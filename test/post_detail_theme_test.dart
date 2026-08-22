import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/core/theme/shape_tokens.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';
import 'package:luli_for_reddit/features/post/post_detail_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/post.dart';

Comment _comment() => Comment(
      id: 'c1',
      fullname: 't1_c1',
      author: 'alice',
      body: 'A tokenized comment',
      score: 5,
      created: DateTime.utc(2026, 1, 2),
      depth: 0,
    );

Post _post() => Post(
      id: 'm3e',
      fullname: 't3_m3e',
      title: 'Theme probe post',
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
}

Widget _cardHarness(ThemeData theme) => MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: M3ECommentCard(
          author: 'alice',
          timeAgo: '1h',
          body: 'body',
          score: 42,
        ),
      ),
    );

/// The card surface must come from the active scheme's [ColorScheme
/// .surfaceContainer] — never a widget-local constant — across light, dark,
/// AMOLED, and seeded schemes. The card is located by its distinctive
/// medium-radius decorated box rather than text internals.
Future<void> _expectTokenizedCardSurface(
  WidgetTester tester,
  ThemeData theme,
) async {
  await tester.pumpWidget(_cardHarness(theme));
  final context = tester.element(find.byType(M3ECommentCard));
  final expected = Theme.of(context).colorScheme.surfaceContainer;
  final card = find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).borderRadius ==
            ShapeTokens.medium &&
        (widget.decoration! as BoxDecoration).color != null,
  );
  expect(card, findsOneWidget);
  expect(
    ((tester.widget<Container>(card).decoration!) as BoxDecoration).color,
    expected,
  );
}

void main() {
  testWidgets('comment card consumes the active scheme in light mode',
      (tester) async {
    await _expectTokenizedCardSurface(tester, AppTheme.light(null));
  });

  testWidgets('comment card consumes the active scheme in dark mode',
      (tester) async {
    await _expectTokenizedCardSurface(tester, AppTheme.dark(null));
  });

  testWidgets('AMOLED appearance is inherited from AppTheme, not hardcoded',
      (tester) async {
    await _expectTokenizedCardSurface(tester, AppTheme.dark(null, amoled: true));
  });

  testWidgets('seeded schemes propagate into the comment card',
      (tester) async {
    // A deliberately non-purple seed proves no stubborn legacy hue remains.
    const seed = Color(0xFF00695C);
    await _expectTokenizedCardSurface(
      tester,
      AppTheme.light(ColorScheme.fromSeed(seedColor: seed)),
    );
  });

  testWidgets('upvote accent follows VoteColors under a seeded scheme',
      (tester) async {
    const seed = Color(0xFF00695C);
    await tester.pumpWidget(
      MaterialApp(
        theme:
            AppTheme.dark(ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark)),
        home: const Scaffold(
          body: M3ECommentCard(
            author: 'alice',
            timeAgo: '1h',
            body: 'body',
            score: 42,
            voteState: 1,
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(M3ECommentCard));
    final theme = Theme.of(context);
    final up =
        tester.widget<Icon>(find.byIcon(Icons.arrow_upward_rounded));
    expect(up.color, theme.extension<VoteColors>()!.up);
  });

  testWidgets('compose bar surfaces follow the active scheme in light mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(null),
        home: Scaffold(
          body: CommentComposeBar(onSubmit: (_) {}, onImageSelected: (_) {}),
        ),
      ),
    );
    final context = tester.element(find.byType(CommentComposeBar));
    final cs = Theme.of(context).colorScheme;

    // Field pill: canonical filled-input surface (surfaceContainerHighest).
    final fieldPill = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color ==
              cs.surfaceContainerHighest &&
          (widget.decoration! as BoxDecoration).borderRadius ==
              ShapeTokens.full,
    );
    expect(fieldPill, findsOneWidget);

    // Dock chrome: same elevated surface family as sheets and the nav dock.
    final dock = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color == cs.surfaceContainerHigh,
    );
    expect(dock, findsOneWidget);
  });

  testWidgets('post detail screen renders on themed scaffold in light mode',
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
          theme: AppTheme.light(null),
          home: const PostDetailScreen(subreddit: 'flutter', postId: 'm3e'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    // Regression (Phase 2): the screen used to force Colors.black regardless
    // of theme. It must now inherit the scaffold background from the theme.
    final context = tester.element(find.byType(PostDetailScreen));
    final scaffold = tester.widget<Scaffold>(
      find.ancestor(of: find.text('BEST'), matching: find.byType(Scaffold)),
    );
    expect(scaffold.backgroundColor, isNull); // defers to ThemeData
    expect(Theme.of(context).scaffoldBackgroundColor, isNot(Colors.black));

    // Sort header uses the scheme's primary rather than a fixed purple.
    final label = tester.widget<Text>(find.text('BEST'));
    expect(label.style?.color, Theme.of(context).colorScheme.primary);
  });
}
