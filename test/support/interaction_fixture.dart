import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luli_for_reddit/core/interaction_actions.dart';
import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/post.dart';
import 'package:shared_preferences/shared_preferences.dart';

Post interactionPost({bool? likes, bool saved = false}) => Post(
  id: 'p1',
  fullname: 't3_p1',
  title: 'Flutter architecture testing',
  subreddit: 'flutter',
  subredditPrefixed: 'r/flutter',
  author: 'tester',
  score: 100,
  numComments: 1,
  upvoteRatio: 0.95,
  created: DateTime.utc(2026, 1, 1),
  permalink: '/r/flutter/comments/p1',
  url: 'https://reddit.com/r/flutter/comments/p1',
  domain: 'reddit.com',
  type: PostType.self,
  isSelf: true,
  likes: likes,
  saved: saved,
);

Comment interactionComment() => Comment(
  id: 'c1',
  fullname: 't1_c1',
  author: 'alice',
  body: 'Comment body',
  score: 10,
  created: DateTime.utc(2026, 1, 1),
  depth: 0,
);

class InteractionRequest {
  InteractionRequest(this.fullname, this.value);
  final String fullname;
  final Object value;
  final done = Completer<void>();
}

class InteractionRepository extends RedditRepository {
  InteractionRepository({this.controlled = false, Post? post})
    : post = post ?? interactionPost(),
      super(RedditClient(SecureStore(), AuthRepository(SecureStore())));
  final bool controlled;
  final Post post;
  bool fail = false;
  final votes = <InteractionRequest>[];
  final saves = <InteractionRequest>[];

  Future<void> _request(
    List<InteractionRequest> list,
    String id,
    Object value,
  ) {
    final request = InteractionRequest(id, value);
    list.add(request);
    if (controlled) return request.done.future;
    return fail ? Future.error(StateError('network')) : Future.value();
  }

  @override
  Future<void> vote(String fullname, int dir) => _request(votes, fullname, dir);
  @override
  Future<void> setSaved(String fullname, bool saved) =>
      _request(saves, fullname, saved);
  @override
  Future<(Post, List<Comment>)> getComments({
    required String subreddit,
    required String postId,
    String sort = 'confidence',
    String? focusCommentId,
  }) async => (post, [interactionComment()]);
}

class _SignedOutAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

ProviderContainer interactionContainer({
  InteractionRepository? repository,
  SharedPreferences? prefs,
  void Function(String, String)? report,
  List<Override> extraOverrides = const [],
}) => ProviderContainer(
  overrides: [
    ...extraOverrides,
    redditRepositoryProvider.overrideWithValue(
      repository ?? InteractionRepository(),
    ),
    authControllerProvider.overrideWith(_SignedOutAuth.new),
    interactionReporterProvider.overrideWithValue(report ?? (_, __) {}),
    if (prefs != null) sharedPrefsProvider.overrideWithValue(prefs),
  ],
);
