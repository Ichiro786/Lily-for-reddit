import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/secure_store.dart';
import '../auth/auth_controller.dart';
import 'settings_controller.dart';

const _backupSchemaVersion = 1;

class BackupRestoreResult {
  const BackupRestoreResult._({required this.success, required this.message});

  const BackupRestoreResult.success()
      : this._(
          success: true,
          message: 'Settings and API keys restored successfully',
        );

  const BackupRestoreResult.failure(String message)
      : this._(success: false, message: message);

  final bool success;
  final String message;
}

class BackupExport {
  const BackupExport({required this.filename, required this.json});

  final String filename;
  final String json;
}

class BackupService {
  BackupService({required this.preferences, required this.secureStore});

  final SharedPreferences preferences;
  final SecureStore secureStore;

  Future<BackupExport> exportBackup() async {
    final backup = await _buildBackup();
    await Share.share(backup.json, subject: backup.filename);
    return backup;
  }

  Future<BackupExport> createBackup() async => _buildBackup();

  Future<BackupExport> _buildBackup() async {
    final now = DateTime.now().toUtc();
    final preferencesMap = <String, dynamic>{};
    for (final key in preferences.getKeys()) {
      final value = preferences.get(key);
      if (_isJsonValue(value)) preferencesMap[key] = value;
    }

    final payload = <String, dynamic>{
      'schema_version': _backupSchemaVersion,
      'timestamp': now.toIso8601String(),
      'api_keys': await secureStore.exportBackupData(),
      'preferences': preferencesMap,
      'auth_data': await secureStore.exportAuthData(),
    };
    final filename =
        'lily_backup_${now.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14)}.json';
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    return BackupExport(filename: filename, json: json);
  }

  Future<BackupRestoreResult> importBackup(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) {
        throw const FormatException('Backup must contain a JSON object');
      }
      final backup = Map<String, dynamic>.from(decoded);
      if (backup['schema_version'] != _backupSchemaVersion) {
        throw const FormatException('Unsupported backup schema version');
      }

      final apiKeys = _mapField(backup, 'api_keys');
      final preferencesMap = _mapField(backup, 'preferences');
      final authData = _mapField(backup, 'auth_data');
      for (final entry in apiKeys.entries) {
        if (entry.value != null && entry.value is! String) {
          throw const FormatException('Invalid API credential in backup');
        }
      }
      for (final entry in preferencesMap.entries) {
        if (!_isJsonValue(entry.value)) {
          throw const FormatException('Invalid preference value in backup');
        }
      }
      _validateAuthData(authData);

      await secureStore.restoreBackupData(apiKeys);
      await secureStore.restoreAuthData(authData);
      for (final entry in preferencesMap.entries) {
        await _writePreference(entry.key, entry.value);
      }
      return const BackupRestoreResult.success();
    } on FormatException catch (error) {
      return BackupRestoreResult.failure(error.message);
    } on Object catch (_) {
      return const BackupRestoreResult.failure(
          'The backup could not be restored. Check that it is valid JSON.');
    }
  }

  Map<String, dynamic> _mapField(Map<String, dynamic> backup, String key) {
    final value = backup[key];
    if (value is! Map) throw FormatException('Missing or invalid $key section');
    return Map<String, dynamic>.from(value);
  }

  void _validateAuthData(Map<String, dynamic> authData) {
    for (final key in [
      'auth_mode',
      'username',
      'access_token',
      'refresh_token',
      'token_expiry',
      'web_cookie',
      'web_modhash',
    ]) {
      final value = authData[key];
      if (value != null && value is! String) {
        throw FormatException('Invalid authentication field: $key');
      }
    }
    final accounts = authData['accounts'];
    if (accounts != null && accounts is! Map) {
      throw const FormatException('Invalid accounts section in backup');
    }
  }

  Future<void> _writePreference(String key, Object? value) async {
    if (value is bool) {
      await preferences.setBool(key, value);
    } else if (value is int) {
      await preferences.setInt(key, value);
    } else if (value is double) {
      await preferences.setDouble(key, value);
    } else if (value is String) {
      await preferences.setString(key, value);
    } else if (value is List && value.every((item) => item is String)) {
      await preferences.setStringList(key, value.cast<String>());
    } else {
      throw FormatException('Unsupported preference type for $key');
    }
  }

  bool _isJsonValue(Object? value) {
    return value == null ||
        value is bool ||
        value is num ||
        value is String ||
        (value is List && value.every((item) => item is String));
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    preferences: ref.read(sharedPrefsProvider),
    secureStore: ref.read(secureStoreProvider),
  );
});

String backupRestoreErrorText(Object error) {
  return error is FormatException
      ? error.message
      : 'The backup could not be restored. Check that it is valid JSON.';
}
