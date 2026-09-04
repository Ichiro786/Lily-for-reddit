import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:luli_for_reddit/core/media_aspect_ratio.dart';
import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/feed/compact_post_card.dart';
import 'package:luli_for_reddit/features/feed/post_action_bar.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/history/history_store.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/post.dart';

class _TestInteractionVault extends InteractionVault {
  @override
  InteractionVaultState build() => const InteractionVaultState();

  // In-memory only: skip persistence so tests never touch platform storage
  // and never depend on the base class' late-initialized preference keys.
  @override
  void recordInteraction(
    String postId, {
    bool? upvoted,
    bool? saved,
    bool? commentOpened,
    bool? downvoted,
    bool? dismissed,
  }) {}

  @override
  void markSeen(String postId) {}
}

class _TestSettingsController extends SettingsController {
  _TestSettingsController(this.value);
  final Settings value;

  @override
  Settings build() => value;
}

/// Repository stub whose network mutations succeed silently, so optimistic
/// update paths can be exercised offline.
class _NoopRedditRepository extends RedditRepository {
  _NoopRedditRepository()
      : super(RedditClient(SecureStore(), AuthRepository(SecureStore())));

  @override
  Future<void> vote(String fullname, int dir) async {}

  @override
  Future<void> setSaved(String fullname, bool saved) async {}
}

Settings _settings(PostDisplay display) => Settings(
      themeMode: ThemeMode.dark,
      amoled: true,
      useDynamicColor: false,
      seedColor: AppTheme.seed.toARGB32(),
      blurNsfw: true,
      defaultSort: PostSort.best,
      postDisplay: display,
      swipeActions: false,
      trackHistory: true,
      offlineCache: true,
      checkUpdates: false,
      forYouFeed: false,
      autoHideReadForYou: false,
      midResThumbnails: true,
      subsCacheEnabled: true,
      subsCacheMinutes: 10,
      textScale: 1,
      autoplayMedia: false,
      showApiUsage: false,
      notifyInbox: false,
      topBarMode: TopBarMode.expandable,
      navLabels: true,
    );

Post _post() => Post(
      id: 't3_m3e',
      fullname: 't3_m3e',
      title: 'A readable Material 3 Expressive post card',
      subreddit: 'flutter',
      subredditPrefixed: 'r/flutter',
      author: 'lily',
      score: 128,
      numComments: 24,
      upvoteRatio: 0.98,
      created: DateTime.utc(2026, 1, 1),
      permalink: '/r/flutter/comments/m3e',
      url: 'https://www.reddit.com/r/flutter/comments/m3e',
      domain: 'reddit.com',
      type: PostType.self,
      isSelf: true,
    );

Widget _postHarness({
  required PostDisplay display,
  List<Override> additionalOverrides = const [],
}) {
  return ProviderScope(
    key: ValueKey<String>('settings-${display.name}'),
    overrides: [
      settingsControllerProvider
          .overrideWith(() => _TestSettingsController(_settings(display))),
      interactionVaultProvider.overrideWith(_TestInteractionVault.new),
      historyContainsProvider.overrideWith((ref, id) => false),
      ...additionalOverrides,
    ],
    child: MaterialApp(
      theme: AppTheme.dark(null, amoled: true),
      home: Scaffold(body: PostCard(post: _post())),
    ),
  );
}

Post _imagePost({required int width, required int height, String? url}) =>
    _post().copyWith(
      type: PostType.image,
      isSelf: false,
      previewUrl: url,
      previewWidth: width,
      previewHeight: height,
    );

