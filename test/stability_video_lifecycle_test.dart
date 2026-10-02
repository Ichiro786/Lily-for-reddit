import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:luli_for_reddit/core/route_observer.dart';
import 'package:luli_for_reddit/features/feed/inline_video.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  final streams = <int, StreamController<VideoEvent>>{};
  final calls = <String>[];
  bool fail = false;
  bool hold = false;
  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool mix) async {}
  @override
  Future<int?> create(DataSource source) async {
    final id = streams.length;
    final stream = StreamController<VideoEvent>();
    streams[id] = stream;
    calls.add('create:$id');
    if (fail) {
      stream.addError(PlatformException(code: 'offline', message: 'Offline'));
    } else if (!hold) {
      stream.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(100, 100),
          duration: const Duration(minutes: 1),
        ),
      );
    }
    return id;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) =>
      create(options.dataSource);
  @override
  Stream<VideoEvent> videoEventsFor(int id) => streams[id]!.stream;
  @override
  Future<void> dispose(int id) async {
    calls.add('dispose:$id');
  }

  @override
  Future<void> play(int id) async {
    calls.add('play:$id');
  }

  @override
  Future<void> pause(int id) async {
    calls.add('pause:$id');
  }

  @override
  Future<void> setLooping(int id, bool looping) async {}
  @override
  Future<void> setVolume(int id, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Widget buildView(int id) => const SizedBox();
}

void main() {
  late _VideoPlatform platform;
  late VideoPlayerPlatform original;
  setUp(() {
    original = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform = _VideoPlatform();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    VideoPlayerPlatform.instance = original;
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });
  Widget app([String url = 'https://example.com/a.mp4']) => MaterialApp(
    navigatorObservers: [appRouteObserver],
    home: Scaffold(
      body: InlineVideo(url: url, height: 200, onTap: () {}),
    ),
  );
  void visible(WidgetTester tester, bool visible) {
    final d = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    d.onVisibilityChanged?.call(
      VisibilityInfo(
        key: d.key!,
        size: const Size(800, 200),
        visibleBounds: visible
            ? const Rect.fromLTWH(0, 0, 800, 200)
            : Rect.zero,
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }

  testWidgets('B10 existing controller resumes on viewport re-entry', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(platform.calls, contains('play:0'));
    visible(tester, false);
    await settle(tester);
    expect(platform.calls.last, 'pause:0');
    visible(tester, true);
    await settle(tester);
    expect(platform.calls.last, 'play:0');
    expect(platform.streams, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(platform.calls.last, 'dispose:0');
  });
  testWidgets('inactive kept-alive tab pauses native video immediately', (
    tester,
  ) async {
    Widget tab(bool active) => MaterialApp(
      navigatorObservers: [appRouteObserver],
      home: Scaffold(
        body: TickerMode(
          enabled: active,
          child: InlineVideo(
            url: 'https://example.com/a.mp4',
            height: 200,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(tab(true));
    await settle(tester);
    expect(platform.calls.last, 'play:0');
    await tester.pumpWidget(tab(false));
    await settle(tester);
    expect(platform.calls.last, 'pause:0');
    await tester.pumpWidget(tab(true));
    await settle(tester);
    expect(platform.calls.last, 'play:0');
    expect(platform.streams, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
  testWidgets('B10 failed initialization can retry without remounting', (
    tester,
  ) async {
    platform.fail = true;
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byTooltip('Retry video'), findsOneWidget);
    platform.fail = false;
    await tester.tap(find.byTooltip('Retry video'));
    await settle(tester);
    expect(platform.calls, contains('play:1'));
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
  testWidgets(
    'B10 URL replacement disposes old decoder and initializes new one',
    (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
      await tester.pumpWidget(app('https://example.com/b.mp4'));
      await settle(tester);
      expect(platform.calls, contains('dispose:0'));
      expect(platform.calls, contains('play:1'));
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );
  testWidgets(
    'B10 app and route exits pause; return resumes only visible media',
    (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      expect(platform.calls.last, 'pause:0');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(platform.calls.last, 'play:0');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.calls, contains('pause:0'));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(platform.calls.last, 'play:0');
      visible(tester, false);
      await settle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      // Only the inline widget owns lifecycle, so hidden media stays paused.
      expect(platform.calls.last, 'pause:0');
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );
}
