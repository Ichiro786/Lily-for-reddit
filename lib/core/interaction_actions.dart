import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/feed/post_overrides.dart';
import '../features/history/interest_store.dart';
import '../features/post/comment_overrides.dart';
import '../models/comment.dart';
import '../models/post.dart';
import 'analytics.dart';
import 'providers.dart';
import 'storage/interaction_vault.dart';

/// Anonymous outcomes only: no content, account identifiers or API errors.
/// Telemetry must never change the result of a Reddit mutation.
final interactionReporterProvider =
    Provider<FutureOr<void> Function(String, String)>(
  (ref) => (action, outcome) async {
    debugPrint('Interaction $action: $outcome');
    await Analytics.track(
        'interaction', {'action': action, 'outcome': outcome});
  },
);

final interactionActionsProvider = Provider<InteractionActions>(
  (ref) {
    final actions = InteractionActions(ref);
    ref.onDispose(() => actions._active = false);
    return actions;
  },
);

/// The UI-facing vote/save boundary shared by feed, detail and comment tiles.
/// Overrides contain optimistic presentation state; the vault contains durable
/// post behavior for history/personalization, never a rendering baseline.
/// Learning is committed after API success so rejected actions cannot persist
/// signals (and rollback needs no inverse of clamped/decayed ranking weights).
class InteractionActions {
  InteractionActions(this._ref);
  final Ref _ref;
  bool _active = true;
  final _votes = <String, _ActionLane<int>>{};
  final _saves = <String, _ActionLane<bool>>{};

  Future<void> votePost(Post post, int direction) {
    assert(direction == 1 || direction == -1);
    final overrides = _ref.read(postOverridesProvider.notifier);
    final repository = _ref.read(redditRepositoryProvider);
    final previous = overrides.effective(post).voteDirection;
    return _perform(
      lanes: _votes,
      key: post.fullname,
      initial: previous,
      target: previous == direction ? 0 : direction,
      action: 'post_vote',
      present: (target) => overrides.setVote(post, target),
      request: (target) => repository.vote(post.fullname, target),
      commit: (target) {
        _ref.read(interactionVaultProvider.notifier).recordInteraction(
              post.id,
              upvoted: target == 1,
              downvoted: target == -1,
            );
        // Dismissal is an independent explicit hide signal, not a downvote.
        if (target == 1 || target == -1) {
          _ref
              .read(interestStoreProvider.notifier)
              .bump(post.subreddit, target == 1 ? 2 : -1.5);
          _ref
              .read(keywordStoreProvider.notifier)
              .bumpTitle(post.title, target == 1 ? 1 : -0.8);
        }
      },
    );
  }

  Future<void> toggleSavePost(Post post) {
    final overrides = _ref.read(postOverridesProvider.notifier);
    final repository = _ref.read(redditRepositoryProvider);
    final previous = overrides.effective(post).saved;
    return _perform(
      lanes: _saves,
      key: post.fullname,
      initial: previous,
      target: !previous,
      action: 'post_save',
      present: (target) => overrides.setSaved(post, target),
      request: (target) => repository.setSaved(post.fullname, target),
      commit: (target) {
        _ref
            .read(interactionVaultProvider.notifier)
            .recordSave(post.id, target);
        _ref
            .read(interestStoreProvider.notifier)
            .bump(post.subreddit, target ? 3 : -3);
        if (target) {
          _ref.read(keywordStoreProvider.notifier).bumpTitle(post.title, 1.5);
        }
      },
    );
  }

  Future<void> voteComment(Comment comment, int direction) {
    assert(direction == 1 || direction == -1);
    final overrides = _ref.read(commentOverridesProvider.notifier);
    final repository = _ref.read(redditRepositoryProvider);
    final previous = overrides.effective(comment).voteDirection;
    return _perform(
      lanes: _votes,
      key: comment.fullname,
      initial: previous,
      target: previous == direction ? 0 : direction,
      action: 'comment_vote',
      present: (target) => overrides.setVote(comment, target),
      request: (target) => repository.vote(comment.fullname, target),
      commit: (_) {}, // Comments have no post-level learning/history signal.
    );
  }

  Future<void> toggleSaveComment(Comment comment) {
    final overrides = _ref.read(commentOverridesProvider.notifier);
    final repository = _ref.read(redditRepositoryProvider);
    final previous = overrides.effective(comment).saved;
    return _perform(
      lanes: _saves,
      key: comment.fullname,
      initial: previous,
      target: !previous,
      action: 'comment_save',
      present: (target) => overrides.setSaved(comment, target),
      request: (target) => repository.setSaved(comment.fullname, target),
      commit: (_) {},
    );
  }

  Future<void> _perform<T>({
    required Map<String, _ActionLane<T>> lanes,
    required String key,
    required T initial,
    required T target,
    required String action,
    required void Function(T) present,
    required Future<void> Function(T) request,
    required void Function(T) commit,
  }) {
    final lane = lanes.putIfAbsent(key, () => _ActionLane(initial));
    return lane.submit(
      target: target,
      present: (value) {
        if (_active) present(value);
      },
      request: request,
      commit: (value) {
        if (!_active) return;
        try {
          commit(value);
        } catch (_) {
          // A local signal failure cannot undo a server-accepted mutation.
          _report(action, 'signal_failed');
        }
      },
      report: (outcome) => _report(action, outcome),
      onIdle: () => lanes.remove(key),
    );
  }

  void _report(String action, String outcome) {
    if (!_active) return;
    // Future.sync handles synchronous reporters and asynchronous SDK failures.
    unawaited(Future<void>.sync(
      () => _ref.read(interactionReporterProvider)(action, outcome),
    ).catchError((Object _) {}));
  }
}

/// Serialize each item's vote and save independently. Every intent still
/// issues its original API mutation, while the newest target renders at once.
/// A failed older request never restores its snapshot over a newer intent;
/// when all requests settle, presentation returns to the last accepted target.
class _ActionLane<T> {
  _ActionLane(this._confirmed);
  T _confirmed;
  final _pending = <_PendingAction<T>>[];

  Future<void> submit({
    required T target,
    required void Function(T) present,
    required Future<void> Function(T) request,
    required void Function(T) commit,
    required void Function(String) report,
    required VoidCallback onIdle,
  }) {
    final pending = _PendingAction(target, present, request, commit, report);
    _pending.add(pending);
    present(target);
    if (_pending.length == 1) unawaited(_drain(onIdle));
    return pending.done.future;
  }

  Future<void> _drain(VoidCallback onIdle) async {
    while (_pending.isNotEmpty) {
      final current = _pending.first;
      try {
        await current.request(current.target);
        _confirmed = current.target;
        current.commit(current.target);
        current.report('succeeded');
      } catch (_) {
        current.report('failed');
      }
      _pending.removeAt(0);
      current.present(_pending.isEmpty ? _confirmed : _pending.last.target);
      current.done.complete();
    }
    onIdle();
  }
}

class _PendingAction<T> {
  _PendingAction(
    this.target,
    this.present,
    this.request,
    this.commit,
    this.report,
  );
  final T target;
  final void Function(T) present;
  final Future<void> Function(T) request;
  final void Function(T) commit;
  final void Function(String) report;
  final done = Completer<void>();
}
