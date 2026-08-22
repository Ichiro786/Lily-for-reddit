import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/post/comments_controller.dart';
import 'package:luli_for_reddit/features/post/post_detail_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/post.dart';

Post _post() => Post(
      id: 'm3e',
      fullname: 't3_m3e',
      title: 'Sort label post',
      subreddit: 'flutter',
      subredditPrefixed: 'r/flutter',
      author: 'lily',
      score: 10,
      numComments: 1,
      upvoteRatio: 0.9,
      created: DateTime.utc(2026, 1, 1),
      permalink: '/r/flutter/comments/m3e',
      url: 'https://www.reddit.com/r/flutter/comments/m3e',
      domain: 'reddit.com',
      type: PostType.self,
      isSelf: true,
    );

Comment _comment() => Comment(
      id: 'c1',
      fullname: 't1_c1',
      author: 'alice',
      body: 'A deterministic comment',
      score: 5,
      created: DateTime.utc(2026, 1, 2),
      depth: 0,
    );

/// Serves a fixed thread without any network access so the detail screen can
/// be pumped deterministically.
class _FixedThreadRepository extends RedditRepository {
  _FixedThreadRepository()
      : super(RedditClient(SecureStore(), AuthRepository(SecureStore())));

  @override
  Future<(Post, List<Comment>)> getComments({
    required String subreddit,
    required String postId,
    String sort = 'confidence',
    String? focusCommentId,
  }) async {
    return (_post(), [_comment()]);
  }

  @override
  Future<List<Comment>> getMoreComments({
    required String linkFullname,
    required List<String> childrenIds,
    String sort = 'confidence',
    int depth = 0,
  }) async {
    return const [];
  }
}

void main() {
  testWidgets('comment sort header reflects and tracks the active sort',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          redditRepositoryProvider.overrideWith((ref) {
            return _FixedThreadRepository();
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: const PostDetailScreen(
            subreddit: 'flutter',
            postId: 'm3e',
          ),
        ),
      ),
    );
    // Advance past the bounded secure-storage auth retries and let the
    // thread load. Explicit pumps are used throughout because the loading
    // branch contains a continuously animating progress indicator.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    // Regression (Phase 1): the header used to hardcode "BEST COMMENTS"
    // regardless of the active sort. Default controller sort is
    // 'confidence' -> canonical label "Best".
    expect(find.text('BEST'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PostDetailScreen)),
    );
    await container
        .read(commentsControllerProvider('flutter/m3e').notifier)
        .changeSort('top');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('TOP'), findsOneWidget);
    expect(find.text('BEST'), findsNothing);
  });
}
