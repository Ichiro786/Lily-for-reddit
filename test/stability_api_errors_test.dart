import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/interaction_actions.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/feed/post_overrides.dart';
import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'support/interaction_fixture.dart';

class _ApiRepository extends InteractionRepository {
  _ApiRepository(this.delegate);
  final RedditRepository delegate;
  @override
  Future<void> vote(String fullname, int dir) => delegate.vote(fullname, dir);
}

class TestStore extends SecureStore {
  String token = 'original';
  @override
  Future<String> get authMode async => 'oauth';
  @override
  Future<String?> get username async => 'alice';
  @override
  Future<String?> get accessToken async => token;
  @override
  Future<DateTime?> get tokenExpiry async =>
      DateTime.now().add(const Duration(hours: 1));
}

class TestAuth extends AuthRepository {
  TestAuth(this.store, {this.result = 'refreshed'}) : super(store);
  final TestStore store;
  final String? result;
  int refreshes = 0;
  @override
  Future<String?> refresh() async {
    refreshes++;
    if (result != null) store.token = result!;
    return result;
  }
}

class _UnreadableTokenStore extends TestStore {
  @override
  Future<DateTime?> get tokenExpiry =>
      Future.error(StateError('storage unavailable'));
}

class _FailedRefresh extends TestAuth {
  _FailedRefresh(super.store);
  @override
  Future<String?> refresh() => Future.error(StateError('storage unavailable'));
}

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? data, int status) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test(
    'B01 session preparation and refresh failures settle rather than hang',
    () async {
      for (final preparation in [true, false]) {
        final store = preparation ? _UnreadableTokenStore() : TestStore();
        final dio = Dio()
          ..httpClientAdapter = TestAdapter((_) => jsonResponse({}, 401));
        final client = RedditClient(
          store,
          preparation ? TestAuth(store) : _FailedRefresh(store),
          dio: dio,
        );
        await expectLater(
          client.post('/api/vote').timeout(const Duration(seconds: 1)),
          throwsA(isA<DioException>()),
        );
      }
    },
  );
  for (final rejection in [403, 429, 200]) {
    test(
      'B01 actual repository/action rollback on rejection $rejection',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = TestStore();
        final dio = Dio()
          ..httpClientAdapter = TestAdapter(
            (_) => jsonResponse(
              rejection == 200
                  ? {
                      'json': {
                        'errors': [
                          ['RATELIMIT', 'Wait', ''],
                        ],
                      },
                    }
                  : {},
              rejection,
            ),
          );
        final events = <String>[];
        final container = interactionContainer(
          prefs: prefs,
          repository: _ApiRepository(
            RedditRepository(RedditClient(store, TestAuth(store), dio: dio)),
          ),
          report: (_, outcome) => events.add(outcome),
        );
        addTearDown(container.dispose);
        await container
            .read(interactionActionsProvider)
            .votePost(interactionPost(), 1);
        expect(
          container
              .read(postOverridesProvider.notifier)
              .effective(interactionPost())
              .voteDirection,
          0,
        );
        expect(
          container.read(interactionVaultProvider).interactedPosts,
          isEmpty,
        );
        expect(events, ['failed']);
      },
    );
  }
  test(
    'B01 a failed refreshed request preserves its final HTTP status',
    () async {
      final store = TestStore();
      final adapter = TestAdapter(
        (request) =>
            jsonResponse({}, request.extra['retried'] == true ? 500 : 401),
      );
      final client = RedditClient(
        store,
        TestAuth(store),
        dio: Dio()..httpClientAdapter = adapter,
      );
      await expectLater(
        client.post('/api/vote'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            500,
          ),
        ),
      );
      expect(adapter.requests, hasLength(2));
    },
  );
  for (final status in [401, 403, 404, 429, 500]) {
    for (final verb in ['get', 'post', 'postJson', 'put', 'delete']) {
      test('B01 $verb rejects final HTTP $status', () async {
        final store = TestStore();
        final auth = TestAuth(store);
        final adapter = TestAdapter((_) => jsonResponse({}, status));
        final dio = Dio()..httpClientAdapter = adapter;
        final client = RedditClient(store, auth, dio: dio);
        final Future<Response> request = switch (verb) {
          'get' => client.get('/api/test'),
          'post' => client.post('/api/test'),
          'postJson' => client.postJson('/api/test'),
          'put' => client.put('/api/test'),
          _ => client.delete('/api/test'),
        };
        await expectLater(
          request,
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              status,
            ),
          ),
        );
        expect(adapter.requests.length, status == 401 ? 2 : 1);
        expect(auth.refreshes, status == 401 ? 1 : 0);
      });
    }
  }
  for (final body in [
    {
      'json': {
        'errors': [
          ['RATELIMIT', 'Wait before trying again', 'ratelimit'],
        ],
      },
    },
    {
      'errors': [
        ['FORBIDDEN', 'Not allowed', ''],
      ],
    },
    {'error': 403},
    {'success': false},
    '<html>login required</html>',
  ]) {
    test('B01 rejects HTTP-200 API failure $body', () async {
      final store = TestStore();
      final dio = Dio()
        ..httpClientAdapter = TestAdapter((_) => jsonResponse(body, 200));
      final client = RedditClient(store, TestAuth(store), dio: dio);
      await expectLater(client.post('/api/vote'), throwsA(isA<DioException>()));
    });
  }
  test(
    'B01 refresh success retries once with new token; empty 204 succeeds',
    () async {
      final store = TestStore();
      final adapter = TestAdapter(
        (request) =>
            jsonResponse({}, request.extra['retried'] == true ? 204 : 401),
      );
      final auth = TestAuth(store);
      final client = RedditClient(
        store,
        auth,
        dio: Dio()..httpClientAdapter = adapter,
      );
      expect((await client.post('/api/vote')).statusCode, 204);
      expect(auth.refreshes, 1);
      expect(
        adapter.requests.last.headers['Authorization'],
        'bearer refreshed',
      );
    },
  );
  test('B01 absent refresh leaves 401 rejected without retry', () async {
    final store = TestStore();
    final adapter = TestAdapter((_) => jsonResponse({}, 401));
    final client = RedditClient(
      store,
      TestAuth(store, result: null),
      dio: Dio()..httpClientAdapter = adapter,
    );
    await expectLater(client.post('/api/vote'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(1));
  });
}
