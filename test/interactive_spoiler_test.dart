import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/features/post/interactive_spoiler.dart';

void main() {
  test('normalizes Reddit spoiler syntax into spoiler elements', () {
    expect(
      normalizeRedditSpoilers('before >!hidden text!< after'),
      'before <spoiler>hidden text</spoiler> after',
    );
    expect(
      normalizeRedditSpoilers('inline !secret!< text'),
      'inline <spoiler>secret</spoiler> text',
    );
  });

  testWidgets('spoiler reveals and hides in place when tapped', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InteractiveSpoiler(text: 'classified'),
        ),
      ),
    );

    expect(find.text('Spoiler (Tap to reveal)'), findsOneWidget);
    await tester.tap(find.byType(InteractiveSpoiler));
    await tester.pumpAndSettle();
    expect(find.text('classified'), findsOneWidget);

    await tester.tap(find.byType(InteractiveSpoiler));
    await tester.pumpAndSettle();
    expect(find.text('Spoiler (Tap to reveal)'), findsOneWidget);
  });
}
