import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/theme/color_schemes.dart';
import 'package:luli_for_reddit/core/theme/shape_tokens.dart';
import 'package:luli_for_reddit/features/navigation/m3e_floating_nav_bar.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: M3EColorSchemes.dark,
    ),
    home: Scaffold(body: child),
  );
}

Finder _dockBackground() {
  return find.descendant(
    of: find.byType(M3EFloatingNavBar),
    matching: find.byType(AnimatedContainer),
  ).first;
}

void main() {
  testWidgets('destination taps report the selected tab', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          selectedIndex: 0,
          onSelected: (index) => selected = index,
        ),
      ),
    );

    await tester.tap(find.text('Discover'));
    expect(selected, 1);
    await tester.tap(find.text('Inbox'));
    expect(selected, 2);
  });

  testWidgets('dock morphs from expanded 64dp to minimized 44dp',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ),
    );
    expect(tester.getSize(_dockBackground()).height, 64);

    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          selectedIndex: 0,
          minimized: true,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getSize(_dockBackground()).height, 44);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('Inbox unread badge is visible when unread count is nonzero',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          selectedIndex: 0,
          unread: 7,
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('dock resolves M3E surface, outline, and shape tokens',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ),
    );

    final animated = tester.widget<AnimatedContainer>(_dockBackground());
    final decoration = animated.decoration! as BoxDecoration;
    final theme = Theme.of(tester.element(find.byType(M3EFloatingNavBar)));
    expect(decoration.color, theme.colorScheme.surfaceContainerHigh);
    expect(decoration.borderRadius, ShapeTokens.extraLarge);
    expect(decoration.border, isNotNull);
    expect(
      (decoration.border! as Border).top.color,
      theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  });
}
