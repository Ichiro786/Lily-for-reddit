import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/explore/explore_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/subreddit.dart';
import 'stability_api_errors_test.dart' show TestStore, TestAuth;

class _Auth extends AuthController {
  _Auth(this.initial);
  final Future<AuthSession?> initial;
  @override
  Future<AuthSession?> build() => initial;
  Future<void> change(Future<void> ready, String? user) =>
      runSessionChange(() async {
        await ready;
        state = AsyncData(user == null ? null : AuthSession(username: user));
      });
}

class _Client extends RedditClient {
  _Client() : super(TestStore(), TestAuth(TestStore()));
  String user = 'alice';
  int subscriptions = 0, popular = 0;
  Completer<void>? pending;
  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    final name = user;
    if (path.contains('/mine/')) {
      subscriptions++;
      final wait = pending;
      pending = null;
      if (wait != null) await wait.future;
    } else {
      popular++;
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'data': {
                  'children': [
                    {
                      'data': {
                        'display_name': name,
                        'display_name_prefixed': 'r/$name',
                        'title': name,
                        'subscribers': 10,
                      },
                    },
                  ],
                },
              }
              as T,
    );
  }
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test(
    'Explore waits for initial authentication before querying communities',
    () async {
      final initial = Completer<AuthSession?>();
      final client = _Client();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(() => _Auth(initial.future)),
          redditClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      container.listen(subscribedSubredditsProvider, (_, __) {});
      container.listen(popularSubredditsProvider, (_, __) {});
      await container.pump();
      expect(client.subscriptions + client.popular, 0);
      initial.complete(const AuthSession(username: 'alice'));
      expect(
        (await container.read(subscribedSubredditsProvider.future)).single.name,
        'alice',
      );
      expect(
        (await container.read(popularSubredditsProvider.future)).single.name,
        'alice',
      );
      expect(client.subscriptions, 1);
      expect(client.popular, 1);
    },
  );

  test(
    'same-account transition resumes requests and rejects old provider results',
    () async {
      final client = _Client();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(
            () => _Auth(Future.value(const AuthSession(username: 'alice'))),
          ),
          redditClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      container.listen(subscribedSubredditsProvider, (_, __) {});
      await container.read(subscribedSubredditsProvider.future);
      final repoBefore = container.read(redditRepositoryProvider);
      final ready = Completer<void>();
      final transition =
          (container.read(authControllerProvider.notifier) as _Auth).change(
            ready.future,
            'alice',
          );
      await container.pump();
      expect(container.read(authTransitionProvider), isTrue);
      expect(client.subscriptions, 1);
      ready.complete();
      await transition;
      expect(
        (await container.read(subscribedSubredditsProvider.future)).single.name,
        'alice',
      );
      expect(container.read(redditRepositoryProvider), isNot(same(repoBefore)));
      expect(client.subscriptions, 2);
      final oldResponse = Completer<void>();
      client.pending = oldResponse;
      container.read(redditRepositoryProvider).clearSubsCache();
      container.invalidate(subscribedSubredditsProvider);
      await container.pump();
      client.user = 'bob';
      await (container.read(authControllerProvider.notifier) as _Auth).change(
        Future.value(),
        'bob',
      );
      expect(
        (await container.read(subscribedSubredditsProvider.future)).single.name,
        'bob',
      );
      oldResponse.complete();
      await container.pump();
      expect(
        container.read(subscribedSubredditsProvider).requireValue.single.name,
        'bob',
      );
    },
  );

  test(
    'guest Explore shows popular communities without fetching subscriptions',
    () async {
      final client = _Client();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(() => _Auth(Future.value(null))),
          redditClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      container.listen(subscribedSubredditsProvider, (_, __) {});
      container.listen(popularSubredditsProvider, (_, __) {});
      expect(
        await container.read(subscribedSubredditsProvider.future),
        isEmpty,
      );
      expect(
        await container.read(popularSubredditsProvider.future),
        isNotEmpty,
      );
      expect(client.subscriptions, 0);
    },
  );

  testWidgets(
    'community errors have a working retry and hide transport details',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith(
              () => _Auth(Future.value(null)),
            ),
            popularSubredditsProvider.overrideWith((ref) async => []),
            subscribedSubredditsProvider.overrideWith((ref) async {
              attempts++;
              if (attempts == 1) {
                throw DioException(
                  requestOptions: RequestOptions(path: '/private'),
                  type: DioExceptionType.cancel,
                  message: 'Account changed.',
                );
              }
              return const [
                Subreddit(
                  name: 'flutter',
                  namePrefixed: 'r/flutter',
                  title: 'Flutter',
                  description: '',
                  subscribers: 100,
                ),
              ];
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(null),
            home: const ExploreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DioException'), findsNothing);
      expect(
        find.text('Could not load communities. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('r/flutter'), findsWidgets);
    },
  );
}
