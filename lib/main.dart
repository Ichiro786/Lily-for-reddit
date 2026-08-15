import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/deferred_startup.dart';
import 'core/startup_metrics.dart';
import 'features/settings/settings_controller.dart';

void main() async {
  final startup = StartupMetrics.instance;
  startup.markMainEntered();
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  startup.markRunAppCalled();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const LuliApp(),
    ),
  );

  // Analytics, telemetry-only secure-storage reads, WorkManager, and optional
  // polling registration do not affect the initial UI or auth decision. Start
  // them after the first frame; each service handles its own failure.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(startDeferredStartupServices(prefs));
  });
}
