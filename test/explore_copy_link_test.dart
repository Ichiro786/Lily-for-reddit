import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/root_messenger.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/explore/explore_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/subreddit.dart';

Subreddit _subreddit() => Subreddit(
      name: 'flutter',
      namePrefixed: 'r/flutter',
      title: 'Flutter Developers',
      description: 'Flutter community.',
      subscribers: 1000,
      iconUrl: null,
      bannerUrl: null,
      userIsSubscriber: true,
    );

Future<void> _pumpExplore(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        subscribedSubredditsProvider.overrideWith((ref) async => [_subreddit()]),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.dark(null),
        home: const Scaffold(body: ExploreScreen()),
      ),
    ),
  );
  // Let the communities provider resolve and the list build.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('copy community link writes the subreddit URL to the clipboard',
      (tester) async {
    // Enlarge the surface so the modal sheet's second list tile is fully
    // on-screen for hit testing.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpExplore(tester, prefs);

    // Regression (Phase 1): this action used to dismiss the sheet without
    // copying anything.
    await tester.tap(find.byTooltip('More community actions').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy community link'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(copied, 'https://reddit.com/r/flutter');
    expect(find.byType(SnackBar), findsOneWidget);

    // Drain the snackbar auto-dismiss timer so no timers are left pending.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
