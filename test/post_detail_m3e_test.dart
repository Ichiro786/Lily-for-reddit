import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
import 'package:luli_for_reddit/features/post/post_detail_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/post.dart';

Post _createPost({
  String id = 'm3e_post',
  String title = 'M3E Post Detail Title',
  String subreddit = 'flutter',
  String subredditPrefixed = 'r/flutter',
  String author = 'tester',
  int score = 42,
  int numComments = 7,
  PostType type = PostType.self,
  bool isSelf = true,
  String selftext = 'This is a test post body',
  bool stickied = false,
  bool over18 = false,
  String domain = 'reddit.com',
  String url = 'https://www.reddit.com/r/flutter/comments/m3e_post',
  String? thumbnailUrl,
}) =>
    Post(
      id: id,
      fullname: 't3_$id',
      title: title,
      subreddit: subreddit,
      subredditPrefixed: subredditPrefixed,
      author: author,
      score: score,
      numComments: numComments,
      upvoteRatio: 0.95,
      created: DateTime.utc(2026, 1, 1),
      permalink: '/r/$subreddit/comments/$id',
      url: url,
      domain: domain,
      type: type,
      isSelf: isSelf,
      selftext: selftext,
      stickied: stickied,
      over18: over18,
      thumbnailUrl: thumbnailUrl,
    );

Comment _createComment() => Comment(
      id: 'c1',
      fullname: 't1_c1',
      author: 'commenter',
      body: 'Top comment body',
      score: 12,
      created: DateTime.utc(2026, 1, 2),
      depth: 0,
    );

class _MockRedditRepository extends RedditRepository {
  _MockRedditRepository(this.post)
      : super(RedditClient(SecureStore(), AuthRepository(SecureStore())));

  final Post post;

  @override
  Future<(Post, List<Comment>)> getComments({
    required String subreddit,
    required String postId,
    String sort = 'confidence',
    String? focusCommentId,
  }) async {
    return (post, [_createComment()]);
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

Widget _buildHarness({
  required Post post,
  ThemeData? theme,
  SharedPreferences? prefs,
}) {
  return ProviderScope(
    overrides: [
      if (prefs != null) sharedPrefsProvider.overrideWithValue(prefs),
      redditRepositoryProvider.overrideWith((_) => _MockRedditRepository(post)),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark(null),
      home: PostDetailScreen(
        subreddit: post.subreddit,
        postId: post.id,
      ),
    ),
  );
}

Future<void> _pumpDetail(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'post header renders inside M3E card container with surfaceContainer and ShapeTokens.large',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final post = _createPost();

    await tester.pumpWidget(
      _buildHarness(post: post, theme: AppTheme.dark(null), prefs: prefs),
    );
    await _pumpDetail(tester);

    final cardFinder = find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final dec = widget.decoration;
      if (dec is! BoxDecoration) return false;
      return dec.borderRadius == ShapeTokens.large &&
          widget.margin ==
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    });
    expect(cardFinder, findsOneWidget);

    final container = tester.widget<Container>(cardFinder);
    final dec = container.decoration as BoxDecoration;
    final context = tester.element(cardFinder);
    expect(dec.color, Theme.of(context).colorScheme.surfaceContainer);
    expect(dec.border, isNotNull);
  });

  testWidgets('post header renders push pin icon when stickied',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final post = _createPost(stickied: true);

    await tester.pumpWidget(
      _buildHarness(post: post, theme: AppTheme.dark(null), prefs: prefs),
    );
    await _pumpDetail(tester);

    final pinFinder = find.byIcon(Icons.push_pin_rounded);
    expect(pinFinder, findsOneWidget);
    final pinIcon = tester.widget<Icon>(pinFinder);
    final context = tester.element(pinFinder);
    expect(pinIcon.color, Theme.of(context).colorScheme.primary);
  });

  testWidgets('post header renders NSFW badge with errorContainer',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final post = _createPost(over18: true);

    await tester.pumpWidget(
      _buildHarness(post: post, theme: AppTheme.dark(null), prefs: prefs),
    );
    await _pumpDetail(tester);

    final nsfwFinder = find.text('NSFW');
    expect(nsfwFinder, findsOneWidget);

    final badgeFinder = find.ancestor(
      of: nsfwFinder,
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration && d.borderRadius == ShapeTokens.extraSmall;
      }),
    );
    expect(badgeFinder, findsOneWidget);
    final badgeContainer = tester.widget<Container>(badgeFinder);
    final context = tester.element(badgeFinder);
    expect(
      (badgeContainer.decoration as BoxDecoration).color,
      Theme.of(context).colorScheme.errorContainer,
    );
  });

  testWidgets('post header renders rich link preview for PostType.link',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final post = _createPost(
      type: PostType.link,
      isSelf: false,
      domain: 'flutter.dev',
      url: 'https://flutter.dev/docs',
      thumbnailUrl: 'https://example.com/flutter_thumb.png',
    );

    await tester.pumpWidget(
      _buildHarness(post: post, theme: AppTheme.dark(null), prefs: prefs),
    );
    await _pumpDetail(tester);

    expect(find.text('flutter.dev'), findsOneWidget);
    expect(find.text('https://flutter.dev/docs'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('comment sort selector renders in M3E tonal capsule chip',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final post = _createPost();

    await tester.pumpWidget(
      _buildHarness(post: post, theme: AppTheme.dark(null), prefs: prefs),
    );
    await _pumpDetail(tester);

    final capsuleFinder = find.ancestor(
      of: find.text('BEST'),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final dec = widget.decoration;
        if (dec is! BoxDecoration) return false;
        return dec.borderRadius == BorderRadius.circular(20);
      }),
    );
    expect(capsuleFinder, findsOneWidget);

    final context = tester.element(capsuleFinder);
    final dec = (tester.widget<Container>(capsuleFinder).decoration as BoxDecoration);
    expect(dec.color, Theme.of(context).colorScheme.surfaceContainerHigh);
    expect(
        find.descendant(of: capsuleFinder, matching: find.text('BEST')),
        findsOneWidget);
    expect(
        find.descendant(
            of: capsuleFinder, matching: find.byIcon(Icons.sort_rounded)),
        findsOneWidget);
    expect(
        find.descendant(
            of: capsuleFinder,
            matching: find.byIcon(Icons.keyboard_arrow_down_rounded)),
        findsOneWidget);
  });

  testWidgets('selftext markdown body attaches customized MarkdownStyleSheet',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final post = _createPost(
      type: PostType.self,
      isSelf: true,
      selftext: 'Testing markdown body with **bold** text',
    );

    await tester.pumpWidget(
      _buildHarness(post: post, theme: AppTheme.dark(null), prefs: prefs),
    );
    await _pumpDetail(tester);

    final markdownFinder = find.byWidgetPredicate(
      (w) =>
          w is MarkdownBody &&
          w.data.contains('Testing markdown body'),
    );
    expect(markdownFinder, findsOneWidget);

    final markdown = tester.widget<MarkdownBody>(markdownFinder);
    expect(markdown.styleSheet, isNotNull);
    expect(markdown.styleSheet?.p?.fontSize, 15);
  });
}
