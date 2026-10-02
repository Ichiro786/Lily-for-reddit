import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/core/widgets/error_view.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/explore/explore_screen.dart';
import 'package:luli_for_reddit/features/feed/feed_controller.dart';
import 'package:luli_for_reddit/features/feed/post_list_view.dart';
import 'package:luli_for_reddit/features/home/home_shell.dart';
import 'package:luli_for_reddit/features/history/visited_subreddits_store.dart';
import 'package:luli_for_reddit/features/inbox/inbox_controller.dart';
import 'package:luli_for_reddit/features/inbox/inbox_screen.dart';
import 'package:luli_for_reddit/features/navigation/m3e_floating_nav_bar.dart';
import 'package:luli_for_reddit/features/search/search_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/inbox_item.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'package:luli_for_reddit/models/subreddit.dart';
import 'support/interaction_fixture.dart';

class _Auth extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession(username: 'alice');
  Future<void> changeAccount() => runSessionChange(() async {
    state = const AsyncData(AuthSession(username: 'bob'));
  });
}

class _Feed extends FeedController {
  @override
  Future<FeedState> build(String arg) async =>
      const FeedState(posts: [], sort: PostSort.hot, time: TopTime.day);
}

class _Unread extends UnreadCountController {
  @override
  int build() => 0;
}

class _MotionFeed extends FeedController {
  _MotionFeed(this.populated);
  final bool populated;
  int refreshes = 0;
  @override
  Future<FeedState> build(String arg) async => FeedState(
    posts: populated ? [interactionPost()] : [],
    sort: PostSort.hot,
    time: TopTime.day,
  );
  @override
  Future<void> refresh() async {
    refreshes++;
  }
}

class _Repo extends InteractionRepository {
  Completer<void>? join;
  int joins = 0;
  bool joined = false, favorite = false, failDelete = false;
  final inboxRequests = <String>[];
  Subreddit get community => Subreddit(
    name: 'LongCommunityName',
    namePrefixed: 'r/LongCommunityName',
    title: 'A community',
    description: '',
    subscribers: 120000,
    accountsActive: 120,
    userIsSubscriber: joined,
    userHasFavorited: favorite,
  );
  @override
  Future<List<Subreddit>> getSubscribedSubreddits({bool force = false}) async =>
      [];
  @override
  Future<List<Subreddit>> getPopularSubreddits({int limit = 15}) async => [
    community,
  ];
  @override
  Future<void> setSubscribed(String name, bool next) async {
    joins++;
    if (join != null) await join!.future;
    joined = next;
  }

  @override
  Future<void> setSubredditFavorite(String name, bool next) async =>
      favorite = next;

  @override
  Future<Listing<InboxItem>> getInbox({
    String where = 'inbox',
    String? after,
  }) async {
    inboxRequests.add(where);
    return Listing(
      items: [
        InboxItem(
          fullname: 't4_$where',
          kind: InboxKind.message,
          author: 'alice',
          subject: '$where subject',
          body: 'A message body',
          created: DateTime.utc(2026),
        ),
      ],
      after: null,
    );
  }

  @override
  Future<void> deleteMessage(String fullname) async {
    if (failDelete) throw StateError('offline');
  }
}

class _Visits extends VisitedCommunityController {
  _Visits(this.initial);
  final Subreddit initial;
  @override
  List<Subreddit> build() => [initial];
}

Future<ProviderContainer> _container(
  _Repo repo, {
  FeedController Function()? feed,
}) async {
  SharedPreferences.setMockInitialValues({
    'notifyInboxPrompted': true,
    'checkUpdates': false,
  });
  return ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      redditRepositoryProvider.overrideWithValue(repo),
      authControllerProvider.overrideWith(_Auth.new),
      feedControllerProvider.overrideWith(feed ?? _Feed.new),
      unreadCountProvider.overrideWith(_Unread.new),
      inboxFailureProvider.overrideWithValue((_) {}),
      visitedCommunityStoreProvider.overrideWith(() => _Visits(repo.community)),
    ],
  );
}

