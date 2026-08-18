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
          historyControllerProvider.overrideWithValue(const <HistoryEntry>[]),
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

    final swatch = find.byKey(const ValueKey<String>('theme-swatch-4289170426'));
    expect(swatch, findsOneWidget);
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsList)),
      ).read(settingsControllerProvider).seedColor,
      4289170426,
    );
  });
}
