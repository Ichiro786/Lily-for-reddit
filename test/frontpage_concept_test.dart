import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/feed/feed_controller.dart';
import 'package:luli_for_reddit/features/feed/post_action_bar.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/feed/post_list_view.dart';
import 'package:luli_for_reddit/features/home/frontpage_header.dart';
import 'package:luli_for_reddit/features/navigation/m3e_floating_nav_bar.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/post.dart';

import 'support/interaction_fixture.dart';

class _SignedOut extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

class _Feed extends FeedController {
  @override
  Future<FeedState> build(String arg) async => FeedState(
    posts: [
      interactionPost().copyWith(
        title: 'The Andromeda Galaxy captured in ultra-high definition',
        subreddit: 'space',
        subredditPrefixed: 'r/space',
        author: 'StarGazer',
        score: 3700,
        numComments: 148,
        created: DateTime.now().subtract(const Duration(hours: 2)),
        type: PostType.self,
        isSelf: true,
        previewWidth: 800,
        previewHeight: 960,
      ),
      interactionPost().copyWith(
        id: 'p2',
        title: 'Haven’t seen this format in eons',
        subreddit: 'HistoryMemes',
        subredditPrefixed: 'r/HistoryMemes',
        author: 'Vital_Willie',
        score: 212,
        numComments: 42,
      ),
    ],
    sort: PostSort.hot,
    time: TopTime.day,
  );

  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> changeSort(PostSort sort, {TopTime? time}) async {
    ref.read(settingsControllerProvider.notifier).setForYouFeed(false);
    state = AsyncData(state.requireValue.copyWith(sort: sort, time: time));
  }

  @override
  Future<void> selectForYou() async {
    ref.read(settingsControllerProvider.notifier).setForYouFeed(true);
  }
}

Widget _page(GlobalKey key, {required ThemeData theme, double scale = 1}) =>
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(412, 915),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: PostListView(
                feedKey: '',
                frontpageStyle: true,
                header: FrontpageHeader(forYou: false),
              ),
            ),
            floatingActionButton: SizedBox(
              width: 64,
              height: 64,
              child: FloatingActionButton(
                elevation: 0,
                tooltip: 'Create post',
                onPressed: () {},
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),
            bottomNavigationBar: M3EFloatingNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trackHistory': false,
      'swipeActions': false,
      'autoplayMedia': false,
      'midResThumbnails': false,
    });
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  testWidgets('homepage sorts, For You and Top timeframe remain reachable', (
    tester,
  ) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(_SignedOut.new),
          feedControllerProvider.overrideWith(_Feed.new),
        ],
        child: _page(GlobalKey(), theme: AppTheme.dark(null)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final hot = find.widgetWithText(FilterChip, 'Hot');
    final forYou = find.widgetWithText(FilterChip, 'For You');
    expect(tester.widget<FilterChip>(hot).selected, isTrue);
    expect(tester.getTopLeft(hot).dx, lessThan(tester.getTopLeft(forYou).dx));
    await tester.tap(find.widgetWithText(FilterChip, 'New'));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'New'))
          .selected,
      isTrue,
    );
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Top'));
    await tester.tap(find.widgetWithText(FilterChip, 'Top'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Today'));
    await tester.tap(find.widgetWithText(ActionChip, 'Today'));
    await tester.pumpAndSettle();
    expect(find.text('Top posts from'), findsOneWidget);
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'For You'));
    await tester.tap(find.widgetWithText(FilterChip, 'For You'));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'For You'))
          .selected,
      isTrue,
    );
  });

  testWidgets(
    'homepage actions stay reachable at narrow widths and large text',
    (tester) async {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 2.0]) {
          var saved = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark(null),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width - 52,
                      child: M3EPostActionBar(
                        frontpageStyle: true,
                        score: 3700,
                        commentCount: 148,
                        onMoreTap: () {},
                        onSaveTap: () => saved = true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$width / $scale');
          await tester.ensureVisible(
            find.byIcon(Icons.bookmark_outline_rounded),
          );
          await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
          expect(saved, isTrue);
          expect(
            tester.getSize(find.byTooltip('Upvote')).height,
            greaterThanOrEqualTo(48),
          );
        }
      }
    },
  );

  testWidgets('concept actions share a single baseline and compact outlines', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 412.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(null),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width - 48,
                child: M3EPostActionBar(
                  frontpageStyle: true,
                  score: 48900,
                  commentCount: 2400,
                  onMoreTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final icons = [
        Icons.arrow_upward_rounded,
        Icons.arrow_downward_rounded,
        Icons.chat_bubble_outline_rounded,
        Icons.shortcut_rounded,
        Icons.bookmark_outline_rounded,
        Icons.more_vert_rounded,
      ];
      final baseline = tester.getCenter(find.byIcon(icons.first)).dy;
      for (final icon in icons) {
        expect(tester.getCenter(find.byIcon(icon)).dy, closeTo(baseline, 0.1));
      }
      for (final outline in find.byType(AnimatedContainer).evaluate()) {
        expect(tester.getSize(find.byWidget(outline.widget)).height, 36);
      }
      // Large test-font metrics may overflow; every action remains reachable
      // on the same row instead of being wrapped into an unbalanced layout.
      await tester.ensureVisible(find.byIcon(Icons.more_vert_rounded));
      expect(
        find.byIcon(Icons.more_vert_rounded).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('homepage uses scoped card style across color modes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final key = GlobalKey();
    for (final theme in [
      AppTheme.dark(null),
      AppTheme.dark(null, amoled: true),
      AppTheme.light(null),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith(_SignedOut.new),
            feedControllerProvider.overrideWith(_Feed.new),
          ],
          child: _page(key, theme: theme),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<PostCard>(find.byType(PostCard).first).frontpageStyle,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });
}
