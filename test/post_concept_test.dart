import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/core/theme/thread_colors.dart';
import 'package:luli_for_reddit/features/feed/post_action_bar.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/media/expandable_post_media.dart';
import 'package:luli_for_reddit/features/media/gallery_carousel.dart';
import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/post/comment_content.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';
import 'package:luli_for_reddit/features/post/comment_media_helper.dart';
import 'package:luli_for_reddit/features/post/comments_controller.dart';
import 'package:luli_for_reddit/features/post/post_detail_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/post.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'support/interaction_fixture.dart';

class _ThreadRepository extends InteractionRepository {
  _ThreadRepository(this.comments);
  final List<Comment> comments;
  int expansions = 0;
  bool failExpansion = false;
  @override
  Future<(Post, List<Comment>)> getComments({
    required String subreddit,
    required String postId,
    String sort = 'confidence',
    String? focusCommentId,
  }) async => (post, comments);
  @override
  Future<List<Comment>> getMoreComments({
    required String linkFullname,
    required List<String> childrenIds,
    String sort = 'confidence',
    int depth = 0,
  }) async {
    expansions++;
    if (failExpansion) throw StateError('offline');
    return [
      for (final id in childrenIds)
        interactionComment().copyWith(
          id: id,
          fullname: 't1_$id',
          parentId: 't1_c1',
          depth: depth,
          body: 'Loaded reply $id',
        ),
    ];
  }
}

