import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../features/notifications/inbox_poller.dart';
import 'analytics.dart';
import 'storage/secure_store.dart';

/// Starts optional services after the first Flutter frame.
///
/// Each service is isolated so an analytics, secure-storage, or WorkManager
/// failure cannot prevent the main UI from staying available.
Future<void> startDeferredStartupServices(SharedPreferences prefs) async {
  await Future.wait<void>([
    _startAnalytics().catchError(
      (Object error, StackTrace stack) => _logFailure('analytics', error, stack),
    ),
    _startInboxPolling(prefs).catchError(
      (Object error, StackTrace stack) =>
          _logFailure('workmanager', error, stack),
    ),
  ]);
}

Future<void> _startAnalytics() async {
  await Analytics.init();

  // This login-method lookup is telemetry-only. Auth/session resolution remains
  // owned by AuthController and is not moved or duplicated here.
  final store = SecureStore();
  final username = await store.username;
  final loginMethod = (username == null || username.isEmpty)
      ? 'logged_out'
      : (await store.authMode) == 'web'
          ? 'website'
          : 'api';
  Analytics.track('app_started', {'login_method': loginMethod});
}

Future<void> _startInboxPolling(SharedPreferences prefs) async {
  await Workmanager().initialize(inboxCallbackDispatcher);
  if (prefs.getBool(kNotifyInboxPref) ?? false) {
    await registerInboxPolling();
  }
}

void _logFailure(String service, Object error, StackTrace stack) {
  developer.log(
    'Deferred $service startup failed; continuing without it.',
    name: 'luli.startup.deferred',
    error: error,
    stackTrace: stack,
  );
}
