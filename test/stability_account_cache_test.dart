import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/network/response_cache.dart';
import 'stability_api_errors_test.dart' show TestStore, TestAuth, jsonResponse;

class _Store extends TestStore {
  String? user = 'alice';
  String mode = 'oauth';
  @override
  Future<String?> get username async => user;
  @override
  Future<String> get authMode async => mode;
  @override
  Future<String?> get webCookie async => 'cookie';
  @override
  Future<String?> get webModhash async => 'modhash';
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory directory;
  setUp(() => directory = Directory('.tools').createTempSync('account-cache-'));
  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test(
    'B03 offline responses isolate account and auth mode, and canonicalize query order',
    () async {
      final store = _Store();
      var offline = false;
      final dio = Dio()
        ..httpClientAdapter = _Adapter((options) async {
          if (offline) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          return jsonResponse({'private': store.user}, 200);
        });
      final client = RedditClient(
        store,
        TestAuth(store),
        dio: dio,
        cache: ResponseCache(directory: directory),
        cacheEnabled: () => true,
      );
      await client.get('/message/inbox', query: {'limit': 25, 'after': 'next'});
      offline = true;
      store.user = 'bob';
      client.invalidateAuthConfig();
      await expectLater(
        client.get('/message/inbox', query: {'after': 'next', 'limit': 25}),
        throwsA(isA<DioException>()),
      );
      store.user = 'alice';
      client.invalidateAuthConfig();
      expect(
        (await client.get(
          '/message/inbox',
          query: {'after': 'next', 'limit': 25},
        )).data,
        {'private': 'alice'},
      );
      store.mode = 'web';
      client.invalidateAuthConfig();
      await expectLater(
        client.get('/message/inbox', query: {'after': 'next', 'limit': 25}),
        throwsA(isA<DioException>()),
      );
      store.user = null;
      client.invalidateAuthConfig();
      await expectLater(
        client.get('/message/inbox', query: {'after': 'next', 'limit': 25}),
        throwsA(isA<DioException>()),
      );
    },
  );

  test(
    'B03 account change rejects late results and prevents an old response cache write',
    () async {
      final store = _Store();
      final started = Completer<void>();
      final response = Completer<ResponseBody>();
      var offline = false;
      final dio = Dio()
        ..httpClientAdapter = _Adapter((options) {
          if (offline) {
            return Future.error(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          }
          started.complete();
          return response.future;
        });
      final client = RedditClient(
        store,
        TestAuth(store),
        dio: dio,
        cache: ResponseCache(directory: directory),
        cacheEnabled: () => true,
      );
      final check = expectLater(
        client.get('/message/inbox'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await started.future;
      store.user = 'bob';
      client.invalidateAuthConfig();
      response.complete(jsonResponse({'private': 'alice'}, 200));
      await check;
      store.user = 'alice';
      client.invalidateAuthConfig();
      offline = true;
      await expectLater(
        client.get('/message/inbox'),
        throwsA(isA<DioException>()),
      );
    },
  );

  test(
    'B03 expiry, clock reversal, clear and legacy payloads fail closed',
    () async {
      var now = DateTime.utc(2026, 10, 1);
      final cache = ResponseCache(directory: directory, now: () => now);
      await cache.write('inbox', {'private': 'alice'});
      expect(await cache.read('inbox'), {'private': 'alice'});
      now = now.add(const Duration(hours: 25));
      expect(await cache.read('inbox'), isNull);
      await cache.write('inbox', {'private': 'alice'});
      now = now.subtract(const Duration(minutes: 1));
      expect(await cache.read('inbox'), isNull);
      await cache.write('inbox', {'private': 'alice'});
      final file = directory.listSync().whereType<File>().single;
      await file.writeAsString('{"private":"legacy"}');
      expect(await cache.read('inbox'), isNull);
      await cache.clear();
      expect(directory.existsSync(), isFalse);
    },
  );
}
