import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_store.dart';
import '../settings/settings_controller.dart' show sharedPrefsProvider;
import 'auth_repository.dart';

/// Durable account-presence marker used to distinguish a real logout from a
/// transient secure-storage read failure during startup or resume.
const kHasAccountPref = 'has_account';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(secureStoreProvider)),
);

/// All stored accounts (usernames). Refreshes when the session changes.
final accountsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.read(secureStoreProvider).accounts;
});

/// Current auth method: 'oauth' (API key) or 'web' (website session).
final authModeProvider = FutureProvider.autoDispose<String>((ref) async {
  ref.watch(authControllerProvider);
  return ref.read(secureStoreProvider).authMode;
});

/// The signed-in session. `null` means no user → show the login screen.
class AuthSession {
  const AuthSession({required this.username});
  final String username;
}

class AuthController extends AsyncNotifier<AuthSession?> {
  SecureStore get _store => ref.read(secureStoreProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Secure storage can transiently return null or throw while the platform
  /// keystore/keychain is becoming available. Keep the retry local to the
  /// critical auth read; do not retry Reddit/network work here.
  Future<String?> _readRetry(Future<String?> Function() read) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final value = await read();
        if (value != null) return value;
      } catch (_) {
        // Retry the bounded platform-storage read below.
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthSession?> build() async {
    final username = await _readRetry(() => _store.username);
    if (username == null) return null;
    final mode = await _store.authMode;
    if (mode == 'web') {
      final cookie = await _readRetry(() => _store.webCookie);
      if (cookie == null) return null;
      final accounts = await _store.accounts;
      if (!accounts.contains(username)) {
        await _store.upsertWebAccount(username, cookie, await _store.webModhash);
      }
      _setHasAccount(true);
      return AuthSession(username: username);
    }
    // OAuth (default).
    final token = await _store.accessToken;
    final refresh = await _readRetry(() => _store.refreshToken);
    if (token == null && refresh == null) return null;
    // Migrate pre-multi-account installs: ensure the current user is in the map.
    if (refresh != null) {
      final accounts = await _store.accounts;
      if (!accounts.contains(username)) {
        await _store.upsertAccount(username, refresh);
      }
    }
    _setHasAccount(true);
    return AuthSession(username: username);
  }

  void _setHasAccount(bool value) {
    ref.read(sharedPrefsProvider).setBool(kHasAccountPref, value);
  }

  /// Website-session login (no API key). [cookie] is captured by the WebView.
  Future<void> loginWithWebSession(String cookie) async {
    final r = await _repo.completeWebLogin(cookie);
    await _store.upsertWebAccount(r.username, cookie, r.modhash);
    _setHasAccount(true);
    state = AsyncData(AuthSession(username: r.username));
  }

  /// Runs the full interactive login (first account or an additional one) using
  /// the entered credentials, then records the account.
  Future<void> login({
    required String clientId,
    required String redirectUri,
    bool ephemeral = false,
  }) async {
    final username = await _repo.login(
        clientId: clientId, redirectUri: redirectUri, ephemeral: ephemeral);
    final rt = await _store.refreshToken;
    if (rt != null) await _store.upsertAccount(username, rt);
    _setHasAccount(true);
    state = AsyncData(AuthSession(username: username));
  }

  /// Adds another account, reusing the saved API credentials.
  Future<void> addAccount() async {
    final clientId = await _store.clientId;
    final redirectUri = await _store.redirectUri;
    if (clientId == null || redirectUri == null) {
      throw AuthException('No saved API credentials on this device.');
    }
    await login(
        clientId: clientId, redirectUri: redirectUri, ephemeral: true);
  }

  /// Switches the active account.
  Future<void> switchAccount(String username) async {
    if (username == state.valueOrNull?.username) return;
    final ok = await _store.activateAccount(username);
    if (!ok) return;
    state = AsyncData(AuthSession(username: username));
  }

  /// Signs out one account; switches to another if any remain.
  Future<void> removeAccount(String username) async {
    await _store.removeAccountEntry(username);
    final isCurrent = username == state.valueOrNull?.username;
    if (!isCurrent) {
      ref.invalidateSelf(); // refresh accountsProvider
      return;
    }
    final remaining = await _store.accounts;
    if (remaining.isEmpty) {
      await _store.clearSession();
      await _store.clearAccounts();
      _setHasAccount(false);
      state = const AsyncData(null);
    } else {
      await _store.activateAccount(remaining.first);
      state = AsyncData(AuthSession(username: remaining.first));
    }
  }

  /// Full sign-out of every account (used by Settings re-enter / clear-all).
  Future<void> logout() async {
    await _store.clearSession();
    await _store.clearAccounts();
    _setHasAccount(false);
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);
