import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] holding everything sensitive:
/// the user's Reddit API credentials (entered at login) and OAuth tokens.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;
  static Future<void> _sessionWrites = Future.value();

  Future<T> sessionTransaction<T>(Future<T> Function() task) {
    final result = _sessionWrites.then((_) => task());
    _sessionWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<bool> saveTokensForSession({
    required String? username,
    required String expectedRefreshToken,
    required String accessToken,
    required DateTime expiry,
    required bool Function() current,
  }) => sessionTransaction(() async {
    if (!current() ||
        await this.username != username ||
        await refreshToken != expectedRefreshToken ||
        await authMode != 'oauth') {
      return false;
    }
    if (!current()) return false;
    await saveTokens(accessToken: accessToken, expiry: expiry);
    return true;
  });

  // Keys
  static const _kClientId = 'client_id';
  static const _kClientSecret = 'client_secret';
  static const _kRedirectUri = 'redirect_uri';
  static const _kGiphyKey = 'giphy_api_key';
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kTokenExpiry = 'token_expiry'; // millis since epoch
  static const _kUsername = 'username';
  // Auth mode + website-session credentials (the no-API-key fallback).
  static const _kAuthMode = 'auth_mode'; // 'oauth' (default) | 'web'
  static const _kWebCookie = 'web_cookie';
  static const _kWebModhash = 'web_modhash';

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> _write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);

  // --- API credentials ---
  Future<String?> get clientId => read(_kClientId);
  Future<String?> get clientSecret => read(_kClientSecret);
  Future<String?> get redirectUri => read(_kRedirectUri);
  Future<String?> get giphyKey => read(_kGiphyKey);

  Future<void> saveCredentials({
    required String clientId,
    required String redirectUri,
    String? clientSecret,
    String? giphyKey,
  }) async {
    await _write(_kClientId, clientId);
    await _write(_kClientSecret, clientSecret);
    await _write(_kRedirectUri, redirectUri);
    await _write(
      _kGiphyKey,
      (giphyKey != null && giphyKey.isEmpty) ? null : giphyKey,
    );
  }

  // --- Tokens ---
  Future<String?> get accessToken => read(_kAccessToken);
  Future<String?> get refreshToken => read(_kRefreshToken);
  Future<String?> get username => read(_kUsername);

  Future<DateTime?> get tokenExpiry async {
    final raw = await read(_kTokenExpiry);
    if (raw == null) return null;
    final millis = int.tryParse(raw);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    required DateTime expiry,
  }) async {
    await _write(_kAccessToken, accessToken);
    if (refreshToken != null) await _write(_kRefreshToken, refreshToken);
    await _write(_kTokenExpiry, expiry.millisecondsSinceEpoch.toString());
  }

  Future<void> saveUsername(String? username) => _write(_kUsername, username);

  // --- Auth mode + website session (no-API-key fallback) ---
  /// 'oauth' (default) or 'web'.
  Future<String> get authMode async => (await read(_kAuthMode)) ?? 'oauth';
  Future<String?> get webCookie => read(_kWebCookie);
  Future<String?> get webModhash => read(_kWebModhash);

  Future<void> saveWebSession({
    required String username,
    required String cookie,
    String? modhash,
  }) => sessionTransaction(() async {
    await _write(_kAuthMode, 'web');
    await _write(_kWebCookie, cookie);
    await _write(_kWebModhash, modhash);
    await _write(_kUsername, username);
    // Clear any OAuth token in the active slot.
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kTokenExpiry);
  });

  // --- Multi-account ---
  // We persist {username: <account JSON>} where each value is either an OAuth
  // account {"mode":"oauth","rt":...} or a website-session account
  // {"mode":"web","cookie":...,"modhash":...}. Legacy plain-string values are
  // treated as an OAuth refresh token. The "active slot" keys above mirror
  // whichever account is current.
  static const _kAccounts = 'accounts_json';

  Future<Map<String, Map<String, dynamic>>> _accountsMap() async {
    final raw = await read(_kAccounts);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map;
      return m.map(
        (k, v) => MapEntry(
          k.toString(),
          v is Map
              ? v.cast<String, dynamic>()
              : {'mode': 'oauth', 'rt': v.toString()}, // legacy migration
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAccounts(Map<String, Map<String, dynamic>> m) =>
      _write(_kAccounts, jsonEncode(m));

  Future<List<String>> get accounts async =>
      (await _accountsMap()).keys.toList();

  /// Mode ('oauth'|'web') of a stored account, or null if unknown.
  Future<String?> accountMode(String username) async =>
      (await _accountsMap())[username]?['mode'] as String?;

  Future<void> upsertAccount(String username, String refreshToken) async {
    final m = await _accountsMap();
    m[username] = {'mode': 'oauth', 'rt': refreshToken};
    await _saveAccounts(m);
  }

  Future<void> upsertWebAccount(
    String username,
    String cookie,
    String? modhash,
  ) async {
    final m = await _accountsMap();
    m[username] = {'mode': 'web', 'cookie': cookie, 'modhash': modhash};
    await _saveAccounts(m);
  }

  Future<void> removeAccountEntry(String username) async {
    final m = await _accountsMap();
    m.remove(username);
    await _saveAccounts(m);
  }

  Future<void> clearAccounts() => _storage.delete(key: _kAccounts);

  /// Loads [username]'s stored credentials into the active slot (OAuth refresh
  /// token, or website cookie+modhash). Returns false if not stored.
  Future<bool> activateAccount(String username) => sessionTransaction(() async {
    final acct = (await _accountsMap())[username];
    if (acct == null) return false;
    final mode = acct['mode'] as String? ?? 'oauth';
    await _write(_kUsername, username);
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kTokenExpiry);
    if (mode == 'web') {
      await _write(_kAuthMode, 'web');
      await _write(_kWebCookie, acct['cookie'] as String?);
      await _write(_kWebModhash, acct['modhash'] as String?);
      await _storage.delete(key: _kRefreshToken);
    } else {
      await _write(_kAuthMode, 'oauth');
      await _write(_kRefreshToken, acct['rt'] as String?);
      await _storage.delete(key: _kWebCookie);
      await _storage.delete(key: _kWebModhash);
    }
    return true;
  });

  /// Clears the active session (tokens, cookie, username, mode) but keeps API
  /// credentials so re-login is quick.
  Future<void> clearSession() => sessionTransaction(() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kTokenExpiry);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kWebCookie);
    await _storage.delete(key: _kWebModhash);
    await _storage.delete(key: _kAuthMode);
  });

  /// Full wipe — credentials and session.
  /// Returns the sensitive values needed for a portable backup. Callers should
  /// only write this data to a user-selected local/share destination.
  Future<Map<String, dynamic>> exportBackupData() async {
    return {
      'client_id': await clientId,
      'client_secret': await clientSecret,
      'redirect_uri': await redirectUri,
      'giphy_api_key': await giphyKey,
    };
  }

  /// Returns the active session and all saved account configurations.
  Future<Map<String, dynamic>> exportAuthData() async {
    return {
      'auth_mode': await authMode,
      'username': await username,
      'access_token': await accessToken,
      'refresh_token': await refreshToken,
      'token_expiry': (await tokenExpiry)?.toIso8601String(),
      'web_cookie': await webCookie,
      'web_modhash': await webModhash,
      'accounts': await _accountsMap(),
    };
  }

  Future<void> restoreBackupData(Map<String, dynamic> data) async {
    await _write(_kClientId, data['client_id'] as String?);
    await _write(_kClientSecret, data['client_secret'] as String?);
    await _write(_kRedirectUri, data['redirect_uri'] as String?);
    await _write(_kGiphyKey, data['giphy_api_key'] as String?);
  }

  Future<void> restoreAuthData(Map<String, dynamic> data) async {
    final values = validatedAuthBackup(data);
    for (final entry in values.entries) {
      await _write(entry.key, entry.value);
    }
  }

  Future<Map<String, String>> snapshot() async => Map.of(await _storage.readAll());

  Future<void> restoreSnapshot(Map<String, String> snapshot) async {
    final current = await _storage.readAll();
    for (final key in current.keys.where((key) => !snapshot.containsKey(key)).toList()) {
      await _storage.delete(key: key);
    }
    for (final entry in snapshot.entries) {
      await _write(entry.key, entry.value);
    }
  }

  static Map<String, String?> validatedAuthBackup(Map<String, dynamic> data) {
    final values = <String, String?>{};
    for (final key in [
      _kAuthMode,
      _kUsername,
      _kAccessToken,
      _kRefreshToken,
      _kWebCookie,
      _kWebModhash,
    ]) {
      final value = data[key];
      if (value != null && value is! String) {
        throw FormatException('Invalid authentication field: $key');
      }
      values[key] = value as String?;
    }
    final mode = values[_kAuthMode];
    if (mode != null && mode != 'oauth' && mode != 'web') {
      throw const FormatException('Invalid authentication mode');
    }
    final user = values[_kUsername];
    if (user != null && user.trim().isEmpty) {
      throw const FormatException('Invalid username');
    }
    if (user != null && mode == 'web' && (values[_kWebCookie]?.isEmpty ?? true)) {
      throw const FormatException('Missing website session');
    }
    if (user != null &&
        (mode == null || mode == 'oauth') &&
        (values[_kRefreshToken]?.isEmpty ?? true) &&
        (values[_kAccessToken]?.isEmpty ?? true)) {
      throw const FormatException('Missing OAuth session');
    }
    final expiry = data['token_expiry'];
    if (expiry != null &&
        (expiry is! String || DateTime.tryParse(expiry) == null)) {
      throw const FormatException('Invalid token expiry in backup');
    }
    values[_kTokenExpiry] = expiry == null
        ? null
        : DateTime.parse(expiry as String).millisecondsSinceEpoch.toString();
    final accounts = data['accounts'];
    if (accounts != null && accounts is! Map) {
      throw const FormatException('Invalid accounts section in backup');
    }
    final normalized = <String, Map<String, dynamic>>{};
    for (final entry in (accounts as Map? ?? {}).entries) {
      if (entry.key is! String ||
          (entry.key as String).trim().isEmpty ||
          entry.value is! Map) {
        throw const FormatException('Invalid account entry in backup');
      }
      final account = Map<String, dynamic>.from(entry.value as Map);
      final mode = account['mode'] ?? 'oauth';
      if (mode != 'web' && mode != 'oauth') {
        throw const FormatException('Invalid saved account mode');
      }
      final secret = mode == 'web' ? account['cookie'] : account['rt'];
      if (secret is! String || secret.isEmpty) {
        throw const FormatException('Missing saved account credentials');
      }
      if (account['modhash'] != null && account['modhash'] is! String) {
        throw const FormatException('Invalid saved account modhash');
      }
      normalized[entry.key as String] = account;
    }
    values[_kAccounts] = jsonEncode(normalized);
    return values;
  }

  Future<void> clearAll() => _storage.deleteAll();
}
