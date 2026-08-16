import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/core/root_messenger.dart';

void main() {
  testWidgets('root snackbar dismisses after its standard duration',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    showRootSnackBar(const SnackBar(content: Text('Tune saved')));
    await tester.pump();
    expect(find.text('Tune saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Tune saved'), findsNothing);
  });
}
