import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/search/search_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'package:luli_for_reddit/models/post.dart';
import 'package:luli_for_reddit/models/reddit_user.dart';
import 'package:luli_for_reddit/models/subreddit.dart';

const _flutter = Subreddit(
  name: 'Flutter',
  namePrefixed: 'r/Flutter',
  title: 'Flutter',
  description: '',
  subscribers: 120000,
);
const _dart = Subreddit(
  name: 'dartlang',
  namePrefixed: 'r/dartlang',
  title: 'Dart',
  description: '',
  subscribers: 50000,
);

class _SearchRepo extends RedditRepository {
  _SearchRepo()
    : super(RedditClient(SecureStore(), AuthRepository(SecureStore())));
  final queries = <String>[];
  final requests = <Completer<List<Subreddit>>>[];
  int postQueries = 0;
  @override
  Future<List<Subreddit>> searchSubreddits(String query) {
    queries.add(query);
    final request = Completer<List<Subreddit>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<Listing<Post>> searchPosts(
    String query, {
    String? subreddit,
    String? after,
    String sort = 'relevance',
    String time = 'all',
  }) async {
    postQueries++;
    return const Listing<Post>(items: []);
  }

  @override
  Future<List<RedditUser>> searchUsers(String query) async => [];
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _SearchRepo repo, {
  bool restricted = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            SearchScreen(initialSubreddit: restricted ? 'Flutter' : null),
      ),
      GoRoute(
        path: '/r/:name',
        builder: (_, state) =>
            Scaffold(body: Text('Community: ${state.pathParameters['name']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        redditRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(null),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(SearchScreen)));
}

void main() {
  testWidgets('typing debounces community lookup without full search', (
    tester,
  ) async {
    final repo = _SearchRepo();
    await _mount(tester, repo);
    await tester.enterText(find.byType(TextField), 'f');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField), 'r/Flutter');
    await tester.pump(const Duration(milliseconds: 249));
    expect(repo.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repo.queries, ['flutter']);
    expect(repo.postQueries, 0);
    repo.requests.single.complete([_flutter]);
    await tester.pump();
    expect(find.widgetWithText(ListTile, 'r/Flutter'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.tap(find.widgetWithText(ListTile, 'r/Flutter'));
    await tester.pumpAndSettle();
    expect(find.text('Community: Flutter'), findsOneWidget);
  });

  testWidgets('old autocomplete responses never replace the latest query', (
    tester,
  ) async {
    final repo = _SearchRepo();
    await _mount(tester, repo);
    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(TextField), 'dart');
    await tester.pump(const Duration(milliseconds: 250));
    repo.requests[1].complete([_dart]);
    await tester.pump();
    repo.requests[0].complete([_flutter]);
    await tester.pump();
    expect(find.text('r/dartlang'), findsOneWidget);
    expect(find.text('r/Flutter'), findsNothing);
  });

  testWidgets(
    'clearing cancels pending debounce and ignores in-flight results',
    (tester) async {
      final repo = _SearchRepo();
      await _mount(tester, repo);
      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byTooltip('Clear search'));
      repo.requests.single.complete([_flutter]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('r/Flutter'), findsNothing);
      await tester.enterText(find.byType(TextField), 'dart');
      await tester.pump();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.queries, ['flutter']);
    },
  );

  testWidgets(
    'submitted search dismisses autocomplete and preserves recent query',
    (tester) async {
      final repo = _SearchRepo();
      await _mount(tester, repo);
      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(repo.postQueries, 1);
      expect(repo.queries, ['flutter']);
      repo.requests.single.complete([]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('community-suggestions')), findsNothing);
      expect(find.text('No posts found'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'recent_searches',
        ),
        ['flutter'],
      );
    },
  );

  testWidgets('account change clears outstanding suggestions', (tester) async {
    final repo = _SearchRepo();
    final container = await _mount(tester, repo);
    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump(const Duration(milliseconds: 250));
    container.read(authSessionEpochProvider.notifier).state++;
    await tester.pump();
    repo.requests.single.complete([_flutter]);
    await tester.pump();
    expect(find.text('r/Flutter'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('scoped subreddit search does not fetch community suggestions', (
    tester,
  ) async {
    final repo = _SearchRepo();
    await _mount(tester, repo, restricted: true);
    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.queries, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.postQueries, 1);
  });

  testWidgets('failed suggestions offer retry and fit enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = _SearchRepo();
    await _mount(tester, repo);
    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump(const Duration(milliseconds: 250));
    repo.requests.single.completeError(Exception('offline'));
    await tester.pump();
    await tester.tap(find.text('Could not load communities'));
    await tester.pump(const Duration(milliseconds: 250));
    repo.requests.last.complete([_flutter]);
    await tester.pump();
    expect(find.widgetWithText(ListTile, 'r/Flutter'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  });
}
