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
    expect(find.byType(CircularProgressIndicator), findsNWidgets(3));
  });

  testWidgets('provides an accessible live-region loading label', (tester) async {
    await tester.pumpWidget(
      _harness(const M3ELoadingIndicator(semanticLabel: 'Loading media')),
    );

    expect(find.bySemanticsLabel('Loading media'), findsOneWidget);
  });
}
