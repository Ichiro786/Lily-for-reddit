import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/deferred_pref_writer.dart';
import '../../models/subreddit.dart';
import '../settings/settings_controller.dart';
import 'interest_store.dart' show userScopedPrefsKey;

/// Manages a persistent on-device record of recently visited subreddits with rich metadata.
class VisitedCommunityController extends Notifier<List<Subreddit>> {
  static const _base = 'visited_subreddits_v1';
  static const _cap = 25;
  late String _key;
  late SharedPreferences _prefs;
  DeferredPrefWriter? _writer;

  @override
  List<Subreddit> build() {
    _key = userScopedPrefsKey(ref, _base);
    final prefs = ref.read(sharedPrefsProvider);
    _prefs = prefs;
    _writer = DeferredPrefWriter(_persist);
    ref.onDispose(() {
      unawaited(_writer?.flush());
      _writer?.cancel();
    });

    final raw = prefs.getStringList(_key) ?? const [];
    final list = <Subreddit>[];
    for (final s in raw) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        list.add(Subreddit.fromData(map));
      } catch (_) {
        // Skip corrupted entries safely
      }
    }
    return list;
  }

  void recordVisit(Subreddit subreddit) {
    final lower = subreddit.name.toLowerCase();
    final updated = [
      subreddit,
      ...state.where((s) => s.name.toLowerCase() != lower),
    ];
    if (updated.length > _cap) {
      updated.removeRange(_cap, updated.length);
    }
    state = updated;
    _writer?.schedule();
  }

  void setFavorite(String name, bool favorite) {
    final lower = name.toLowerCase();
    state = [
      for (final s in state)
        if (s.name.toLowerCase() == lower)
          s.copyWith(userHasFavorited: favorite)
        else
          s,
    ];
    _writer?.schedule();
  }

  void setSubscribed(String name, bool subscribed) {
    final lower = name.toLowerCase();
    state = [
      for (final s in state)
        if (s.name.toLowerCase() == lower)
          s.copyWith(userIsSubscriber: subscribed)
        else
          s,
    ];
    _writer?.schedule();
  }

  void remove(String name) {
    final lower = name.toLowerCase();
    state = state.where((s) => s.name.toLowerCase() != lower).toList();
    _writer?.schedule();
  }

  void clear() {
    state = [];
    _persist();
  }

  Future<void> _persist() {
    return _prefs.setStringList(
      _key,
      [for (final s in state) jsonEncode(s.toJson())],
    );
  }
}

final visitedCommunityStoreProvider =
    NotifierProvider<VisitedCommunityController, List<Subreddit>>(
  VisitedCommunityController.new,
);
