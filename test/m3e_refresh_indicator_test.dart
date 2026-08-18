import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/widgets/m3e_refresh_indicator.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('scalloped spinner renders at the requested size', (tester) async {
    await tester.pumpWidget(
      _harness(
        const M3EScallopedSpinner(
          progress: 0.6,
          size: 56,
        ),
      ),
    );

    expect(tester.getSize(find.byType(M3EScallopedSpinner)), const Size(56, 56));
    expect(
      find.descendant(
        of: find.byType(M3EScallopedSpinner),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Refreshing'), findsOneWidget);
  });

  testWidgets('refresh wrapper shows the indicator until refresh completes',
      (tester) async {
    final refresh = Completer<void>();
    final key = GlobalKey<M3ERefreshIndicatorState>();

    await tester.pumpWidget(
      _harness(
        M3ERefreshIndicator(
          key: key,
          onRefresh: () => refresh.future,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [SizedBox(height: 400)],
          ),
        ),
      ),
    );

    final refreshFuture = key.currentState!.show();
    await tester.pump();
    expect(find.byType(M3EScallopedSpinner), findsOneWidget);

    refresh.complete();
    await refreshFuture;
    await tester.pumpAndSettle();
    expect(find.byType(M3EScallopedSpinner), findsNothing);
  });
}