void main() {
  test('feed media bounds preserve portrait and landscape safety limits', () {
    expect(
      boundedMediaAspectRatio(width: 350, height: 2000),
      closeTo(0.4, 0.0001),
    );
    expect(
      boundedMediaAspectRatio(width: 2400, height: 1000),
      closeTo(1.91, 0.0001),
    );
    expect(
      boundedMediaAspectRatio(width: 4000, height: 3000),
      closeTo(4 / 3, 0.0001),
    );
    expect(
      boundedMediaAspectRatio(width: 1080, height: 1920),
      closeTo(9 / 16, 0.0001),
    );
  });

  test('feed media preserves intrinsic source ratios for variable-height layout', () {
    expect(
      intrinsicMediaAspectRatio(width: 4000, height: 3000),
      closeTo(4 / 3, 0.0001),
    );
    expect(
      intrinsicMediaAspectRatio(width: 1080, height: 1920),
      closeTo(9 / 16, 0.0001),
    );
    expect(
      intrinsicMediaAspectRatio(width: 300, height: 2400),
      closeTo(1 / 8, 0.0001),
    );
    expect(
      intrinsicMediaAspectRatio(width: 2400, height: 600),
      closeTo(4, 0.0001),
    );
  });

  test('feed media cap is derived from viewport metrics', () {
    expect(
      mediaViewportMaxHeight(viewportHeight: 800, verticalPadding: 24),
      closeTo(728, 0.0001),
    );
    expect(
      mediaViewportMaxHeight(viewportHeight: 300, verticalPadding: 24),
      320,
    );
  });

  group('Post.fromData media parsing and URL unescaping', () {
    test('unescapes XML entities in preview and resolution URLs', () {
      final post = Post.fromData({
        'id': 'p1',
        'title': 'Test preview unescaping',
        'preview': {
          'images': [
            {
              'source': {
                'url': 'https://preview.redd.it/test.jpg?width=1080&amp;crop=smart&amp;s=abc123xyz',
                'width': 1080,
                'height': 1920,
              },
              'resolutions': [
                {
                  'url': 'https://preview.redd.it/test.jpg?width=640&amp;crop=smart&amp;s=def456uvw',
                  'width': 640,
                  'height': 1137,
                },
              ],
            },
          ],
        },
      });

      expect(post.previewUrl, 'https://preview.redd.it/test.jpg?width=1080&crop=smart&s=abc123xyz');
      expect(post.previewMedUrl, 'https://preview.redd.it/test.jpg?width=640&crop=smart&s=def456uvw');
      expect(post.previewWidth, 1080);
      expect(post.previewHeight, 1920);
    });

    test('unescapes XML entities in gallery image URLs', () {
      final post = Post.fromData({
        'id': 'p2',
        'title': 'Test gallery unescaping',
        'gallery_data': {
          'items': [
            {'media_id': 'm1'},
          ],
        },
        'media_metadata': {
          'm1': {
            's': {
              'u': 'https://preview.redd.it/gallery1.jpg?width=800&amp;s=xyz789',
              'x': 800,
              'y': 600,
            },
          },
        },
      });

      expect(post.gallery.length, 1);
      expect(post.gallery.first.url, 'https://preview.redd.it/gallery1.jpg?width=800&s=xyz789');
      expect(post.gallery.first.width, 800);
      expect(post.gallery.first.height, 600);
      expect(post.type, PostType.gallery);
    });

    test('unescapes XML entities in thumbnail and main post URLs', () {
      final post = Post.fromData({
        'id': 'p3',
        'title': 'Test thumb and URL unescaping',
        'url': 'https://i.redd.it/img.jpg?auto=webp&amp;s=link123',
        'thumbnail': 'https://b.thumbs.redditmedia.com/thumb.jpg?width=140&amp;crop=smart',
      });

      expect(post.url, 'https://i.redd.it/img.jpg?auto=webp&s=link123');
      expect(post.thumbnailUrl, 'https://b.thumbs.redditmedia.com/thumb.jpg?width=140&crop=smart');
    });

    test('extracts video dimensions from reddit_video when preview is missing', () {
      final post = Post.fromData({
        'id': 'v1',
        'title': 'Portrait video without preview',
        'is_video': true,
        'media': {
          'reddit_video': {
            'width': 1080,
            'height': 1920,
            'fallback_url': 'https://v.redd.it/vid.mp4',
            'hls_url': 'https://v.redd.it/vid.m3u8',
          },
        },
      });

      expect(post.type, PostType.video);
      expect(post.previewWidth, 1080);
      expect(post.previewHeight, 1920);
      expect(post.fallbackVideoUrl, 'https://v.redd.it/vid.mp4');
      expect(post.hlsUrl, 'https://v.redd.it/vid.m3u8');
    });

    test('falls back to crosspost_parent_list for media metadata', () {
      final post = Post.fromData({
        'id': 'cp1',
        'title': 'Crosspost with nested media',
        'crosspost_parent_list': [
          {
            'id': 'orig1',
            'is_video': true,
            'media': {
              'reddit_video': {
                'width': 720,
                'height': 1280,
                'fallback_url': 'https://v.redd.it/parent.mp4',
              },
            },
            'preview': {
              'images': [
                {
                  'source': {
                    'url': 'https://preview.redd.it/parent_thumb.jpg?width=720&amp;s=abc',
                    'width': 720,
                    'height': 1280,
                  },
                },
              ],
            },
          },
        ],
      });

      expect(post.type, PostType.video);
      expect(post.previewWidth, 720);
      expect(post.previewHeight, 1280);
      expect(post.previewUrl, 'https://preview.redd.it/parent_thumb.jpg?width=720&s=abc');
      expect(post.fallbackVideoUrl, 'https://v.redd.it/parent.mp4');
    });
  });

  group('intrinsicMediaAspectRatio and dimension validation', () {
    test('hasMediaDimensions validates positive non-null dimensions', () {
      expect(hasMediaDimensions(width: 100, height: 100), isTrue);
      expect(hasMediaDimensions(width: null, height: 100), isFalse);
      expect(hasMediaDimensions(width: 100, height: null), isFalse);
      expect(hasMediaDimensions(width: 0, height: 100), isFalse);
      expect(hasMediaDimensions(width: 100, height: -1), isFalse);
    });

    test('intrinsicMediaAspectRatio defaults to 4/3 when dimensions are missing', () {
      expect(intrinsicMediaAspectRatio(), closeTo(4 / 3, 0.0001));
      expect(intrinsicMediaAspectRatio(width: null, height: null), closeTo(4 / 3, 0.0001));
      expect(intrinsicMediaAspectRatio(width: 0, height: 0), closeTo(4 / 3, 0.0001));
      expect(intrinsicMediaAspectRatio(width: -10, height: 100), closeTo(4 / 3, 0.0001));
    });

    test('intrinsicMediaAspectRatio supports caller-specified fallback', () {
      expect(intrinsicMediaAspectRatio(fallback: 16 / 9), closeTo(16 / 9, 0.0001));
      expect(intrinsicMediaAspectRatio(width: null, height: null, fallback: 1.0), 1.0);
    });
  });

  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('PostCard uses M3E surface container in AMOLED dark theme',
      (tester) async {
    await tester.pumpWidget(_postHarness(display: PostDisplay.large));
    await tester.pump(const Duration(milliseconds: 500));

    final theme = Theme.of(tester.element(find.byType(PostCard)));
    final card = tester.widget<Container>(find.byWidgetPredicate((widget) {
      if (widget is! Container || widget.margin == null) return false;
      if (widget.margin !=
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8)) {
        return false;
      }
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.color == theme.colorScheme.surfaceContainer;
    }));
    final decoration = card.decoration! as BoxDecoration;

    expect(decoration.color, theme.colorScheme.surfaceContainer);
    expect(decoration.borderRadius, const BorderRadius.all(Radius.circular(24)));
    expect(theme.scaffoldBackgroundColor, Colors.black);
  });

  testWidgets('segmented action bar reports upvote, downvote, and save taps',
      (tester) async {
    var upvotes = 0;
    var downvotes = 0;
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(null),
        home: Scaffold(
          body: M3EPostActionBar(
            score: 12,
            commentCount: 3,
            voteState: 0,
            isSaved: false,
            onVote: (vote) {
              if (vote == 1) upvotes++;
              if (vote == -1) downvotes++;
            },
            onCommentTap: () {},
            onSaveTap: () => saves++,
            onShareTap: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
    await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
    expect(find.byIcon(Icons.shortcut_rounded), findsOneWidget);

    expect(upvotes, 1);
    expect(downvotes, 1);
    expect(saves, 1);
  });

  testWidgets('action bar remains inside a narrow phone width', (tester) async {
    Object? exception;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(null),
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: M3EPostActionBar(
              score: 1234567,
              commentCount: 987654,
              onCommentTap: () {},
              onSaveTap: () {},
              onShareTap: () {},
              onMoreTap: () {},
            ),
          ),
        ),
      ),
    );
    exception = tester.takeException();
    expect(exception, isNull);
    expect(find.byIcon(Icons.shortcut_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
  });

  testWidgets('action controls expose readable semantics and More callback',
      (tester) async {
    var more = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(null),
        home: Scaffold(
          body: M3EPostActionBar(
            score: 3700,
            commentCount: 148,
            onCommentTap: () {},
            onSaveTap: () {},
            onShareTap: () {},
            onMoreTap: () => more++,
          ),
        ),
      ),
    );

    expect(find.text('148'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    expect(more, 1);
    semantics.dispose();
  });

  testWidgets('very tall media gets an intentional full-view affordance',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider
              .overrideWith(() => _TestSettingsController(_settings(PostDisplay.card))),
          interactionVaultProvider.overrideWith(_TestInteractionVault.new),
          historyContainsProvider.overrideWith((ref, id) => false),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null, amoled: true),
          home: Scaffold(
            body: ListView(
              children: [
                PostCard(post: _imagePost(width: 300, height: 2400)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('View full'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings switch between full and compact card layouts',
      (tester) async {
    await tester.pumpWidget(_postHarness(display: PostDisplay.large));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CompactPostCard), findsNothing);
    expect(find.byType(M3EPostActionBar), findsOneWidget);

    await tester.pumpWidget(_postHarness(display: PostDisplay.mini));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CompactPostCard), findsOneWidget);
    expect(find.byType(M3EPostActionBar), findsOneWidget);
  });

  testWidgets('action bar renders the effective score exactly once',
      (tester) async {
    // Regression (Phase 1): the bar used to display score + voteState even
    // though callers pass the override-adjusted effective score, producing a
    // double-counted number for every vote state.
    Future<void> pump(int score, int voteState) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(null),
          home: Scaffold(
            body: M3EPostActionBar(
              score: score,
              commentCount: 3,
              voteState: voteState,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump(100, 0); // neutral
    expect(find.text('100'), findsOneWidget);

    await pump(101, 1); // upvoted effective state
    expect(find.text('101'), findsOneWidget);
    expect(find.text('102'), findsNothing);

    await pump(99, -1); // downvoted / switched effective state
    expect(find.text('99'), findsOneWidget);
    expect(find.text('98'), findsNothing);
  });

  testWidgets('voting through the card adjusts the displayed score exactly once',
      (tester) async {
    // Regression (Phase 1): end-to-end optimistic path — PostCard ->
    // PostOverridesController -> M3EPostActionBar — with one delta per tap.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(
              () => _TestSettingsController(_settings(PostDisplay.large))),
          interactionVaultProvider.overrideWith(_TestInteractionVault.new),
          historyContainsProvider.overrideWith((ref, id) => false),
          sharedPrefsProvider.overrideWithValue(prefs),
          redditRepositoryProvider.overrideWith((ref) {
            return _NoopRedditRepository();
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null, amoled: true),
          home: Scaffold(
            body: ListView(children: [
              PostCard(post: _post().copyWith(score: 100)),
            ]),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('100'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('101'), findsOneWidget);
    expect(find.text('102'), findsNothing);

    // Switching directions applies the single net delta (-2 from up).
    await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('99'), findsOneWidget);
    expect(find.text('98'), findsNothing);

    // And back to upvoted (+2 net).
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('101'), findsOneWidget);
  });

  testWidgets('compact card thumbnail uses BoxFit.cover and center alignment',
      (tester) async {
    final post = _imagePost(
      width: 1200,
      height: 800,
      url: 'https://example.com/thumb.jpg',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider
              .overrideWith(() => _TestSettingsController(_settings(PostDisplay.mini))),
          interactionVaultProvider.overrideWith(_TestInteractionVault.new),
          historyContainsProvider.overrideWith((ref, id) => false),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null, amoled: true),
          home: Scaffold(body: PostCard(post: post)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final imageFinder = find.byType(CachedNetworkImage);
    expect(imageFinder, findsOneWidget);
    final imageWidget = tester.widget<CachedNetworkImage>(imageFinder);
    expect(imageWidget.fit, BoxFit.cover);
    expect(imageWidget.alignment, Alignment.center);
  });

  testWidgets('link preview thumbnail uses BoxFit.cover and center alignment',
      (tester) async {
    final linkPost = _post().copyWith(
      type: PostType.link,
      isSelf: false,
      thumbnailUrl: 'https://example.com/link_thumb.jpg',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider
              .overrideWith(() => _TestSettingsController(_settings(PostDisplay.large))),
          interactionVaultProvider.overrideWith(_TestInteractionVault.new),
          historyContainsProvider.overrideWith((ref, id) => false),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null, amoled: true),
          home: Scaffold(body: PostCard(post: linkPost)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final imageFinder = find.byType(CachedNetworkImage);
    expect(imageFinder, findsOneWidget);
    final imageWidget = tester.widget<CachedNetworkImage>(imageFinder);
    expect(imageWidget.fit, BoxFit.cover);
    expect(imageWidget.alignment, Alignment.center);
  });

  testWidgets('capped tall media uses BoxFit.cover and Alignment.topCenter',
      (tester) async {
    final tallPost = _imagePost(
      width: 300,
      height: 2400,
      url: 'https://example.com/tall_infographic.jpg',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider
              .overrideWith(() => _TestSettingsController(_settings(PostDisplay.card))),
          interactionVaultProvider.overrideWith(_TestInteractionVault.new),
          historyContainsProvider.overrideWith((ref, id) => false),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null, amoled: true),
          home: Scaffold(
            body: ListView(
              children: [
                PostCard(post: tallPost),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final imageFinder = find.byType(CachedNetworkImage);
    expect(imageFinder, findsOneWidget);
    final imageWidget = tester.widget<CachedNetworkImage>(imageFinder);
    expect(imageWidget.fit, BoxFit.cover);
    expect(imageWidget.alignment, Alignment.topCenter);
    expect(find.text('View full'), findsOneWidget);
  });
}
