import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/history/history_store.dart';
import 'package:luli_for_reddit/features/home/tab_signals.dart';

import 'support/interaction_fixture.dart';

FixedScrollMetrics _metrics({double pixels = 0, Axis axis = Axis.vertical}) =>
    FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 1000,
      pixels: pixels,
      viewportDimension: 600,
      axisDirection: axis == Axis.vertical
          ? AxisDirection.down
          : AxisDirection.right,
      devicePixelRatio: 1,
    );

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = Uint8List.fromList(data!.buffer.asUint8List());
      image.dispose();
      return bytes;
    }))!;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trackHistory': true,
      'swipeActions': false,
      'autoplayMedia': false,
    });
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  testWidgets('chrome hides at the first downward gesture from offset zero', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    expect(
      scrollChromeVisible(
        UserScrollNotification(
          metrics: _metrics(),
          context: context,
          direction: ScrollDirection.reverse,
        ),
        true,
      ),
      isFalse,
    );
    expect(
      scrollChromeVisible(
        ScrollUpdateNotification(
          metrics: _metrics(pixels: 1),
          context: context,
          scrollDelta: 1,
        ),
        true,
      ),
      isFalse,
    );
    expect(
      scrollChromeVisible(
        ScrollUpdateNotification(
          metrics: _metrics(pixels: 20),
          context: context,
          scrollDelta: -1,
        ),
        false,
      ),
      isTrue,
    );
    expect(
      scrollChromeVisible(
        UserScrollNotification(
          metrics: _metrics(pixels: 20),
          context: context,
          direction: ScrollDirection.idle,
        ),
        false,
      ),
      isFalse,
    );
    expect(
      scrollChromeVisible(
        ScrollEndNotification(metrics: _metrics(), context: context),
        false,
      ),
      isTrue,
    );
  });

  testWidgets('horizontal and nested scrollers do not hide the navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    expect(
      scrollChromeVisible(
        UserScrollNotification(
          metrics: _metrics(axis: Axis.horizontal),
          context: context,
          direction: ScrollDirection.reverse,
        ),
        true,
      ),
      isTrue,
    );
    expect(
      scrollChromeVisible(
        ScrollUpdateNotification(
          metrics: _metrics(pixels: 20),
          context: context,
          scrollDelta: 10,
          depth: 1,
        ),
        true,
      ),
      isTrue,
    );
    expect(
      scrollChromeVisible(
        ScrollUpdateNotification(
          metrics: _metrics(pixels: -20),
          context: context,
          scrollDelta: -10,
        ),
        false,
      ),
      isTrue,
    );
  });

  test('read index matches history during synchronous notifications', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = interactionContainer(prefs: prefs);
    addTearDown(container.dispose);
    final changes = <bool>[];
    container.listen(historyControllerProvider, (_, entries) {
      final indexed = container
          .read(historyControllerProvider.notifier)
          .containsId('p1');
      expect(indexed, entries.any((entry) => entry.id == 'p1'));
      changes.add(indexed);
    });
    container.listen(historyContainsProvider('p1'), (_, __) {});
    final history = container.read(historyControllerProvider.notifier);
    history.markViewed(interactionPost());
    expect(container.read(historyContainsProvider('p1')), isTrue);
    history.removeViewed('p1');
    expect(container.read(historyContainsProvider('p1')), isFalse);
    history.markViewed(interactionPost());
    history.clear();
    expect(container.read(historyContainsProvider('p1')), isFalse);
    expect(changes, [true, false, true, false]);
  });

  testWidgets('unread card pixels stay unchanged on press and scroll', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final container = interactionContainer(prefs: prefs);
    addTearDown(container.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(null, amoled: true),
          home: Scaffold(
            body: ListView(
              children: [
                RepaintBoundary(
                  key: key,
                  child: PostCard(
                    post: interactionPost(),
                    frontpageStyle: true,
                  ),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final before = await _pixels(tester, key);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Flutter architecture testing')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      await _pixels(tester, key),
      before,
      reason: 'A potential scroll must not tint an unread card',
    );
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      await _pixels(tester, key),
      before,
      reason: 'Scrolling must not change unread paint',
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(historyControllerProvider), isEmpty);
    expect(find.byKey(const ValueKey('read-overlay-p1')), findsNothing);

    // Merely seen by the recommender is distinct from explicitly opened.
    container.read(interactionVaultProvider.notifier).recordDwell('p1');
    await tester.pump();
    expect(find.byKey(const ValueKey('read-overlay-p1')), findsNothing);
    expect(await _pixels(tester, key), before);
    container
        .read(historyControllerProvider.notifier)
        .markViewed(interactionPost());
    await tester.pump();
    expect(find.byKey(const ValueKey('read-overlay-p1')), findsOneWidget);
    expect(await _pixels(tester, key), isNot(before));
    container.read(historyControllerProvider.notifier).removeViewed('p1');
    await tester.pump();
    expect(find.byKey(const ValueKey('read-overlay-p1')), findsNothing);
    expect(await _pixels(tester, key), before);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 500));
  });
}
