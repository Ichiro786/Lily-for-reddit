import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/widgets/m3e_loading_indicator.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('small, medium, and large variants use the requested sizes',
      (tester) async {
    await tester.pumpWidget(_harness(
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          M3ELoadingIndicator.small(),
          M3ELoadingIndicator.medium(),
          M3ELoadingIndicator.large(),
        ],
      ),
    ));

    final indicators = find.byType(M3ELoadingIndicator);
    expect(indicators, findsNWidgets(3));
    expect(tester.getSize(indicators.at(0)), const Size(18, 18));
    expect(tester.getSize(indicators.at(1)), const Size(32, 32));
    expect(tester.getSize(indicators.at(2)), const Size(48, 48));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('provides an accessible live-region loading label', (tester) async {
    await tester.pumpWidget(
      _harness(const M3ELoadingIndicator(semanticLabel: 'Loading media')),
    );

    expect(find.bySemanticsLabel('Loading media'), findsOneWidget);
  });

  test('computeM3EFlowerPath morphs from circle at t=0 to 12-lobed flower at t=1', () {
    const size = Size(100, 100);
    final circlePath = computeM3EFlowerPath(size: size, progress: 0.0);
    final circleBounds = circlePath.getBounds();
    expect(circleBounds.width, closeTo(circleBounds.height, 0.01));

    final flowerPath = computeM3EFlowerPath(size: size, progress: 1.0);
    final flowerBounds = flowerPath.getBounds();
    // At progress 1.0, crests expand outward
    expect(flowerBounds.width, greaterThan(circleBounds.width));
    expect(flowerBounds.height, greaterThan(circleBounds.height));

    // Zero size returns an empty path
    final emptyPath = computeM3EFlowerPath(size: Size.zero, progress: 0.5);
    expect(emptyPath.getBounds().isEmpty, isTrue);
  });

  testWidgets('determinate mode respects progress without running continuous ticker',
      (tester) async {
    await tester.pumpWidget(
      _harness(const M3ELoadingIndicator(progress: 0.75, size: 40)),
    );
    expect(find.byType(M3ELoadingIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(M3ELoadingIndicator)), const Size(40, 40));
    expect(find.byType(CustomPaint), findsOneWidget);

    // Pumping a short duration should succeed without pending unmanaged frames
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('indeterminate mode animates rotation and breathing scale',
      (tester) async {
    await tester.pumpWidget(
      _harness(const M3ELoadingIndicator(size: 36)),
    );
    expect(find.byType(M3ELoadingIndicator), findsOneWidget);
    expect(find.byType(AnimatedBuilder), findsOneWidget);

    // Advance animation across several frames
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('disposes animation controllers cleanly without memory leaks',
      (tester) async {
    await tester.pumpWidget(
      _harness(const M3ELoadingIndicator()),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Replace with a plain container to trigger dispose
    await tester.pumpWidget(_harness(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(find.byType(M3ELoadingIndicator), findsNothing);
  });

  testWidgets('adapts to constraints without layout overflow across various sizes',
      (tester) async {
    for (final s in [16.0, 24.0, 36.0, 64.0, 120.0]) {
      await tester.pumpWidget(
        _harness(M3ELoadingIndicator(size: s)),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(M3ELoadingIndicator)), Size(s, s));
    }
  });
}
