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
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';
import 'package:luli_for_reddit/features/post/post_detail_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/post.dart';

Post _post() => Post(
      id: 'qre',
      fullname: 't3_qre',
      title: 'Reply failure post',
      subreddit: 'flutter',
      subredditPrefixed: 'r/flutter',
      author: 'lily',
      score: 10,
      numComments: 1,
      upvoteRatio: 0.9,
      created: DateTime.utc(2026, 1, 1),
      permalink: '/r/flutter/comments/qre',
      url: 'https://www.reddit.com/r/flutter/comments/qre',
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

/// Thread the detail screen can load without network, but whose `reply` fails
/// exactly like a transient outage would.
class _FailingReplyRepository extends RedditRepository {
  _FailingReplyRepository()
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
  Future<Comment> reply({
    required String parentFullname,
    required String text,
    String? richtextJson,
    int depth = 0,
  }) async {
    throw Exception('Could not reach Reddit');
  }
}

void main() {
  testWidgets('failed quick reply keeps the comment text and shows an error',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          redditRepositoryProvider.overrideWith((ref) {
            return _FailingReplyRepository();
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: const PostDetailScreen(
            subreddit: 'flutter',
            postId: 'qre',
          ),
        ),
      ),
    );
    // Let the thread load (loading branch animates continuously, so pump
    // explicit durations like the sibling post detail tests do).
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    final composeField = find.descendant(
      of: find.byType(CommentComposeBar),
      matching: find.byType(TextField),
    );
    await tester.enterText(composeField, 'This comment must survive');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The failure is surfaced and the draft is restored, not silently eaten.
    expect(find.textContaining("Couldn't post the comment"), findsOneWidget);
    expect(
      tester.widget<TextField>(composeField).controller!.text,
      'This comment must survive',
    );
    // No phantom comment was spliced into the tree.
    expect(find.text('This comment must survive'), findsWidgets);

    // Let the snackbar's auto-dismiss timer elapse before teardown.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
