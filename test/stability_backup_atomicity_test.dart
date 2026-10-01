import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/features/settings/backup_service.dart';

class _FailAfterAuth extends SecureStore {
  @override
  Future<void> restoreAuthData(Map<String, dynamic> data) async {
    await super.restoreAuthData(data);
    throw StateError('storage failed after writing');
  }
}

class _Preferences extends Fake implements SharedPreferences {
  final values = <String, Object>{'amoled': false, 'keep': 'original'};
  int? failAt;
  int writes = 0;
  Future<bool> _set(String key, Object value) async {
    if (++writes == failAt) return false;
    values[key] = value;
    return true;
  }

  @override
  Set<String> getKeys() => values.keys.toSet();
  @override
  Object? get(String key) => values[key];
  @override
  Future<bool> setBool(String key, bool value) => _set(key, value);
  @override
  Future<bool> setInt(String key, int value) => _set(key, value);
  @override
  Future<bool> setDouble(String key, double value) => _set(key, value);
  @override
  Future<bool> setString(String key, String value) => _set(key, value);
  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _set(key, List.of(value));
  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

Map<String, dynamic> _payload() => {
  'schema_version': 1,
  'api_keys': {'client_id': 'imported'},
  'auth_data': {
    'auth_mode': 'oauth',
    'username': 'bob',
    'refresh_token': 'bob-rt',
    'token_expiry': '2026-10-01T00:00:00Z',
    'accounts': {
      'bob': {'mode': 'oauth', 'rt': 'bob-rt'},
    },
  },
  'preferences': <String, dynamic>{
    'amoled': true,
    'new_key': 'imported',
    'keep': 'changed',
  },
};

void main() {
  const original = {
    'client_id': 'original',
    'username': 'alice',
    'refresh_token': 'alice-rt',
    'token_expiry': '123',
    'unrelated': 'preserved',
  };
  setUp(() => FlutterSecureStorage.setMockInitialValues(Map.of(original)));
  for (final invalid in [
    'expiry',
    'account',
    'mode',
    'null_pref',
    'typed_pref',
    'enum',
  ]) {
    test(
      'B05 validates $invalid before any sensitive/preference write',
      () async {
        final prefs = _Preferences();
        final payload = _payload();
        final auth = payload['auth_data'] as Map;
        final preferences = payload['preferences'] as Map;
        switch (invalid) {
          case 'expiry':
            auth['token_expiry'] = 'invalid';
          case 'account':
            auth['accounts'] = {
              'bob': {'mode': 'web', 'cookie': 1},
            };
          case 'mode':
            auth['auth_mode'] = 'unsupported';
          case 'null_pref':
            preferences['keep'] = null;
          case 'typed_pref':
            preferences['trackHistory'] = 'false';
          case 'enum':
            preferences['themeMode'] = 99;
        }
        final store = SecureStore();
        final result = await BackupService(
          preferences: prefs,
          secureStore: store,
        ).importBackup(jsonEncode(payload));
        expect(result.success, isFalse);
        expect(await store.snapshot(), original);
        expect(prefs.values, {'amoled': false, 'keep': 'original'});
        expect(prefs.writes, 0);
      },
    );
  }
  test(
    'B05 mid-storage failure restores exact original keys and values',
    () async {
      final prefs = _Preferences();
      final store = _FailAfterAuth();
      final result = await BackupService(
        preferences: prefs,
        secureStore: store,
      ).importBackup(jsonEncode(_payload()));
      expect(result.success, isFalse);
      expect(await store.snapshot(), original);
      expect(prefs.values, {'amoled': false, 'keep': 'original'});
    },
  );
  test(
    'B05 partial preference failure removes imported keys and restores both stores',
    () async {
      final prefs = _Preferences()..failAt = 3;
      final store = SecureStore();
      final result = await BackupService(
        preferences: prefs,
        secureStore: store,
      ).importBackup(jsonEncode(_payload()));
      expect(result.success, isFalse);
      expect(await store.snapshot(), original);
      expect(prefs.values, {'amoled': false, 'keep': 'original'});
    },
  );
  test(
    'B05 valid backup round-trips auth, accounts, and preferences',
    () async {
      final prefs = _Preferences();
      final store = SecureStore();
      final service = BackupService(preferences: prefs, secureStore: store);
      final result = await service.importBackup(jsonEncode(_payload()));
      expect(result.success, isTrue, reason: result.message);
      expect(await store.username, 'bob');
      expect(await store.accounts, ['bob']);
      expect(await store.clientId, 'imported');
      expect(prefs.values, {
        'amoled': true,
        'new_key': 'imported',
        'keep': 'changed',
      });
      final exported = await service.createBackup();
      expect((await service.importBackup(exported.json)).success, isTrue);
    },
  );
}
