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
  void Function(List<HistoryEntry>)? _captureHistory;

  @override
  List<HistoryEntry> build() {
    _key = userScopedPrefsKey(ref, _base); // per-account
    final prefs = ref.read(sharedPrefsProvider);
    _prefs = prefs;
    // Coalesced: a full 500-entry list rewrite per opened post collapses into
    // one write per quiet window. Dispose flushes pending work. The writer
    // captures [prefs] directly so disposal-time flushes never read through
    // the dead container.
    final key = _key;
    List<HistoryEntry> snapshot = [];
    _captureHistory = (value) => snapshot = value;
    final writer = DeferredPrefWriter(
      () => prefs.setStringList(key, [
        for (final e in snapshot) jsonEncode(e.toJson()),
      ]),
    );
    _writer = writer;
    ref.onDispose(() {
      unawaited(writer.flush());
      writer.cancel();
    });
    final raw = prefs.get(_key);
    final entries = <HistoryEntry>[];
    final ids = <String>{};
    // A single corrupt row must not break the feed's read-state provider.
    for (final row in raw is List ? raw : const []) {
      if (row is! String) continue;
      try {
        final entry = HistoryEntry.fromJson(
          jsonDecode(row) as Map<String, dynamic>,
        );
        if (entry.id.isNotEmpty && ids.add(entry.id)) entries.add(entry);
        if (entries.length == _cap) break;
      } catch (_) {
        // Preserve valid history around a malformed or obsolete record.
      }
    }
    _rebuildIndex(entries);
    return entries;
  }

  Future<void> flushPersisted() async => _writer?.flush();

  void markViewed(Post p) {
    final entry = HistoryEntry(
      id: p.id,
      subreddit: p.subreddit,
      title: p.title,
      permalink: p.permalink,
      viewedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final list = [entry, ...state.where((e) => e.id != p.id)];
    if (list.length > _cap) list.removeRange(_cap, list.length);
    // Keep the index coherent before notifying historyContainsProvider.
    _rebuildIndex(list);
    state = list;
    _schedulePersist();
  }

  void removeViewed(String id) {
    _idSet.remove(id);
    state = state.where((e) => e.id != id).toList();
    _schedulePersist();
  }

  /// Removes entries older than [age]. Legacy entries (no timestamp) count as
  /// old and are removed too.
  void clearOlderThan(Duration age) {
    final cutoff = DateTime.now().millisecondsSinceEpoch - age.inMilliseconds;
    final entries = state.where((e) => e.viewedAt >= cutoff).toList();
    _rebuildIndex(entries);
    state = entries;
    _schedulePersist();
  }

  void clear() {
    _writer?.cancel();
    _idSet.clear();
    state = [];
    _persist(); // explicit wipe: durable immediately
  }

  bool containsId(String id) => _idSet.contains(id);

  void _schedulePersist() {
    _captureHistory?.call(state);
    _writer?.schedule();
  }

  void _rebuildIndex(Iterable<HistoryEntry> entries) {
    _idSet
      ..clear()
      ..addAll(entries.map((e) => e.id));
  }

  Future<void> _persist() {
    return _prefs.setStringList(_key, [
      for (final e in state) jsonEncode(e.toJson()),
    ]);
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, List<HistoryEntry>>(
      HistoryController.new,
    );

/// Whether a post id has been viewed (for dimming in feeds).
final historyContainsProvider = Provider.family<bool, String>((ref, id) {
  // Watch the state for invalidation, then answer from the controller's index.
  ref.watch(historyControllerProvider);
  return ref.read(historyControllerProvider.notifier).containsId(id);
});
