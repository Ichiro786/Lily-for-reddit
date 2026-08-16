import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/feed/post_overrides.dart';
import 'package:luli_for_reddit/features/history/history_store.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/post.dart';

class _TestSettingsController extends SettingsController {
  @override
  Settings build() => const Settings(
        themeMode: ThemeMode.light,
        amoled: false,
        useDynamicColor: false,
        seedColor: AppTheme.seed,
        blurNsfw: true,
        defaultSort: PostSort.best,
        postDisplay: PostDisplay.large,
        swipeActions: true,
        trackHistory: true,
        offlineCache: true,
        checkUpdates: false,
        forYouFeed: false,
        autoHideReadForYou: false,
        midResThumbnails: true,
        subsCacheEnabled: true,
        subsCacheMinutes: 10,
        textScale: 1.0,
        autoplayMedia: false,
        showApiUsage: false,
        notifyInbox: false,
        topBarMode: TopBarMode.expandable,
        navLabels: true,
      );
}

class _TestHistoryController extends HistoryController {
  @override
  List<HistoryEntry> build() => const [];
}

class _TestPostOverridesController extends PostOverridesController {
  @override
  Map<String, PostOverride> build() => const {};
}

void main() {
  testWidgets('PostCard action bar does not overflow at 360px width',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final post = Post.fromData({
      'id': 'test_overflow',
      'title': 'Narrow screen overflow test post title with ample text',
      'subreddit': 'flutterdev',
      'score': 12345,
      'num_comments': 890,
      'created_utc': 1700000000,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          settingsControllerProvider.overrideWith(_TestSettingsController.new),
          historyControllerProvider.overrideWith(_TestHistoryController.new),
          historyContainsProvider.overrideWith((ref, id) => false),
          postOverridesProvider
              .overrideWith(_TestPostOverridesController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(null),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: PostCard(post: post),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PostCard), findsOneWidget);
    // If an overflow occurs, Flutter throws a rendering exception.
    expect(tester.takeException(), isNull);
  });
}
