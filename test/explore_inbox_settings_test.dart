import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/explore/explore_screen.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/history/history_store.dart';
import 'package:luli_for_reddit/features/inbox/m3e_inbox_widgets.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/features/settings/settings_screen.dart';
import 'package:luli_for_reddit/models/inbox_item.dart';
import 'package:luli_for_reddit/models/subreddit.dart';

class _FakeHistoryController extends HistoryController {
  @override
  List<HistoryEntry> build() => const <HistoryEntry>[];
}

class _FakeAuthenticatedAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession(username: 'testuser');
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.dark(null),
      home: Scaffold(body: child),
    );

Subreddit _subreddit({String name = 'flutter', bool favorite = false}) {
  return Subreddit(
    name: name,
    namePrefixed: 'r/$name',
    title: name,
    description: 'A community',
    subscribers: 120000,
    userHasFavorited: favorite,
    userIsSubscriber: true,
  );
}

void main() {
  testWidgets('Explore search dock and category filter selection work',
      (tester) async {
    final communities = [_subreddit(), _subreddit(name: 'dart')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscribedSubredditsProvider.overrideWith((ref) async => communities),
          historyControllerProvider.overrideWith(_FakeHistoryController.new),
        ],
        child: _app(const ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Popular near you'), findsOneWidget);
    expect(find.text('r/flutter'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'dart');
    await tester.pumpAndSettle();
    expect(find.text('r/dart'), findsWidgets);
    expect(find.text('r/flutter'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Joined'));
    await tester.pumpAndSettle();
    expect(find.text('Joined'), findsWidgets);
  });

  testWidgets('Inbox category tabs switch and unread dot renders',
      (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      _app(
        DefaultTabController(
          length: M3EInboxCategoryTabs.labels.length,
          child: Column(
            children: [
              M3EInboxCategoryTabs(onChanged: (index) => selected = index),
              M3EInboxMessageCard(
                item: InboxItem(
                  fullname: 't4_message',
                  kind: InboxKind.message,
                  author: 'alice',
                  subject: 'Hello',
                  body: 'Unread message body',
                  created: DateTime.utc(2026, 1, 1),
                  isNew: true,
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('inbox-unread-dot')), findsOneWidget);
    await tester.tap(find.text('Mentions'));
    await tester.pumpAndSettle();
    expect(selected, 3);
  });

  testWidgets('grouped Settings panels toggle AMOLED and select palette color',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authModeProvider.overrideWith((ref) async => 'oauth'),
        ],
        child: _app(const SettingsList()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    final amoled = find.byType(SwitchListTile).first;
    expect(tester.widget<SwitchListTile>(amoled).value, isFalse);
    await tester.tap(amoled);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(amoled).value, isTrue);

    // Verify all 8 curated M3E swatches render
    for (final c in AppTheme.accentSwatches) {
      expect(
        find.byKey(ValueKey<String>('theme-swatch-${c.toARGB32()}')),
        findsOneWidget,
      );
    }

    final swatch = find.byKey(const ValueKey<String>('theme-swatch-4289763866'));
    expect(swatch, findsOneWidget);
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsList)),
      ).read(settingsControllerProvider).seedColor,
      4289763866,
    );
  });

  testWidgets('dynamic color switch dims accent swatches and displays helper note',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authModeProvider.overrideWith((ref) async => 'oauth'),
        ],
        child: _app(const SettingsList()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Wallpaper colors override custom accents when Dynamic color is enabled'),
      findsNothing,
    );

    final dynamicSwitch = find.widgetWithText(SwitchListTile, 'Dynamic color');
    expect(dynamicSwitch, findsOneWidget);
    await tester.tap(dynamicSwitch);
    await tester.pumpAndSettle();

    expect(
      find.text('Wallpaper colors override custom accents when Dynamic color is enabled'),
      findsOneWidget,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsList)),
      ).read(settingsControllerProvider).useDynamicColor,
      isTrue,
    );
  });

  testWidgets('SettingsList renders profile header when authenticated and guest card when guest',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // 1. Guest state (standalone SettingsList)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authModeProvider.overrideWith((ref) async => 'oauth'),
        ],
        child: _app(const SettingsList(embedded: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Sign in to customize and sync'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    // 2. Authenticated state (standalone SettingsList)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authModeProvider.overrideWith((ref) async => 'oauth'),
          authControllerProvider
              .overrideWith(() => _FakeAuthenticatedAuthController()),
        ],
        child: _app(const SettingsList(embedded: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('u/testuser'), findsOneWidget);
    expect(find.text('Guest'), findsNothing);

    // 3. Embedded state (inside AccountTab) should not render profile or guest card in SettingsList
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authModeProvider.overrideWith((ref) async => 'oauth'),
        ],
        child: _app(const SettingsList(embedded: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guest'), findsNothing);
    expect(find.text('u/testuser'), findsNothing);
  });
}
