import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/deferred_pref_writer.dart';
import '../../models/post.dart';
import '../settings/settings_controller.dart';
import 'interest_store.dart' show userScopedPrefsKey;

/// A locally-stored record of a viewed post. History is **on-device only** —
/// Reddit does not sync "viewed" state to third-party clients.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.subreddit,
    required this.title,
    required this.permalink,
    this.viewedAt = 0,
  });

  final String id;
  final String subreddit;
  final String title;
  final String permalink;
  final int viewedAt; // millis since epoch; 0 = legacy/unknown

  Map<String, dynamic> toJson() => {
        'id': id,
        'sub': subreddit,
        'title': title,
        'permalink': permalink,
        'ts': viewedAt,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String? ?? '',
        subreddit: j['sub'] as String? ?? '',
        title: j['title'] as String? ?? '',
        permalink: j['permalink'] as String? ?? '',
        viewedAt: (j['ts'] as num?)?.toInt() ?? 0,
      );
}

class HistoryController extends Notifier<List<HistoryEntry>> {
  static const _base = 'history';
  static const _cap = 500;
  late String _key;
  late SharedPreferences _prefs;
  final _idSet = <String>{};
  DeferredPrefWriter? _writer;

  @override
  List<HistoryEntry> build() {
    _key = userScopedPrefsKey(ref, _base); // per-account
    final prefs = ref.read(sharedPrefsProvider);
    _prefs = prefs;
    // Coalesced: a full 500-entry list rewrite per opened post collapses into
    // one write per quiet window. Dispose flushes pending work. The writer
    // captures [prefs] directly so disposal-time flushes never read through
    // the dead container.
    _writer = DeferredPrefWriter(_persist);
    ref.onDispose(() {
      unawaited(_writer?.flush());
      _writer?.cancel();
    });
    final raw = prefs.getStringList(_key) ?? const [];
    final entries = [
      for (final s in raw)
        HistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>),
    ];
    _rebuildIndex(entries);
    return entries;
  }

  void markViewed(Post p) {
    final entry = HistoryEntry(
        id: p.id,
        subreddit: p.subreddit,
        title: p.title,
        permalink: p.permalink,
        viewedAt: DateTime.now().millisecondsSinceEpoch);
    final list = [entry, ...state.where((e) => e.id != p.id)];
    if (list.length > _cap) list.removeRange(_cap, list.length);
    state = list;
    _rebuildIndex(state);
    _writer?.schedule();
  }

  void removeViewed(String id) {
    state = state.where((e) => e.id != id).toList();
    _idSet.remove(id);
    _writer?.schedule();
  }

  /// Removes entries older than [age]. Legacy entries (no timestamp) count as
  /// old and are removed too.
  void clearOlderThan(Duration age) {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - age.inMilliseconds;
    state = state.where((e) => e.viewedAt >= cutoff).toList();
    _rebuildIndex(state);
    _writer?.schedule();
  }

  void clear() {
    state = [];
    _idSet.clear();
    _persist(); // explicit wipe: durable immediately
  }

  bool containsId(String id) => _idSet.contains(id);

  void _rebuildIndex(Iterable<HistoryEntry> entries) {
    _idSet
      ..clear()
      ..addAll(entries.map((e) => e.id));
  }

  Future<void> _persist() {
    return _prefs.setStringList(
        _key, [for (final e in state) jsonEncode(e.toJson())]);
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, List<HistoryEntry>>(
        HistoryController.new);

/// Whether a post id has been viewed (for dimming in feeds).
final historyContainsProvider = Provider.family<bool, String>((ref, id) {
  // Watch the state for invalidation, then answer from the controller's index.
  ref.watch(historyControllerProvider);
  return ref.read(historyControllerProvider.notifier).containsId(id);
});
