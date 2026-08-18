import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:luli_for_reddit/core/media_aspect_ratio.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/feed/compact_post_card.dart';
import 'package:luli_for_reddit/features/feed/post_action_bar.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/history/history_store.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/post.dart';

class _TestInteractionVault extends InteractionVault {
  @override
  InteractionVaultState build() => const InteractionVaultState();

  @override
  void recordDwell(String postId) {}
}

class _TestSettingsController extends SettingsController {
  _TestSettingsController(this.value);
  final Settings value;

  @override
  Settings build() => value;
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

Widget _postHarness({required PostDisplay display}) {
  return ProviderScope(
    key: ValueKey<String>('settings-${display.name}'),
    overrides: [
      settingsControllerProvider
          .overrideWith(() => _TestSettingsController(_settings(display))),
      interactionVaultProvider.overrideWith(_TestInteractionVault.new),
      historyContainsProvider.overrideWith((ref, id) => false),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(null, amoled: true),
      home: Scaffold(body: PostCard(post: _post())),
    ),
  );
}

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
            likes: null,
            commentCount: 3,
            saved: false,
            onUpvote: () => upvotes++,
            onDownvote: () => downvotes++,
            onComment: () {},
            onSave: () => saves++,
            onShare: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Upvote'));
    await tester.tap(find.byTooltip('Downvote'));
    await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
    expect(find.byTooltip('Share'), findsOneWidget);

    expect(upvotes, 1);
    expect(downvotes, 1);
    expect(saves, 1);
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
}
