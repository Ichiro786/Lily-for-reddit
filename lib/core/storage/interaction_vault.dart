import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_controller.dart'
    show sharedPrefsProvider;
import 'deferred_pref_writer.dart';

const interactionVaultMaxAge = Duration(days: 30);

class InteractionRecord {
  const InteractionRecord({
    this.upvoted = false,
    this.saved = false,
    this.commentOpened = false,
    this.downvoted = false,
    this.dismissed = false,
    this.timestamp = 0,
  });

  final bool upvoted;
  final bool saved;
  final bool commentOpened;
  final bool downvoted;
  final bool dismissed;
  final int timestamp;

  InteractionRecord copyWith({
    bool? upvoted,
    bool? saved,
    bool? commentOpened,
    bool? downvoted,
    bool? dismissed,
    int? timestamp,
  }) {
    return InteractionRecord(
      upvoted: upvoted ?? this.upvoted,
      saved: saved ?? this.saved,
      commentOpened: commentOpened ?? this.commentOpened,
      downvoted: downvoted ?? this.downvoted,
      dismissed: dismissed ?? this.dismissed,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'upvoted': upvoted,
        'saved': saved,
        'commentOpened': commentOpened,
        'downvoted': downvoted,
        'dismissed': dismissed,
        'timestamp': timestamp,
      };

  factory InteractionRecord.fromJson(Map<String, dynamic> json) {
    return InteractionRecord(
      upvoted: json['upvoted'] == true,
      saved: json['saved'] == true,
      commentOpened: json['commentOpened'] == true,
      downvoted: json['downvoted'] == true,
      dismissed: json['dismissed'] == true,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  bool get suppressesPost =>
      upvoted || saved || downvoted || dismissed || commentOpened;
}

class InteractionVaultState {
  const InteractionVaultState({
    this.interactedPosts = const {},
    this.seenPosts = const {},
  });

  final Map<String, InteractionRecord> interactedPosts;
  final Map<String, int> seenPosts;

  InteractionVaultState copyWith({
    Map<String, InteractionRecord>? interactedPosts,
    Map<String, int>? seenPosts,
  }) {
    return InteractionVaultState(
      interactedPosts: interactedPosts ?? this.interactedPosts,
      seenPosts: seenPosts ?? this.seenPosts,
    );
  }

  bool isSeen(String postId) => seenPosts.containsKey(postId);

  bool shouldSuppress(String postId) {
    final interaction = interactedPosts[postId];
    return isSeen(postId) || (interaction?.suppressesPost ?? false);
  }
}

class InteractionVault extends Notifier<InteractionVaultState> {
  static const _interactedBaseKey = 'interaction_vault_interacted_posts';
  static const _seenBaseKey = 'interaction_vault_seen_posts';

  late String _interactedKey;
  late String _seenKey;

  @override
  InteractionVaultState build() {
    _interactedKey = _interactedBaseKey;
    _seenKey = _seenBaseKey;
    final prefs = ref.read(sharedPrefsProvider);
    final cutoff = _cutoff();

    // Coalesced persistence: bursts of dwell/vote/save events collapse into a
    // single serialized write per key. Closures capture [prefs] directly so a
    // flush during disposal never reads through the dead container.
    final interactedWriter = DeferredPrefWriter(() async {
      final payload = {
        for (final entry in state.interactedPosts.entries)
          entry.key: entry.value.toJson(),
      };
      await prefs.setString(_interactedKey, jsonEncode(payload));
    });
    final seenWriter = DeferredPrefWriter(
        () => prefs.setString(_seenKey, jsonEncode(state.seenPosts)));
    _interactedWriter = interactedWriter;
    _seenWriter = seenWriter;
    ref.onDispose(() {
      unawaited(interactedWriter.flush());
      unawaited(seenWriter.flush());
      interactedWriter.cancel();
      seenWriter.cancel();
    });

    final interacted = _readInteractions(prefs.getString(_interactedKey));
    final rawSeen = _readSeen(prefs.getString(_seenKey));
    final seen = {
      for (final entry in rawSeen.entries)
        if (entry.value >= cutoff) entry.key: entry.value,
    };

    if (seen.length != rawSeen.length) {
      _scheduleSeenPersist();
    }
    return InteractionVaultState(
      interactedPosts: Map.unmodifiable(interacted),
      seenPosts: Map.unmodifiable(seen),
    );
  }

  DeferredPrefWriter? _interactedWriter;
  DeferredPrefWriter? _seenWriter;

  void _scheduleInteractedPersist() => _interactedWriter?.schedule();
  void _scheduleSeenPersist() => _seenWriter?.schedule();

  /// Makes any pending coalesced writes durable immediately (tests, dispose).
  Future<void> flushPersisted() async {
    await _interactedWriter?.flush();
    await _seenWriter?.flush();
  }

  void recordInteraction(
    String postId, {
    bool? upvoted,
    bool? saved,
    bool? commentOpened,
    bool? downvoted,
    bool? dismissed,
  }) {
    if (postId.isEmpty) return;
    final current = state.interactedPosts[postId] ?? const InteractionRecord();
    final updated = current.copyWith(
      upvoted: upvoted,
      saved: saved,
      commentOpened: commentOpened,
      downvoted: downvoted,
      dismissed: dismissed,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    final next = {...state.interactedPosts, postId: updated};
    state = state.copyWith(interactedPosts: Map.unmodifiable(next));
    _scheduleInteractedPersist();
  }

  void recordUpvote(String postId, bool value) =>
      recordInteraction(postId, upvoted: value, downvoted: false);

  void recordSave(String postId, bool value) =>
      recordInteraction(postId, saved: value);

  void recordDismissal(String postId, [bool value = true]) =>
      recordInteraction(postId, dismissed: value);

  void recordCommentOpened(String postId) {
    recordInteraction(postId, commentOpened: true);
    markSeen(postId);
  }

  void markSeen(String postId) {
    if (postId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = {
      for (final entry in state.seenPosts.entries)
        if (entry.value >= _cutoff()) entry.key: entry.value,
      postId: now,
    };
    state = state.copyWith(seenPosts: Map.unmodifiable(next));
    _scheduleSeenPersist();
  }

  void recordDwell(String postId) => markSeen(postId);

  Map<String, InteractionRecord> _readInteractions(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: InteractionRecord.fromJson(
                entry.value as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }

  Map<String, int> _readSeen(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  int _cutoff() =>
      DateTime.now().millisecondsSinceEpoch - interactionVaultMaxAge.inMilliseconds;
}

final interactionVaultProvider =
    NotifierProvider<InteractionVault, InteractionVaultState>(
  InteractionVault.new,
);
