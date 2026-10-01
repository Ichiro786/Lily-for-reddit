import 'dart:convert';

import 'package:dio/dio.dart';

import '../reddit_constants.dart';
import '../storage/secure_store.dart';
import '../../features/auth/auth_repository.dart';
import 'rate_limit.dart';
import 'response_cache.dart';

/// Authenticated dio client for oautreddit.com. Attaches the bearer token,
/// a compliant User-Agent and `raw_json=1`, transparently refreshes the access
/// token once on a 401, surfaces rate-limit headers, and (optionally) serves a
/// disk cache fallback when offline.
class RedditClient {
  RedditClient(
    this._store,

    this._auth, {
    this.onRateLimit,
    this.cacheEnabled,
    Dio? dio,
    ResponseCache? cache,
    bool Function()? sessionReady,
  }) {
    _sessionReady = sessionReady ?? (() => true);
    _cache = cache ?? ResponseCache();
    _dio = dio ?? Dio();
    _dio.options.baseUrl = RedditConstants.oauthApiBase;
    // Keep 401 available to the refresh interceptor; every final response is
    // validated below, including retries and HTTP-200 API error envelopes.
    _dio.options.validateStatus = (s) => s != null && s < 500;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final generation =
                options.extra['session_generation'] as int? ?? _generation;
            _assertSession(generation, options);
            if (_webMode) {
              // Website-session mode: act like a logged-in browser.
              options.headers['User-Agent'] = RedditConstants.webUserAgent;
              if (_webCookie != null) options.headers['cookie'] = _webCookie;
              options.queryParameters['raw_json'] = 1;
              if (options.method.toUpperCase() != 'GET' &&
                  _webModhash != null) {
                options.headers['X-Modhash'] = _webModhash;
              }
            } else {
              final token = await _validToken();
              options.headers['Authorization'] = 'bearer $token';
              options.headers['User-Agent'] = RedditConstants.userAgent(
                await _store.username,
              );
              options.queryParameters['raw_json'] = 1;
            }
            _assertSession(generation, options);
            handler.next(options);
          } on DioException catch (error) {
            handler.reject(error);
          } catch (error) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                message: 'Unable to prepare the Reddit session.',
              ),
            );
          }
        },
        onResponse: (response, handler) async {
          try {
            _assertSession(
              response.requestOptions.extra['session_generation'] as int? ??
                  _generation,
              response.requestOptions,
            );
          } on DioException catch (error) {
            return handler.reject(error);
          }
          _captureRateLimit(response.headers);
          if (!_webMode &&
              response.statusCode == 401 &&
              response.requestOptions.extra['retried'] != true) {
            final String? newToken;
            try {
              newToken = await _auth.refresh();
            } catch (error) {
              return handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  error: error,
                  message: 'Unable to refresh the Reddit session.',
                ),
              );
            }
            if (newToken != null) {
              final req = response.requestOptions;
              req.extra['retried'] = true;
              req.headers['Authorization'] = 'bearer $newToken';
              try {
                final retry = await _dio.fetch(req);
                return handler.resolve(retry);
              } on DioException catch (error) {
                return handler.reject(error);
              }
            }
          }
          handler.next(response);
        },
      ),
    );
  }

  late final Dio _dio;
  final SecureStore _store;
  final AuthRepository _auth;
  final void Function(RateLimit)? onRateLimit;
  final bool Function()? cacheEnabled;
  late final ResponseCache _cache;
  late final bool Function() _sessionReady;
  int _generation = 0;

  // Auth-mode config, lazily loaded from the store and refreshed on login/switch.
  bool _webMode = false;
  String? _webCookie;
  String? _webModhash;
  bool _configured = false;

  /// Force a re-read of the auth mode on the next request (call after login or
  /// account switch).
  void invalidateAuthConfig() {
    _generation++;
    _configured = false;
  }

  Future<void> _ensureConfig() async {
    final generation = _generation;
    _assertSession(generation, RequestOptions(path: ''));
    if (_configured) return;
    final webMode = (await _store.authMode) == 'web';
    final webCookie = webMode ? await _store.webCookie : null;
    final webModhash = webMode ? await _store.webModhash : null;
    _assertSession(generation, RequestOptions(path: ''));
    _webMode = webMode;
    _webCookie = webCookie;
    _webModhash = webModhash;
    _configured = true;
  }

  void _assertSession(int generation, RequestOptions options) {
    if (!_sessionReady() || generation != _generation) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'Account changed.',
      );
    }
  }

  /// Builds the request URL for the current mode. Web mode talks to
  /// www.reddit.com and appends `.json` to listing GETs.
  String _reqUrl(String path, {required bool isGet}) {
    if (!_webMode) return path; // relative to the oauth base URL
    final base = RedditConstants.webApiBase;
    if (isGet && !path.contains('/api/')) return '$base$path.json';
    return '$base$path';
  }

  void _captureRateLimit(Headers headers) {
    final rem = headers.value('x-ratelimit-remaining');
    final used = headers.value('x-ratelimit-used');
    final reset = headers.value('x-ratelimit-reset');
    if (rem == null || onRateLimit == null) return;
    onRateLimit!(
      RateLimit(
        remaining: double.tryParse(rem)?.round() ?? 0,
        used: double.tryParse(used ?? '0')?.round() ?? 0,
        resetSeconds: double.tryParse(reset ?? '0')?.round() ?? 0,
      ),
    );
  }

  Future<String> _validToken() async {
    final token = await _store.accessToken;
    final expiry = await _store.tokenExpiry;
    final expired = expiry == null || DateTime.now().isAfter(expiry);
    if (token == null || token.isEmpty || expired) {
      final refreshed = await _auth.refresh();
      if (refreshed != null) return refreshed;
    }
    return token ?? '';
  }

  bool get _cacheOn => cacheEnabled?.call() ?? false;
  String _cacheKey(String username, String path, Map<String, dynamic>? query) {
    final keys = (query ?? {}).keys.toList()..sort();
    return jsonEncode([
      'v2',
      _webMode ? 'web' : 'oauth',
      username.toLowerCase(),
      path,
      {for (final key in keys) key: query![key]},
    ]);
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    final generation = _generation;
    await _ensureConfig();
    final username = await _store.username;
    if (generation != _generation) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.cancel,
        message: 'Account changed.',
      );
    }
    final cacheKey = username == null || username.isEmpty
        ? null
        : _cacheKey(username, path, query);
    final url = _reqUrl(path, isGet: true);
    try {
      // Fetch as dynamic so Dio never does the failing internal `as T` cast;
      // we decode + re-type ourselves (Reddit occasionally returns a JSON body
      // with a content-type Dio doesn't auto-decode).
      final res = await _dio.get<dynamic>(
        url,
        queryParameters: query,
        options: Options(extra: {'session_generation': generation}),
      );
      if (generation != _generation) {
        throw DioException(
          requestOptions: res.requestOptions,
          type: DioExceptionType.cancel,
          message: 'Account changed.',
        );
      }
      final data = _checkedData(res);
      if (_cacheOn &&
          generation == _generation &&
          cacheKey != null &&
          res.statusCode == 200 &&
          data != null) {
        await _cache.write(cacheKey, data);
      }
      return _retype<T>(res, data);
    } on DioException catch (e) {
      _assertSession(generation, e.requestOptions);
      // Network failure → serve cached copy if we have one.
      if (_cacheOn &&
          generation == _generation &&
          cacheKey != null &&
          _isNetworkError(e)) {
        final cached = await _cache.read(cacheKey);
        if (generation != _generation) rethrow;
        if (cached != null) {
          return Response<T>(
            requestOptions: e.requestOptions,
            data: cached as T,
            statusCode: 200,
            extra: {'fromCache': true},
          );
        }
      }
      rethrow;
    }
  }

  /// Decodes a String body to JSON when needed (defensive against wrong/missing
  /// content-type headers from Reddit/CDNs).
  dynamic _coerce(dynamic data) {
    if (data is String && data.trim().isNotEmpty) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data; // genuinely not JSON (e.g. an HTML error page)
      }
    }
    return data;
  }

  dynamic _checkedData(Response response) {
    final status = response.statusCode;
    void reject(String message) => throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: message,
      error: message,
    );
    if (status == null || status < 200 || status >= 300) {
      reject('Reddit rejected the request (HTTP $status).');
    }
    final data = _coerce(response.data);
    if (data is String && data.trim().isNotEmpty) {
      reject('Unexpected response from Reddit. Please try again.');
    }
    if (data is Map) {
      final json = data['json'];
      final errors = json is Map ? json['errors'] : data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        final detail = first is List && first.length > 1
            ? first[1].toString()
            : first.toString();
        reject('Reddit rejected the request: $detail');
      }
      final error = data['error'];
      if (data['success'] == false ||
          (error != null && error != false && error != 0 && error != '')) {
        reject('Reddit rejected the request. Please try again.');
      }
    }
    return data;
  }

  Response<T> _retype<T>(Response res, dynamic data) {
    try {
      return Response<T>(
        requestOptions: res.requestOptions,
        data: data as T?,
        statusCode: res.statusCode,
        statusMessage: res.statusMessage,
        headers: res.headers,
        extra: res.extra,
        isRedirect: res.isRedirect,
      );
    } on TypeError {
      throw DioException(
        requestOptions: res.requestOptions,
        type: DioExceptionType.badResponse,
        error:
            'Unexpected response from Reddit (HTTP ${res.statusCode}). Please try again.',
      );
    }
  }

  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout;

  Future<void> clearCache() => _cache.clear();

  Future<Response<T>> post<T>(String path, {Map<String, dynamic>? data}) async {
    final generation = _generation;
    await _ensureConfig();
    _assertSession(generation, RequestOptions(path: path));
    final res = await _dio.post<dynamic>(
      _reqUrl(path, isGet: false),
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        extra: {'session_generation': generation},
      ),
    );
    _assertSession(generation, res.requestOptions);
    return _retype<T>(res, _checkedData(res));
  }

  /// POST with a JSON body (used by submit_gallery_post and multireddit APIs).
  Future<Response<T>> postJson<T>(String path, {Object? data}) async {
    final generation = _generation;
    await _ensureConfig();
    _assertSession(generation, RequestOptions(path: path));
    final res = await _dio.post<dynamic>(
      _reqUrl(path, isGet: false),
      data: data,
      options: Options(
        contentType: Headers.jsonContentType,
        extra: {'session_generation': generation},
      ),
    );
    _assertSession(generation, res.requestOptions);
    return _retype<T>(res, _checkedData(res));
  }

  Future<Response<T>> put<T>(String path, {Object? data}) async {
    final generation = _generation;
    await _ensureConfig();
    _assertSession(generation, RequestOptions(path: path));
    final res = await _dio.put<dynamic>(
      _reqUrl(path, isGet: false),
      data: data,
      options: Options(
        contentType: Headers.jsonContentType,
        extra: {'session_generation': generation},
      ),
    );
    _assertSession(generation, res.requestOptions);
    return _retype<T>(res, _checkedData(res));
  }

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final generation = _generation;
    await _ensureConfig();
    _assertSession(generation, RequestOptions(path: path));
    final res = await _dio.delete<dynamic>(
      _reqUrl(path, isGet: false),
      queryParameters: query,
      options: Options(extra: {'session_generation': generation}),
    );
    _assertSession(generation, res.requestOptions);
    return _retype<T>(res, _checkedData(res));
  }
}