Future<void> _detail(
  WidgetTester tester,
  _ThreadRepository repository, {
  ThemeData? theme,
  void Function(Object)? failure,
}) async {
  SharedPreferences.setMockInitialValues({'autoplayMedia': false});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        redditRepositoryProvider.overrideWithValue(repository),
        if (failure != null)
          moreRepliesFailureProvider.overrideWithValue(failure),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.dark(null),
        home: const PostDetailScreen(subreddit: 'flutter', postId: 'p1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'search is absent from the top bar and remains available through post options',
    (tester) async {
      await _detail(tester, _ThreadRepository([interactionComment()]));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.search_rounded),
        ),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Post options'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Search comments'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      final field = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'no results');
      await tester.pumpAndSettle();
      expect(find.text('No matching comments'), findsOneWidget);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'feed video overlays remain readable on their scrim in light mode',
    (tester) async {
      final visibility = VisibilityDetectorController.instance;
      final previousInterval = visibility.updateInterval;
      visibility.updateInterval = Duration.zero;
      addTearDown(() => visibility.updateInterval = previousInterval);
      SharedPreferences.setMockInitialValues({
        'autoplayMedia': false,
        'trackHistory': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = interactionContainer(prefs: prefs);
      addTearDown(container.dispose);
      final post = interactionPost().copyWith(
        type: PostType.video,
        isSelf: false,
        previewUrl: 'https://i.redd.it/poster.jpg',
        previewWidth: 1600,
        previewHeight: 900,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(null),
            home: Scaffold(
              body: ListView(children: [PostCard(post: post)]),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
        Colors.white,
      );
      expect(
        tester.widget<Text>(find.text('VIDEO')).style?.color,
        Colors.white,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'search remains attached to its comment after a preceding branch collapses',
    (tester) async {
      final branch = interactionComment().copyWith(
        replies: [
          for (var i = 0; i < 8; i++)
            interactionComment().copyWith(
              id: 'r$i',
              fullname: 't1_r$i',
              depth: 1,
              body: 'Reply $i',
            ),
        ],
      );
      await _detail(
        tester,
        _ThreadRepository([
          branch,
          interactionComment().copyWith(
            id: 'target',
            fullname: 't1_target',
            author: 'target',
            body: 'needle',
          ),
        ]),
      );
      await tester.tap(find.byTooltip('Double-tap to search comments'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byTooltip('Double-tap to search comments'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'needle',
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PostDetailScreen)),
      );
      container
          .read(commentsControllerProvider('flutter/p1').notifier)
          .toggleCollapse('c1');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'u/target'));
      await tester.pumpAndSettle();
      expect(find.text('u/target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('spoiler media loads only after reveal and can be hidden again', (
    tester,
  ) async {
    await _detail(
      tester,
      _ThreadRepository([
        interactionComment().copyWith(body: '>!https://i.redd.it/secret.gif!<'),
      ]),
    );
    expect(find.byType(CachedNetworkImage), findsNothing);
    await tester.tap(find.text('Spoiler (Tap to reveal)'));
    await tester.pumpAndSettle();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    await tester.tap(find.text('Hide spoiler'));
    await tester.pumpAndSettle();
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
  test('GIF image hints and query strings keep the animated source', () {
    final direct = Post.fromData({
      'url': 'https://i.redd.it/reaction.gif?width=640',
      'post_hint': 'image',
    });
    expect(direct.type, PostType.gif);
    final preview = Post.fromData({
      'url': 'https://reddit.com/post',
      'post_hint': 'image',
      'preview': {
        'images': [
          {
            'source': {'url': 'https://preview.redd.it/static.jpg'},
            'variants': {
              'gif': {
                'source': {
                  'url': 'https://preview.redd.it/animated.gif?a=1&amp;b=2',
                  'width': 600,
                  'height': 900,
                },
              },
            },
          },
        ],
      },
    });
    expect(preview.type, PostType.gif);
    expect(preview.previewUrl, 'https://preview.redd.it/animated.gif?a=1&b=2');
    expect(preview.previewHeight, 900);
  });

  testWidgets('sort dropdown animates and updates the selected comment order', (
    tester,
  ) async {
    await _detail(tester, _ThreadRepository([interactionComment()]));
    await tester.tap(find.text('BEST'));
    await tester.pumpAndSettle();
    expect(find.text('Top'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is CheckedPopupMenuItem<String> && widget.value == 'top',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TOP'), findsOneWidget);
    expect(find.text('BEST'), findsNothing);
    final menus = tester.widgetList<PopupMenuButton<String>>(
      find.byType(PopupMenuButton<String>),
    );
    expect(
      menus.every(
        (menu) =>
            menu.popUpAnimationStyle?.duration ==
            const Duration(milliseconds: 300),
      ),
      isTrue,
    );
  });

  testWidgets('next thread skips a long nested reply branch', (tester) async {
    final root = interactionComment().copyWith(
      replies: [
        for (var i = 0; i < 8; i++)
          interactionComment().copyWith(
            id: 'reply$i',
            fullname: 't1_reply$i',
            depth: i + 1,
            author: 'reply$i',
            body: 'Nested discussion $i',
          ),
      ],
    );
    await _detail(
      tester,
      _ThreadRepository([
        root,
        interactionComment().copyWith(
          id: 'last',
          fullname: 't1_last',
          author: 'last_author',
        ),
      ]),
    );
    await tester.tap(find.byTooltip('Add media'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next comment thread'));
    await tester.tap(find.text('Next comment thread'));
    await tester.pumpAndSettle();
    expect(find.text('u/last_author'), findsNothing);
    await tester.tap(find.byTooltip('Add media'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next comment thread'));
    await tester.tap(find.text('Next comment thread'));
    await tester.pumpAndSettle();
    expect(find.text('u/last_author'), findsOneWidget);
    final card = find.ancestor(
      of: find.text('u/last_author'),
      matching: find.byType(M3ECommentCard),
    );
    expect(
      tester.getBottomRight(card).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(CommentComposeBar)).dy),
    );
  });

  test('rainbow rails remain distinct and readable in all device schemes', () {
    for (final theme in [
      AppTheme.light(null),
      AppTheme.dark(null),
      AppTheme.dark(null, amoled: true),
      AppTheme.light(null, seed: Colors.teal),
      AppTheme.dark(null, seed: Colors.amber),
    ]) {
      final colors = theme.extension<ThreadColors>()!;
      expect(colors.rails.toSet(), hasLength(7));
      final background = theme.colorScheme.surfaceContainer.computeLuminance();
      for (final color in colors.rails) {
        final luminance = color.computeLuminance();
        final contrast = (luminance > background
            ? (luminance + .05) / (background + .05)
            : (background + .05) / (luminance + .05));
        expect(contrast, greaterThanOrEqualTo(3));
      }
      expect(colors.atDepth(1), colors.atDepth(8));
    }
  });

  testWidgets(
    'narrow deeply nested comments support long authors and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(null),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: ListView(
                children: [
                  M3ECommentCard(
                    author: 'A_very_long_author_name_that_would_overflow',
                    timeAgo: '12 hours ago',
                    body: 'Readable comment text',
                    depth: 24,
                    score: 12345678,
                    isOp: true,
                    onVote: (_) {},
                    onReply: () {},
                    onSave: () {},
                    onOverflow: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byTooltip('Upvote')), const Size(48, 48));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('comment-depth-rail-24')))
            .height,
        greaterThan(120),
      );
    },
  );

  testWidgets('portrait media keeps its exact intrinsic height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ExpandablePostMedia(
                aspectRatio: 9 / 16,
                onOpen: () {},
                builder: (_, height) =>
                    SizedBox(key: const ValueKey('portrait'), height: height),
              ),
            ],
          ),
        ),
      ),
    );
    // Default 800x600 viewport caps the initial image; use a wider landscape
    // ratio here only to test natural sizing without triggering the cap.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: ListView(
              children: [
                ExpandablePostMedia(
                  key: const ValueKey('new-media'),
                  aspectRatio: 9 / 16,
                  onOpen: () {},
                  builder: (_, height) =>
                      SizedBox(key: const ValueKey('portrait'), height: height),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('portrait'))).height,
      closeTo(300 * 16 / 9, .01),
    );
    expect(find.text('View full'), findsNothing);
  });

  testWidgets('very tall media expands smoothly in place and can collapse', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: ListView(
              children: [
                ExpandablePostMedia(
                  aspectRatio: .2,
                  onOpen: () {},
                  builder: (_, height) => ColoredBox(
                    key: const ValueKey('image'),
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final animated = find.byType(AnimatedSize).first;
    final initial = tester.getSize(animated).height;
    await tester.tap(find.text('View full'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final midway = tester.getSize(animated).height;
    expect(midway, greaterThan(initial));
    expect(midway, lessThan(1500));
    await tester.pumpAndSettle();
    expect(tester.getSize(animated).height, closeTo(1500, .01));
    await tester.ensureVisible(find.text('Show less'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(tester.getSize(animated).height, closeTo(initial, .01));
  });

  testWidgets('reduced motion collapses comments without a pending animation', (
    tester,
  ) async {
    var collapsed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StatefulBuilder(
              builder: (context, setState) => M3ECommentCard(
                author: 'alice',
                timeAgo: '1h',
                body: 'Hidden body',
                isCollapsed: collapsed,
                onToggleCollapse: () => setState(() => collapsed = !collapsed),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('u/alice'));
    await tester.pump();
    expect(find.text('Hidden body'), findsNothing);
    expect(find.byType(AnimatedSize), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Reddit emotes use metadata; missing metadata stays recoverable', () {
    final comment = Comment.fromChild({
      'kind': 't1',
      'data': {
        'id': 'emote',
        'body': 'Hello ![img](emote|t5_flutter|123)',
        'media_metadata': {
          '123': {
            's': {'u': 'https://i.redd.it/emote.png?x=1&amp;y=2'},
          },
        },
      },
    }, 0);
    expect(
      extractCommentMedia(comment.body).single.url,
      'https://i.redd.it/emote.png?x=1&y=2',
    );
    expect(
      commentTextWithoutMedia('![gif](emote|unknown)'),
      '[Emote unavailable]',
    );
    expect(extractCommentMedia('>!https://i.redd.it/secret.gif!<'), isEmpty);
    expect(
      commentTextWithoutMedia('>!https://i.redd.it/secret.gif!<'),
      '>!https://i.redd.it/secret.gif!<',
    );
  });

  testWidgets(
    'comments render GIFs and images once and remove them on collapse',
    (tester) async {
      final comment = interactionComment().copyWith(
        body:
            'A reaction ![gif](giphy|abc123) ![image](https://i.redd.it/photo.png) https://i.redd.it/photo.png',
      );
      await _detail(tester, _ThreadRepository([comment]));
      expect(find.byType(CommentContent), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNWidgets(2));
      expect(find.textContaining('giphy|', findRichText: true), findsNothing);
      await tester.tap(find.text('u/alice'));
      await tester.pumpAndSettle();
      expect(find.byType(CachedNetworkImage), findsNothing);
    },
  );

  testWidgets('reply expansion loads inline and retries a failed request', (
    tester,
  ) async {
    final more = interactionComment().copyWith(
      id: 'more',
      fullname: 'more',
      author: '',
      body: '',
      isMore: true,
      moreCount: 2,
      moreChildren: ['r1', 'r2'],
      depth: 1,
      parentId: 't1_c1',
    );
    final repository = _ThreadRepository([
      interactionComment().copyWith(replies: [more]),
    ]);
    final errors = <Object>[];
    repository.failExpansion = true;
    await _detail(tester, repository, failure: errors.add);
    await tester.tap(find.text('View 2 more replies'));
    await tester.pumpAndSettle();
    expect(repository.expansions, 1);
    expect(errors, hasLength(1));
    repository.failExpansion = false;
    await tester.tap(find.text('View 2 more replies'));
    await tester.pumpAndSettle();
    expect(repository.expansions, 2);
    expect(
      find.textContaining('Loaded reply r1', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('View 2 more replies'), findsNothing);
  });

  testWidgets('comment search dialog selects the exact distant item', (
    tester,
  ) async {
    final comments = [
      for (var i = 0; i < 45; i++)
        interactionComment().copyWith(
          id: 'c$i',
          fullname: 't1_c$i',
          author: 'author$i',
          body: i == 42 ? 'needle in thread' : 'Comment $i',
        ),
    ];
    await _detail(tester, _ThreadRepository(comments));
    await tester.tap(find.byTooltip('Double-tap to search comments'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byTooltip('Double-tap to search comments'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      'needle',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'u/author42'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('needle in thread', findRichText: true),
      findsOneWidget,
    );
    expect(tester.getTopLeft(find.text('u/author42')).dy, lessThan(200));
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail action order and callbacks match the reference', (
    tester,
  ) async {
    final votes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(null),
        home: Scaffold(
          body: M3EPostActionBar(
            detailStyle: true,
            score: 534,
            commentCount: 42,
            onVote: votes.add,
            onCommentTap: () {},
            onSaveTap: () {},
            onShareTap: () {},
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.byTooltip('Save')).dx,
      lessThan(tester.getTopLeft(find.byTooltip('Share')).dx),
    );
    await tester.tap(find.byTooltip('Upvote'));
    await tester.tap(find.byTooltip('Downvote'));
    expect(votes, [1, -1]);
    expect(tester.getSize(find.byTooltip('Save')), const Size(48, 48));
  });

  testWidgets(
    'mixed portrait/landscape galleries never crop and handle empty lists',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ListView(
                children: [
                  GalleryCarousel(
                    images: const [
                      GalleryImage(
                        url: 'https://i.redd.it/portrait.jpg',
                        width: 900,
                        height: 1600,
                      ),
                      GalleryImage(
                        url: 'https://i.redd.it/landscape.jpg',
                        width: 1600,
                        height: 900,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
            .fit,
        BoxFit.contain,
      );
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('2/2'), findsOneWidget);
      expect(
        tester.getSize(find.byType(PageView)).height,
        closeTo(300 * 9 / 16, .01),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GalleryCarousel(images: [])),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
