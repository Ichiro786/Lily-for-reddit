import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comment.dart';

/// The effective, user-visible interaction state of a comment that can change
/// after it is fetched. Mirrors [PostOverride] for posts: the fetched
/// [Comment] provides the baseline, optimistic mutations update this store
/// immediately, API success keeps them, and API failure reverts.
class CommentOverride {
  const CommentOverride({
    required this.likes,
    required this.score,
    required this.saved,
  });

  final bool? likes; // true=up, false=down, null=no vote
  final int score;
  final bool saved;

  int get voteDirection =>
      likes == true ? 1 : (likes == false ? -1 : 0);
}

/// Authoritative optimistic state for comments, keyed by fullname (t1_…).
///
/// Keep-alive by design so interaction state survives comment-tile disposal
/// during scroll recycling and navigation. The UI stays a controlled
/// presenter: tiles emit intents, this controller owns transitions.
class CommentOverridesController
    extends Notifier<Map<String, CommentOverride>> {
  @override
  Map<String, CommentOverride> build() => {};

  /// Effective state for [c]: an override when one exists, else derived from
  /// the comment's own server-provided values.
  CommentOverride effective(Comment c) =>
      state[c.fullname] ??
      CommentOverride(likes: c.likes, score: c.score, saved: c.saved);

  void _set(String fullname, CommentOverride o) =>
      state = {...state, fullname: o};

  /// Applies a vote transition (toggling off when the active direction is
  /// re-tapped). The score moves by exactly one net delta.
  void setVote(Comment c, int targetDir) {
    final cur = effective(c);
    if (targetDir == cur.voteDirection) return;
    _set(
      c.fullname,
      CommentOverride(
        likes: targetDir == 1
            ? true
            : (targetDir == -1 ? false : null),
        score: cur.score + (targetDir - cur.voteDirection),
        saved: cur.saved,
      ),
    );
  }

  void setSaved(Comment c, bool saved) {
    final cur = effective(c);
    if (cur.saved == saved) return;
    _set(
      c.fullname,
      CommentOverride(
        likes: cur.likes,
        score: cur.score,
        saved: saved,
      ),
    );
  }

  /// Optimistic vote with revert-on-failure. [api] performs the network call
  /// with the resolved target direction (0 clears the vote).
  Future<void> vote(
    Comment c,
    int dir,
    Future<void> Function(int targetDir) api,
  ) async {
    final previousDirection = effective(c).voteDirection;
    final target = previousDirection == dir ? 0 : dir;
    setVote(c, target);
    try {
      await api(target);
    } catch (_) {
      setVote(c, previousDirection); // restore prior authoritative state
    }
  }

  /// Optimistic save/unsave with revert-on-failure.
  Future<void> toggleSave(
    Comment c,
    Future<void> Function(bool next) api,
  ) async {
    final previous = effective(c).saved;
    final next = !previous;
    setSaved(c, next);
    try {
      await api(next);
    } catch (_) {
      setSaved(c, previous);
    }
  }
}

final commentOverridesProvider =
    NotifierProvider<CommentOverridesController, Map<String, CommentOverride>>(
        CommentOverridesController.new);
