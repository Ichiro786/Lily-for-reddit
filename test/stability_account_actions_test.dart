import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/interaction_actions.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/feed/post_overrides.dart';
import 'package:luli_for_reddit/features/post/comment_overrides.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'support/interaction_fixture.dart';
import 'stability_api_errors_test.dart' show TestStore, TestAuth, jsonResponse;

class _SwitchStore extends TestStore {
  String user = 'alice';
  final started = Completer<void>();
  final activated = Completer<void>();
  @override
  Future<String?> get username async => user;
  @override
  Future<String?> get refreshToken async => 'rt';
  @override
  Future<List<String>> get accounts async => ['alice', 'bob'];
  @override
  Future<bool> activateAccount(String username) async {
    started.complete();
    await activated.future;
    user = username;
    return true;
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _DelayedToken extends TestStore {
  final started = Completer<void>();
  final answer = Completer<String>();
  @override
  Future<String?> get accessToken {
    started.complete();
    return answer.future;
  }
}

void main() {
  test(
    'B04 actual account transition resets overrides, cancels queued actions, and blocks new ones',
    () async {
      SharedPreferences.setMockInitialValues({'trackHistory': false});
      final prefs = await SharedPreferences.getInstance();
      final store = _SwitchStore();
      final repo = InteractionRepository(controlled: true);
      final container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(store),
          sharedPrefsProvider.overrideWithValue(prefs),
          redditRepositoryProvider.overrideWithValue(repo),
          interactionReporterProvider.overrideWithValue((_, __) {}),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      container
          .read(commentOverridesProvider.notifier)
          .setSaved(interactionComment(), true);
      final actions = container.read(interactionActionsProvider);
      final first = actions.votePost(interactionPost(), 1);
      final second = actions.votePost(interactionPost(), -1);
      expect(repo.votes, hasLength(1));
      final switching = container
          .read(authControllerProvider.notifier)
          .switchAccount('bob');
      await store.started.future;
      expect(container.read(authTransitionProvider), isTrue);
      expect(container.read(postOverridesProvider), isEmpty);
      expect(container.read(commentOverridesProvider), isEmpty);
      await container
          .read(interactionActionsProvider)
          .toggleSavePost(interactionPost());
      expect(repo.saves, isEmpty);
      store.activated.complete();
      await switching;
      expect(container.read(authTransitionProvider), isFalse);
      repo.votes.first.done.complete();
      await Future.wait([first, second]);
      expect(repo.votes, hasLength(1));
      expect(container.read(interactionVaultProvider).interactedPosts, isEmpty);
      final bob = container
          .read(interactionActionsProvider)
          .votePost(interactionPost(), 1);
      expect(repo.votes.last.value, 1);
      repo.votes.last.done.complete();
      await bob;
      expect(
        container.read(interactionVaultProvider).interactedPosts['p1']?.upvoted,
        isTrue,
      );
      await container.read(interactionVaultProvider.notifier).flushPersisted();
    },
  );

  test(
    'B04 stale token read cannot send a mutation with another session token',
    () async {
      final store = _DelayedToken();
      final adapter = _Adapter((_) async => jsonResponse({}, 200));
      final client = RedditClient(
        store,
        TestAuth(store),
        dio: Dio()..httpClientAdapter = adapter,
      );
      final check = expectLater(
        client.post('/api/vote'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await store.started.future;
      client.invalidateAuthConfig();
      store.answer.complete('bob-token');
      await check;
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'B04 refresh that completes after a switch cannot overwrite the new active slot',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'username': 'alice',
        'refresh_token': 'alice-rt',
        'client_id': 'client',
        'accounts_json':
            '{"alice":{"mode":"oauth","rt":"alice-rt"},"bob":{"mode":"oauth","rt":"bob-rt"}}',
      });
      final store = SecureStore();
      final started = Completer<void>();
      final response = Completer<ResponseBody>();
      final adapter = _Adapter((_) {
        started.complete();
        return response.future;
      });
      final auth = AuthRepository(
        store,
        dio: Dio()..httpClientAdapter = adapter,
      );
      final pending = auth.refresh();
      await started.future;
      expect(await store.activateAccount('bob'), isTrue);
      response.complete(
        jsonResponse({'access_token': 'alice-token', 'expires_in': 3600}, 200),
      );
      expect(await pending, isNull);
      expect(await store.username, 'bob');
      expect(await store.refreshToken, 'bob-rt');
      expect(await store.accessToken, isNull);
    },
  );

  test(
    'B04 revoked refresh epoch and background refresh never persist tokens',
    () async {
      for (final background in [false, true]) {
        FlutterSecureStorage.setMockInitialValues({
          'username': 'alice',
          'refresh_token': 'rt',
          'client_id': 'client',
        });
        final store = SecureStore();
        var current = true;
        final started = Completer<void>();
        final response = Completer<ResponseBody>();
        final auth = AuthRepository(
          store,
          dio: Dio()
            ..httpClientAdapter = _Adapter((_) {
              started.complete();
              return response.future;
            }),
          sessionCurrent: () => current,
          persistRefreshedToken: !background,
        );
        final pending = auth.refresh();
        await started.future;
        if (!background) current = false;
        response.complete(
          jsonResponse({'access_token': 'token', 'expires_in': 3600}, 200),
        );
        expect(await pending, background ? 'token' : isNull);
        expect(await store.accessToken, isNull);
      }
    },
  );
}