Widget _app(
  ProviderContainer container,
  Widget child, {
  bool light = false,
  double scale = 1,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: light ? AppTheme.light(null) : AppTheme.dark(null),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  testWidgets('reselecting an empty feed still starts a visible refresh', (
    tester,
  ) async {
    final container = await _container(_Repo(), feed: () => _MotionFeed(false));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _app(container, const Scaffold(body: PostListView(feedKey: ''))),
    );
    await tester.pumpAndSettle();
    container.read(frontpageScrollSignalProvider.notifier).state++;
    await tester.pumpAndSettle();
    expect(
      (container.read(feedControllerProvider('').notifier) as _MotionFeed)
          .refreshes,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced-motion feed reselect jumps to top without animateTo assertion',
    (tester) async {
      final container = await _container(
        _Repo(),
        feed: () => _MotionFeed(true),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _app(
          container,
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: PostListView(feedKey: '', header: SizedBox(height: 1200)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      list.controller!.jumpTo(200);
      await tester.pump();
      container.read(frontpageScrollSignalProvider.notifier).state++;
      await tester.pump();
      expect(list.controller!.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final light in [false, true]) {
    testWidgets(
      'focused Discover search matches its pill in ${light ? 'light' : 'dark'} theme',
      (tester) async {
        final container = await _container(_Repo());
        addTearDown(container.dispose);
        await tester.pumpWidget(
          _app(container, const ExploreScreen(), light: light),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        final decoration = tester.widget<InputDecorator>(
          find.byType(InputDecorator),
        );
        expect(decoration.isFocused, isTrue);
        expect(decoration.decoration.filled, isFalse);
        expect(decoration.decoration.focusedBorder, InputBorder.none);
        expect(decoration.decoration.enabledBorder, InputBorder.none);
        final material = tester.widget<Material>(
          find
              .ancestor(
                of: find.byType(TextField),
                matching: find.byType(Material),
              )
              .first,
        );
        final scheme = Theme.of(
          tester.element(find.byType(TextField)),
        ).colorScheme;
        expect(material.color, scheme.surfaceContainerHighest);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'shell briefly delays upward reveal and idle events preserve it',
    (tester) async {
      final container = await _container(_Repo());
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container, const HomeShell()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(HomeShell));
      final listener = tester.widget<NotificationListener<ScrollNotification>>(
        find.byWidgetPredicate(
          (w) =>
              w is NotificationListener<ScrollNotification> &&
              w.child is SafeArea,
        ),
      );
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 200,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
      void direction(ScrollDirection direction) => listener.onNotification!(
        UserScrollNotification(
          metrics: metrics,
          context: context,
          direction: direction,
        ),
      );
      bool visible() => tester
          .widget<M3EFloatingNavBar>(find.byType(M3EFloatingNavBar))
          .isVisible;
      direction(ScrollDirection.reverse);
      await tester.pumpAndSettle();
      expect(visible(), isFalse);
      direction(ScrollDirection.forward);
      await tester.pump(const Duration(milliseconds: 32));
      expect(visible(), isFalse);
      direction(ScrollDirection.idle);
      await tester.pump(const Duration(milliseconds: 40));
      expect(visible(), isTrue);
      await tester.pumpAndSettle();
      direction(ScrollDirection.reverse);
      await tester.pumpAndSettle();
      direction(ScrollDirection.forward);
      await tester.pump(const Duration(milliseconds: 20));
      direction(ScrollDirection.reverse);
      await tester.pump(const Duration(milliseconds: 80));
      expect(visible(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Discover double tap focuses its own search from Home and already-selected Discover',
    (tester) async {
      final container = await _container(_Repo());
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeShell()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.dark(null),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Toolbar'), findsNothing);
      expect(find.byTooltip('Display'), findsNothing);
      final discover = find.descendant(
        of: find.byType(M3EFloatingNavBar),
        matching: find.text('Discover'),
      );
      await tester.tap(discover);
      await tester.pump();
      expect(
        tester
            .widget<M3EFloatingNavBar>(find.byType(M3EFloatingNavBar))
            .currentIndex,
        1,
      );
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(discover);
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsNothing);
      final search = find.descendant(
        of: find.byType(ExploreScreen),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      tester.widget<TextField>(search).focusNode!.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(discover);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(discover);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.byType(SearchScreen), findsNothing);
      // Android Back can dismiss the keyboard without unfocusing the field.
      tester.testTextInput.hide();
      await tester.pump();
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
      await tester.tap(discover);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(discover);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester
            .widget<M3EFloatingNavBar>(find.byType(M3EFloatingNavBar))
            .currentIndex,
        1,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(M3EFloatingNavBar),
          matching: find.text('Inbox'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('New message').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.byTooltip('New message')).bottom,
        lessThan(tester.getRect(find.byType(M3EFloatingNavBar)).top),
      );
    },
  );

  testWidgets('Posts search leaves the community filter usable on return', (
    tester,
  ) async {
    final container = await _container(_Repo());
    addTearDown(container.dispose);
    String? query;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ExploreScreen()),
        GoRoute(
          path: '/search',
          builder: (_, state) {
            query = state.uri.queryParameters['q'];
            return const Scaffold(body: Text('Search route'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Long');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Posts'));
    await tester.pumpAndSettle();
    expect(query, 'Long');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('r/LongCommunityName'), findsWidgets);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'All'))
          .selected,
      isTrue,
    );
  });

  testWidgets(
    'joining prevents duplicate requests and ignores completion after account switch',
    (tester) async {
      final repo = _Repo()..join = Completer<void>();
      final container = await _container(repo);
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container, const ExploreScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join'));
      await tester.tap(find.text('Join'));
      expect(repo.joins, 1);
      await (container.read(authControllerProvider.notifier) as _Auth)
          .changeAccount();
      await tester.pumpAndSettle();
      repo.join!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Joined'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'single Inbox tab row routes Mentions and Messages to the right endpoints',
    (tester) async {
      final repo = _Repo();
      final container = await _container(repo);
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container, const InboxScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      final labels = tester
          .widgetList<Tab>(find.byType(Tab))
          .map((tab) => tab.text)
          .toList();
      expect(labels, ['All', 'Unread', 'Mentions', 'Messages', 'Sent']);
      for (final (label, endpoint) in const [
        ('Mentions', 'mentions'),
        ('Messages', 'messages'),
        ('Unread', 'unread'),
        ('Sent', 'sent'),
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(repo.inboxRequests, contains(endpoint));
        expect(find.text('$endpoint subject').hitTestable(), findsOneWidget);
      }
    },
  );

  testWidgets(
    'failed Inbox deletion restores the card without a dismissed-widget assertion',
    (tester) async {
      final repo = _Repo()..failDelete = true;
      final container = await _container(repo);
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container, const InboxScreen()));
      await tester.pumpAndSettle();
      await tester.drag(find.text('inbox subject'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('inbox subject'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'joined and favorite states update across recent and popular cards',
    (tester) async {
      final container = await _container(_Repo());
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container, const ExploreScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(find.text('Joined'), findsOneWidget);
      await tester.tap(find.byTooltip('Add favorite'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove favorite'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Favorites'));
      await tester.tap(find.byTooltip('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('r/LongCommunityName'), findsWidgets);
    },
  );

  testWidgets(
    'community completion after leaving Explore does not use a disposed ref',
    (tester) async {
      final repo = _Repo()..join = Completer<void>();
      final container = await _container(repo);
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container, const ExploreScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join'));
      await tester.pumpWidget(const SizedBox());
      repo.join!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('popular retry succeeds even when subscriptions fail', (
    tester,
  ) async {
    final repo = _Repo();
    final container = await _container(repo);
    addTearDown(container.dispose);
    var attempts = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ProviderScope(
          overrides: [
            subscribedSubredditsProvider.overrideWith(
              (_) => Future.error(StateError('offline')),
            ),
            popularSubredditsProvider.overrideWith((_) async {
              if (++attempts == 1) throw StateError('offline');
              return [repo.community];
            }),
          ],
          child: MaterialApp(home: const ExploreScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final error = find.ancestor(
      of: find.text('Could not load popular communities. Please try again.'),
      matching: find.byType(ErrorView),
    );
    final retry = find.descendant(of: error, matching: find.text('Retry'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(retry.hitTestable(), findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(
      find.text('Could not load popular communities. Please try again.'),
      findsNothing,
    );
    expect(
      find.text('Could not load communities. Please try again.'),
      findsOneWidget,
    );
  });

  for (final light in [false, true]) {
    for (final width in [320.0, 390.0]) {
      testWidgets(
        'Discover and Inbox fit width $width at 200% text in ${light ? 'light' : 'dark'} theme',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = await _container(_Repo());
          addTearDown(container.dispose);
          for (final screen in [const ExploreScreen(), const InboxScreen()]) {
            await tester.pumpWidget(
              _app(container, screen, light: light, scale: 2),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
