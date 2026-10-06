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
  BackupService({
    required this.preferences,
    required this.secureStore,
    this.sessionChange,
  });

  final SharedPreferences preferences;
  final SecureStore secureStore;
  final Future<BackupRestoreResult> Function(
    Future<BackupRestoreResult> Function(),
  )?
  sessionChange;
  Future<void> _restores = Future.value();

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
        if (entry.value == null || !_isJsonValue(entry.value)) {
          throw const FormatException('Invalid preference value in backup');
        }
        _validatePreference(entry.key, entry.value);
      }
      _validateAuthData(authData);

      final restore = _restores.then((_) async {
        Future<BackupRestoreResult>
        apply() => secureStore.sessionTransaction(() async {
          final oldSecure = await secureStore.snapshot();
          final oldPreferences = {
            for (final key in preferences.getKeys()) key: preferences.get(key),
          };
          try {
            await secureStore.restoreBackupData(apiKeys);
            await secureStore.restoreAuthData(authData);
            for (final entry in preferencesMap.entries) {
              await _writePreference(entry.key, entry.value);
            }
            return const BackupRestoreResult.success();
          } catch (_) {
            try {
              await secureStore.restoreSnapshot(oldSecure);
              for (final key in preferences.getKeys().difference(
                oldPreferences.keys.toSet(),
              )) {
                if (!await preferences.remove(key)) {
                  throw StateError('Preference rollback failed');
                }
              }
              for (final entry in oldPreferences.entries) {
                await _writePreference(entry.key, entry.value);
              }
              return const BackupRestoreResult.failure(
                'Restore failed. Your previous settings and credentials were restored.',
              );
            } catch (_) {
              return const BackupRestoreResult.failure(
                'Restore failed and previous values could not be fully restored. Please check your account and settings.',
              );
            }
          }
        });
        return sessionChange == null ? apply() : sessionChange!(apply);
      });
      _restores = restore.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      );
      return await restore;
    } on FormatException catch (error) {
      return BackupRestoreResult.failure(error.message);
    } on Object catch (_) {
      return const BackupRestoreResult.failure(
        'The backup could not be restored. Check that it is valid JSON.',
      );
    }
  }

  Map<String, dynamic> _mapField(Map<String, dynamic> backup, String key) {
    final value = backup[key];
    if (value is! Map) throw FormatException('Missing or invalid $key section');
    return Map<String, dynamic>.from(value);
  }

  void _validateAuthData(Map<String, dynamic> authData) {
    SecureStore.validatedAuthBackup(authData);
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
    final bool success;
    if (value is bool) {
      success = await preferences.setBool(key, value);
    } else if (value is int) {
      success = await preferences.setInt(key, value);
    } else if (value is double) {
      success = await preferences.setDouble(key, value);
    } else if (value is String) {
      success = await preferences.setString(key, value);
    } else if (value is List && value.every((item) => item is String)) {
      success = await preferences.setStringList(key, value.cast<String>());
    } else {
      throw FormatException('Unsupported preference type for $key');
    }
    if (!success) throw StateError('Preference write failed');
  }

  void _validatePreference(String key, Object? value) {
    const boolKeys = {
      'amoled',
      'useDynamicColor',
      'blurNsfw',
      'swipeActions',
      'trackHistory',
      'offlineCache',
      'checkUpdates',
      'forYouFeed',
      'autoHideReadForYou',
      'hideReadPosts',
      'resumeFeeds',
      'midResThumbnails',
      'subsCacheEnabled',
      'autoplayMedia',
      'notifyInbox',
      'navLabels',
      'has_account',
      'notif_prompted',
      'notifyInboxPrompted',
    };
    const intKeys = {
      'themeMode',
      'seedColor',
      'defaultSort',
      'postDisplay',
      'subsCacheMinutes',
    };
    final current = preferences.get(key);
    final listKey = [
      'history',
      'muted_subs',
      'visited_subreddits_v1',
      'recent_searches',
      'notif_seen_ids',
    ].any((prefix) => key == prefix || key.startsWith('${prefix}_'));
    final stringKey = [
      'interest_weights',
      'keyword_weights',
      'fy_impressions',
      'interaction_vault_interacted_posts',
      'interaction_vault_seen_posts',
      'draft_',
    ].any((prefix) => key.startsWith(prefix));
    if ((listKey && (value is! List || !value.every((v) => v is String))) ||
        (stringKey && value is! String) ||
        (key.startsWith('unreadCountCache') && value is! int)) {
      throw FormatException('Invalid stored-data preference type: $key');
    }
    final wrongCurrentType =
        current != null &&
        !((current is bool && value is bool) ||
            (current is int && value is int) ||
            (current is double && value is double) ||
            (current is String && value is String) ||
            (current is List<String> &&
                value is List &&
                value.every((v) => v is String)));
    if ((boolKeys.contains(key) && value is! bool) ||
        (intKeys.contains(key) && value is! int) ||
        (key == 'textScale' && value is! double) ||
        wrongCurrentType) {
      throw FormatException('Invalid preference type: $key');
    }
    final upper = switch (key) {
      'themeMode' => 2,
      'defaultSort' => 4,
      'postDisplay' => 2,
      _ => null,
    };
    if (upper != null && (value is! int || value < 0 || value > upper)) {
      throw FormatException('Invalid preference range: $key');
    }
    if (key == 'textScale' &&
        (value is! double || !value.isFinite || value <= 0 || value > 4)) {
      throw const FormatException('Invalid text scale');
    }
    if (key == 'subsCacheMinutes' && (value is! int || value < 0)) {
      throw const FormatException('Invalid subscription cache duration');
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
    sessionChange: (task) =>
        ref.read(authControllerProvider.notifier).runSessionChange(task),
  );
});

String backupRestoreErrorText(Object error) {
  return error is FormatException
      ? error.message
      : 'The backup could not be restored. Check that it is valid JSON.';
}
