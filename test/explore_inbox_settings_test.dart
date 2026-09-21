import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/explore/explore_screen.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/history/history_store.dart';
import 'package:luli_for_reddit/features/history/visited_subreddits_store.dart';
import 'package:luli_for_reddit/features/inbox/inbox_screen.dart';
import 'package:luli_for_reddit/features/inbox/m3e_inbox_widgets.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/features/settings/settings_screen.dart';
import 'package:luli_for_reddit/models/inbox_item.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'package:luli_for_reddit/models/subreddit.dart';

class _TestInboxRepository extends RedditRepository {
  _TestInboxRepository()
      : super(RedditClient(SecureStore(), AuthRepository(SecureStore())));

  @override
  Future<Listing<InboxItem>> getInbox(
      {String where = 'inbox', String? after}) async {
    return Listing(
      items: [
        InboxItem(
          fullname: 't4_1',
          kind: InboxKind.message,
          author: 'alice',
          subject: 'Hello there',
          body: 'A private message body',
          created: DateTime.utc(2026, 1, 1),
        ),
      ],
      after: null,
    );
  }
}

class _FakeHistoryController extends HistoryController {
  @override
  List<HistoryEntry> build() => const <HistoryEntry>[];
}

class _FakeVisitedCommunityController extends VisitedCommunityController {
  _FakeVisitedCommunityController(this._initial);
  final List<Subreddit> _initial;

  @override
  List<Subreddit> build() => _initial;
}

class _FakeAuthenticatedAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession(username: 'testuser');
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.dark(null),
      home: Scaffold(body: child),
    );

Subreddit _subreddit({
  String name = 'flutter',
  bool favorite = false,
  int? accountsActive,
}) {
  return Subreddit(
    name: name,
    namePrefixed: 'r/$name',
    title: name,
    description: 'A community',
    subscribers: 120000,
    accountsActive: accountsActive,
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

  testWidgets('Explore screen matches M3E blueprint with headline, chip row, and live stats',
      (tester) async {
    final visited = [
      _subreddit(name: 'dart', accountsActive: 1240),
    ];
    final communities = [_subreddit(name: 'flutter'), _subreddit(name: 'dart')];
    final popular = [_subreddit(name: 'technology', accountsActive: 4500)];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscribedSubredditsProvider.overrideWith((ref) async => communities),
          popularSubredditsProvider.overrideWith((ref) async => popular),
          visitedCommunityStoreProvider.overrideWith(
            () => _FakeVisitedCommunityController(visited),
          ),
          historyControllerProvider.overrideWith(_FakeHistoryController.new),
        ],
        child: _app(const ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 1. "Explore" headline sliver
    expect(find.text('Explore'), findsOneWidget);

    // 2. Search dock hint
    expect(find.text('Search communities & posts'), findsOneWidget);

    // 3. Filter chips
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Joined'), findsWidgets);

    // 4. Section hierarchy: "Recently visited" precedes "Popular near you"
    final recentPos = tester.getTopLeft(find.text('Recently visited')).dy;
    final popularPos = tester.getTopLeft(find.text('Popular near you')).dy;
    expect(recentPos, lessThan(popularPos));

    // 5. "See all >" action button
    expect(find.text('See all >'), findsOneWidget);

    // 6. Live online count indicator
    expect(find.textContaining('online'), findsWidgets);
  });

  testWidgets('VisitedCommunityController persists and deduplicates community visits',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final ctrl = container.read(visitedCommunityStoreProvider.notifier);
    expect(container.read(visitedCommunityStoreProvider), isEmpty);

    final sub1 = _subreddit(name: 'flutter');
    final sub2 = _subreddit(name: 'dart', accountsActive: 350);

    ctrl.recordVisit(sub1);
    expect(container.read(visitedCommunityStoreProvider).length, 1);
    expect(container.read(visitedCommunityStoreProvider).first.name, 'flutter');

    ctrl.recordVisit(sub2);
    expect(container.read(visitedCommunityStoreProvider).length, 2);
    expect(container.read(visitedCommunityStoreProvider).first.name, 'dart');

    // Re-visiting sub1 moves it back to top
    ctrl.recordVisit(sub1);
    expect(container.read(visitedCommunityStoreProvider).length, 2);
    expect(container.read(visitedCommunityStoreProvider).first.name, 'flutter');

    // Favorite toggle updates in state
    ctrl.setFavorite('flutter', true);
    expect(container.read(visitedCommunityStoreProvider).first.userHasFavorited, isTrue);

    // Subscribed toggle updates in state
    ctrl.setSubscribed('flutter', false);
    expect(container.read(visitedCommunityStoreProvider).first.userIsSubscriber, isFalse);

    // Remove
    ctrl.remove('flutter');
    expect(container.read(visitedCommunityStoreProvider).length, 1);
    expect(container.read(visitedCommunityStoreProvider).first.name, 'dart');

    // Clear
    ctrl.clear();
    expect(container.read(visitedCommunityStoreProvider), isEmpty);

    // Drain any pending debounce timers
    await tester.pump(const Duration(seconds: 1));
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

    final targetColor = AppTheme.accentSwatches[1];
    final swatch = find.byKey(ValueKey<String>('theme-swatch-${targetColor.toARGB32()}'));
    expect(swatch, findsOneWidget);
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsList)),
      ).read(settingsControllerProvider).seedColor,
      targetColor.toARGB32(),
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

  testWidgets('SettingsList renders guest card when unauthenticated and standalone',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

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
  });

  testWidgets('SettingsList renders profile header when authenticated and standalone',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authModeProvider.overrideWith((ref) async => 'oauth'),
          authControllerProvider
              .overrideWith(_FakeAuthenticatedAuthController.new),
        ],
        child: _app(const SettingsList(embedded: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('u/testuser'), findsOneWidget);
    expect(find.text('Guest'), findsNothing);
  });

  testWidgets('SettingsList does not render profile or guest header when embedded',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

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

  testWidgets('Inbox empty state and guest view render correctly',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            Expanded(child: M3EInboxEmptyState()),
            Expanded(child: M3EInboxGuestView()),
          ],
        ),
      ),
    );
    expect(find.text('No messages'), findsOneWidget);
    expect(find.text('Sign in to view your inbox'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('InboxScreen renders M3E app bar overflow menu, filter bar, and items',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _TestInboxRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          redditRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: const InboxScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.byTooltip('Mark this tab read'), findsOneWidget);
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.byTooltip('New message'), findsOneWidget);

    // Verify filter bar
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Replies'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);

    // Verify overflow menu
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Sent messages'), findsOneWidget);
    expect(find.text('Notification settings'), findsOneWidget);
  });
}
