import 'dart:developer' as developer;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Lightweight, opt-in startup instrumentation.
///
/// Enable logs with `--dart-define=LULI_STARTUP_METRICS=true`. The coordinator
/// never changes application control flow; it only records monotonic marks and
/// emits developer timeline/log events when enabled.
class StartupMetrics {
  StartupMetrics({bool? enabled})
      : _enabled = enabled ??
            const bool.fromEnvironment('LULI_STARTUP_METRICS',
                defaultValue: false),
        _clock = Stopwatch()..start();

  static final StartupMetrics instance = StartupMetrics();

  final bool _enabled;
  final Stopwatch _clock;
  final Map<String, Duration> _marks = <String, Duration>{};
  bool _frameTimingsStarted = false;

  bool get enabled => _enabled;

  /// Returns a snapshot for tests and future diagnostic surfaces.
  Map<String, Duration> get marks => Map.unmodifiable(_marks);

  void markMainEntered() => mark('main_entered');

  void markRunAppCalled() => mark('run_app_called');

  void markFirstFlutterFrame() => mark('first_flutter_frame');

  void markAuthResolved() => mark('auth_resolved');

  void markFirstFeedItemVisible() {
    if (!_enabled || _marks.containsKey('first_feed_item_visible')) return;
    mark('first_feed_item_visible');

    // This is the app-level proxy for "fully interactive home": the first
    // visible item has been laid out, then one additional frame is allowed for
    // the surrounding home UI to settle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mark('fully_interactive_home');
    });
  }

  /// Captures frame build/raster durations for the first timing batch.
  void startFrameTimings() {
    if (!_enabled || _frameTimingsStarted) return;
    _frameTimingsStarted = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  void mark(String name) {
    if (!_enabled || _marks.containsKey(name)) return;
    final elapsed = _clock.elapsed;
    _marks[name] = elapsed;
    developer.Timeline.instantSync(
      'luli.startup.$name',
      arguments: <String, dynamic>{
        'elapsed_ms': elapsed.inMicroseconds / 1000,
      },
    );
    developer.log(
      '$name=${elapsed.inMicroseconds / 1000}ms',
      name: 'luli.startup',
    );
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      developer.log(
        'frame build=${timing.buildDuration.inMicroseconds / 1000}ms '
        'raster=${timing.rasterDuration.inMicroseconds / 1000}ms',
        name: 'luli.startup.frame',
      );
    }
  }
}
