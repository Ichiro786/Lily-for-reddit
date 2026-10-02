import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/features/navigation/m3e_floating_nav_bar.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

Finder _dock() => find
    .descendant(
      of: find.byType(M3EFloatingNavBar),
      matching: find.byType(AnimatedContainer),
    )
    .first;

void main() {
  testWidgets(
    'Discover single taps stay immediate and spaced taps do not search',
    (tester) async {
      final selections = <int>[];
      var searches = 0;
      await tester.pumpWidget(
        _harness(
          M3EFloatingNavBar(
            currentIndex: 0,
            onTap: selections.add,
            onSearch: () => searches++,
          ),
        ),
      );
      await tester.tap(find.text('Discover'));
      expect(selections, [1]);
      expect(searches, 0);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Discover'));
      expect(selections, [1, 1]);
      expect(searches, 0);
      await tester.tap(find.text('Home'));
      await tester.tap(find.text('Discover'));
      expect(searches, 0);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'Discover search is available by long press when labels are hidden',
    (tester) async {
      var searches = 0;
      await tester.pumpWidget(
        _harness(
          M3EFloatingNavBar(
            currentIndex: 1,
            isMinimized: true,
            onTap: (_) {},
            onSearch: () => searches++,
          ),
        ),
      );
      await tester.longPress(find.byTooltip('Discover · double-tap to search'));
      expect(searches, 1);
    },
  );

  testWidgets('labels fade immediately and finish hiding within 120ms', (
    tester,
  ) async {
    Widget nav(bool minimized) => _harness(
      M3EFloatingNavBar(currentIndex: 0, isMinimized: minimized, onTap: (_) {}),
    );
    await tester.pumpWidget(nav(false));
    await tester.pumpWidget(nav(true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final fades = tester.widgetList<FadeTransition>(
      find.descendant(
        of: find.byType(M3EFloatingNavBar),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fades, hasLength(4));
    for (final fade in fades) {
      expect(fade.opacity.value, lessThan(1));
      expect(fade.opacity.value, greaterThan(0));
    }
    await tester.pump(const Duration(milliseconds: 80));
    for (final fade in fades) {
      expect(fade.opacity.value, 0);
    }
    expect(tester.getSize(_dock()).height, 60);
    expect(find.byTooltip('Inbox').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion hides labels without an animation delay', (
    tester,
  ) async {
    Widget nav(bool minimized) => _harness(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: M3EFloatingNavBar(
          currentIndex: 0,
          isMinimized: minimized,
          onTap: (_) {},
        ),
      ),
    );
    await tester.pumpWidget(nav(false));
    await tester.pumpWidget(nav(true));
    await tester.pump();
    expect(tester.getSize(_dock()).height, 60);
    for (final fade in tester.widgetList<FadeTransition>(
      find.descendant(
        of: find.byType(M3EFloatingNavBar),
        matching: find.byType(FadeTransition),
      ),
    )) {
      expect(fade.opacity.value, 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'navigation keeps touch targets and unread semantics when minimized',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          M3EFloatingNavBar(
            currentIndex: 0,
            isMinimized: true,
            unreadCount: 7,
            onTap: (_) {},
          ),
        ),
      );
      expect(
        tester.getSize(find.byTooltip('Home')).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.bySemanticsLabel('Inbox, 7 unread'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('destination taps report the selected tab', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          currentIndex: 0,
          onTap: (index) => selected = index,
        ),
      ),
    );

    await tester.tap(find.text('Discover'));
    expect(selected, 1);
    await tester.tap(find.text('Inbox'));
    expect(selected, 2);
  });

  testWidgets('dock uses 64dp expanded and accessible 60dp minimized heights', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          currentIndex: 0,
          onTap: (_) {},
        ),
      ),
    );
    expect(tester.getSize(_dock()).height, 64);

    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          currentIndex: 0,
          isMinimized: true,
          onTap: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(_dock()).height, 60);
  });

  testWidgets('Inbox badge dot is visible when unread count is nonzero',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          currentIndex: 0,
          unreadCount: 7,
          onTap: (_) {},
        ),
      ),
    );

    expect(find.text('7'), findsNothing);
    expect(find.byType(Positioned), findsWidgets);
  });

  testWidgets(
      'minimizing and expanding dock causes no layout overflows across all animation frames',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          currentIndex: 0,
          isMinimized: false,
          onTap: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // Transition to minimized
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          currentIndex: 0,
          isMinimized: true,
          onTap: (_) {},
        ),
      ),
    );

    for (final ms in [0, 40, 80, 120, 160, 220]) {
      await tester.pump(Duration(milliseconds: ms == 0 ? 0 : 40));
      expect(tester.takeException(), isNull,
          reason: 'Overflow occurred while minimizing at ${ms}ms');
    }

    // Transition back to expanded
    await tester.pumpWidget(
      _harness(
        M3EFloatingNavBar(
          currentIndex: 0,
          isMinimized: false,
          onTap: (_) {},
        ),
      ),
    );

    for (final ms in [0, 40, 80, 120, 160, 220]) {
      await tester.pump(Duration(milliseconds: ms == 0 ? 0 : 40));
      expect(tester.takeException(), isNull,
          reason: 'Overflow occurred while expanding at ${ms}ms');
    }
  });
}
