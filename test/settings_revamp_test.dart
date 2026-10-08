import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/profile/profile_providers.dart';
import 'package:luli_for_reddit/features/settings/settings_catalog.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/features/settings/settings_screen.dart';
import 'package:luli_for_reddit/models/reddit_user.dart';

class SettingsAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession(username: 'alice');
}

Future<(ProviderContainer, GoRouter, SharedPreferences)> mount(
  WidgetTester tester, {
  Map<String, Object> initial = const {},
  bool large = false,
  ColorScheme? dynamicScheme,
  bool amoled = true,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authControllerProvider.overrideWith(SettingsAuth.new),
      authModeProvider.overrideWith((ref) async => 'oauth'),
      accountsProvider.overrideWith((ref) async => ['alice']),
      userAboutProvider.overrideWith(
        (ref, name) async => RedditUser(
          name: name,
          displayName: 'Alice',
          created: DateTime.utc(2023),
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/u/:name',
        builder: (_, state) =>
            Scaffold(body: Text('Profile ${state.pathParameters['name']}')),
      ),
      GoRoute(
        path: '/manage_for_you',
        builder: (_, __) =>
            const Scaffold(body: Text('Manage feed destination')),
      ),
      GoRoute(
        path: '/history',
        builder: (_, __) => const Scaffold(body: Text('History destination')),
      ),
      GoRoute(
        path: '/policy',
        builder: (_, __) => const Scaffold(body: Text('Policy destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: AppTheme.dark(dynamicScheme, amoled: amoled),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
          child: Directionality(
            textDirection: large ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (c, router, prefs);
}

Future<void> open(WidgetTester tester, SettingsCategory category) async {
  final row = find.widgetWithText(SettingsNavigationRow, category.title);
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> toggle(WidgetTester tester, String title) async {
  final tile = find.widgetWithText(SwitchListTile, title);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'all 32 original settings plus account management have stable searchable destinations',
    () {
      expect(SettingId.values.length, 33);
      expect(SettingId.values.map((item) => item.name).toSet().length, 33);
      for (final item in SettingId.values) {
        expect(item.matches(item.title), true);
        expect(item.keywords, isNotEmpty);
      }
      expect(SettingId.accent.matches('custom palette'), true);
      expect(SettingId.font.matches('text slider'), true);
      expect(SettingId.apiUsage.matches('rate limit'), true);
    },
  );

  testWidgets(
    'all seven categories retain every control and Android back returns home',
    (tester) async {
      final (_, router, _) = await mount(tester);
      for (final category in SettingsCategory.values) {
        await open(tester, category);
        expect(find.byType(SettingsCategoryScreen), findsOneWidget);
        for (final item in SettingId.values.where(
          (item) => item.category == category,
        )) {
          expect(find.byKey(ValueKey('setting-${item.name}')), findsOneWidget);
        }
        expect(await router.routerDelegate.popRoute(), true);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsCategoryScreen), findsNothing);
        expect(find.text('Settings'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search navigates to accent, font slider, and API usage, preserving query on return',
    (tester) async {
      final (_, router, _) = await mount(tester);
      for (final item in [
        SettingId.accent,
        SettingId.font,
        SettingId.apiUsage,
        SettingId.cacheTime,
      ]) {
        await tester.enterText(find.byType(TextField), item.keywords);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('search-${item.name}')));
        await tester.pumpAndSettle();
        final target = find.byKey(ValueKey('setting-${item.name}'));
        expect(target.hitTestable(), findsOneWidget);
        expect(
          tester.widget<Container>(target).decoration,
          isA<BoxDecoration>(),
        );
        expect(await router.routerDelegate.popRoute(), true);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          item.keywords,
        );
      }
      await tester.enterText(find.byType(TextField), 'zzzz unknown setting');
      await tester.pumpAndSettle();
      expect(find.text('No settings found'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear settings search'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'appearance preserves saved values and writes the same keys from UI controls',
    (tester) async {
      final (c, _, prefs) = await mount(
        tester,
        initial: {
          'themeMode': 2,
          'amoled': true,
          'useDynamicColor': false,
          'seedColor': AppTheme.accentSwatches[2].toARGB32(),
          'textScale': 1.2,
          'navLabels': false,
        },
      );
      await open(tester, SettingsCategory.appearance);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('120% of normal'), findsOneWidget);
      await toggle(tester, 'AMOLED black');
      expect(prefs.getBool('amoled'), false);
      await tester.ensureVisible(find.text('Theme'));
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(prefs.getInt('themeMode'), ThemeMode.light.index);
      final swatch = find.byKey(
        ValueKey('theme-swatch-${AppTheme.accentSwatches[1].toARGB32()}'),
      );
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pumpAndSettle();
      expect(prefs.getInt('seedColor'), AppTheme.accentSwatches[1].toARGB32());
      await toggle(tester, 'Dynamic color');
      expect(prefs.getBool('useDynamicColor'), true);
      await tester.ensureVisible(swatch);
      await tester.tap(swatch, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(prefs.getInt('seedColor'), AppTheme.accentSwatches[1].toARGB32());
      await toggle(tester, 'Dynamic color');
      expect(prefs.getBool('useDynamicColor'), false);
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(prefs.getDouble('textScale'), greaterThan(1.2));
      await toggle(tester, 'Bottom bar labels');
      expect(prefs.getBool('navLabels'), true);
      c.invalidate(settingsControllerProvider);
      expect(c.read(settingsControllerProvider).navLabels, true);
      expect(
        c.read(settingsControllerProvider).textScale,
        prefs.getDouble('textScale'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'feed, power, history, and update toggles keep their preference keys',
    (tester) async {
      final (_, router, prefs) = await mount(tester);
      const settings = {
        SettingsCategory.feed: {
          'Blur NSFW media': 'blurNsfw',
          'Data-saver thumbnails': 'midResThumbnails',
          'Hide read posts automatically': 'hideReadPosts',
          'Resume feeds where I left off': 'resumeFeeds',
        },
        SettingsCategory.power: {
          'Swipe to vote': 'swipeActions',
          'Autoplay videos': 'autoplayMedia',
        },
        SettingsCategory.history: {
          'Track history': 'trackHistory',
          'Offline cache': 'offlineCache',
          'Cache subscriptions': 'subsCacheEnabled',
        },
        SettingsCategory.about: {'Check for updates': 'checkUpdates'},
      };
      for (final category in settings.entries) {
        await open(tester, category.key);
        for (final control in category.value.entries) {
          final tile = find.widgetWithText(SwitchListTile, control.key);
          final before = tester.widget<SwitchListTile>(tile).value;
          await toggle(tester, control.key);
          expect(prefs.getBool(control.value), !before);
        }
        expect(await router.routerDelegate.popRoute(), true);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selection controls and disabled cache duration retain behavior',
    (tester) async {
      final (_, router, prefs) = await mount(tester);
      await open(tester, SettingsCategory.feed);
      await tester.tap(find.text('Default sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(prefs.getInt('defaultSort'), isNotNull);
      await tester.tap(find.text('Post display'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mini cards'));
      await tester.pumpAndSettle();
      expect(prefs.getInt('postDisplay'), PostDisplay.mini.index);
      await router.routerDelegate.popRoute();
      await tester.pumpAndSettle();
      await open(tester, SettingsCategory.history);
      final duration = find.widgetWithText(
        ListTile,
        'Subscriptions cache time',
      );
      await tester.ensureVisible(duration);
      await tester.tap(duration);
      await tester.pumpAndSettle();
      await tester.tap(find.text('60 minutes'));
      await tester.pumpAndSettle();
      expect(prefs.getInt('subsCacheMinutes'), 60);
      await toggle(tester, 'Cache subscriptions');
      expect(tester.widget<ListTile>(duration).enabled, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact profile opens full profile and destructive actions retain confirmation',
    (tester) async {
      final (_, router, prefs) = await mount(
        tester,
        initial: {'textScale': 1.2},
      );
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      expect(find.text('Profile alice'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await open(tester, SettingsCategory.account);
      await tester.tap(find.text('Clear all data'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all data?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(prefs.getDouble('textScale'), 1.2);
      await tester.tap(find.text('Reddit API credentials'));
      await tester.pumpAndSettle();
      expect(find.text('Re-enter credentials?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsCategoryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all categories fit narrow RTL 200% text with dynamic AMOLED and normal dark themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dynamic = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      );
      final (_, router, _) = await mount(
        tester,
        large: true,
        dynamicScheme: dynamic,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        null,
      );
      expect(
        Theme.of(
          tester.element(find.byType(SettingsScreen)),
        ).scaffoldBackgroundColor,
        Colors.black,
      );
      for (final category in SettingsCategory.values) {
        await open(tester, category);
        expect(tester.takeException(), isNull, reason: category.title);
        await router.routerDelegate.popRoute();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount(tester, large: true, dynamicScheme: dynamic, amoled: false);
      expect(
        Theme.of(
          tester.element(find.byType(SettingsScreen)),
        ).scaffoldBackgroundColor,
        isNot(Colors.black),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
