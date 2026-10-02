import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';

import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/core/theme/shape_tokens.dart';
import 'package:luli_for_reddit/core/widgets/m3e_loading_indicator.dart';
import 'package:luli_for_reddit/core/widgets/m3e_press_bounce.dart';
import 'package:luli_for_reddit/core/widgets/m3e_refresh_indicator.dart';
import 'package:luli_for_reddit/features/navigation/m3e_floating_nav_bar.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';

Widget app(Widget child, {bool light = false, bool reduced = false}) =>
    MaterialApp(
      theme: light ? AppTheme.light(null) : AppTheme.dark(null, amoled: true),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: child),
      ),
    );

Finder dock() => find
    .descendant(
      of: find.byType(M3EFloatingNavBar),
      matching: find.byType(AnimatedContainer),
    )
    .first;

void main() {
  for (final light in [false, true]) {
    testWidgets(
      'focused comment pill stays borderless in ${light ? 'light' : 'dark'} theme',
      (tester) async {
        await tester.pumpWidget(app(const CommentComposeBar(), light: light));
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'Reply text');
        await tester.pump();
        final decorator = tester.widget<InputDecorator>(
          find.byType(InputDecorator),
        );
        expect(decorator.isFocused, isTrue);
        expect(decorator.decoration.filled, isFalse);
        expect(decorator.decoration.enabledBorder, InputBorder.none);
        expect(decorator.decoration.focusedBorder, InputBorder.none);
        expect(decorator.decoration.focusedErrorBorder, InputBorder.none);
        expect(find.text('Reply text'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'actual overflow menu inherits rounded theme in ${light ? 'light' : 'dark'} mode',
      (tester) async {
        await tester.pumpWidget(
          app(
            PopupMenuButton<int>(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 1, child: Text('Refresh')),
              ],
            ),
            light: light,
          ),
        );
        await tester.tap(find.byType(PopupMenuButton<int>));
        await tester.pumpAndSettle();
        final context = tester.element(find.text('Refresh'));
        final theme = Theme.of(context);
        final material = tester.widget<Material>(
          find
              .ancestor(
                of: find.text('Refresh'),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.shape, ShapeTokens.smallShape);
        expect(material.color, theme.colorScheme.surfaceContainerHigh);
        expect(
          theme.menuTheme.style!.shape!.resolve({}),
          ShapeTokens.smallShape,
        );
        expect(
          theme.dropdownMenuTheme.menuStyle!.shape!.resolve({}),
          ShapeTokens.smallShape,
        );
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'navigation hides labels before sliding and preserves its footprint',
    (tester) async {
      Widget nav(bool visible) => app(
        Align(
          alignment: Alignment.bottomCenter,
          child: M3EFloatingNavBar(
            currentIndex: 0,
            isVisible: visible,
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(nav(true));
      final extent = tester.getSize(find.byType(M3EFloatingNavBar));
      final top = tester.getTopLeft(dock()).dy;
      await tester.pumpWidget(nav(false));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getTopLeft(dock()).dy, closeTo(top + 4, 1));
      for (final label in tester.widgetList<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      )) {
        expect(label.opacity, 0);
      }
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getTopLeft(dock()).dy, greaterThan(top + 4));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(M3EFloatingNavBar)), extent);
      expect(find.byTooltip('Home').hitTestable(), findsNothing);
      await tester.pumpWidget(nav(true));
      await tester.pump(const Duration(milliseconds: 160));
      for (final label in tester.widgetList<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      )) {
        expect(label.opacity, 0);
      }
      await tester.pumpAndSettle();
      expect(find.byTooltip('Home').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(dock()).dy, top);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'navigation reverses safely during rapid scroll direction changes',
    (tester) async {
      Widget nav(bool visible) => app(
        M3EFloatingNavBar(currentIndex: 1, isVisible: visible, onTap: (_) {}),
      );
      await tester.pumpWidget(nav(true));
      for (final visible in [false, true, false, true]) {
        await tester.pumpWidget(nav(visible));
        await tester.pump(const Duration(milliseconds: 90));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.byTooltip('Discover').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'reduced motion snaps navigation visibility without a pending ticker',
    (tester) async {
      Widget nav(bool visible) => app(
        M3EFloatingNavBar(currentIndex: 0, isVisible: visible, onTap: (_) {}),
        reduced: true,
      );
      await tester.pumpWidget(nav(false));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Home').hitTestable(), findsNothing);
      await tester.pumpWidget(nav(true));
      await tester.pump();
      expect(find.byTooltip('Home').hitTestable(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets(
    'navigation press feedback responds before release and spring settles',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        app(
          M3EPressBounce(
            child: SizedBox(
              width: 80,
              height: 60,
              child: InkWell(onTap: () => taps++, child: const Text('Tap')),
            ),
          ),
        ),
      );
      final transform = find.descendant(
        of: find.byType(M3EPressBounce),
        matching: find.byType(Transform),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester.widget<Transform>(transform).transform.storage[0],
        lessThan(1),
      );
      await gesture.up();
      expect(taps, 1);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Transform>(transform).transform.storage[0],
        closeTo(1, 0.001),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'morph loader scales its canvas and removes timers when inactive',
    (tester) async {
      Widget loader(bool active, bool reduced) => app(
        TickerMode(enabled: active, child: const M3ELoadingIndicator.small()),
        reduced: reduced,
      );
      await tester.pumpWidget(loader(true, false));
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byType(M3ELoadingIndicator)),
        const Size(18, 18),
      );
      final fit = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fit.fit, BoxFit.contain);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpWidget(loader(false, false));
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(loader(true, true));
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      await tester.pumpAndSettle();
      await tester.pumpWidget(loader(true, false));
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  FixedScrollMetrics metrics(double pixels) => FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: 1000,
    pixels: pixels,
    viewportDimension: 600,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );

  testWidgets(
    'refresh ignores nested and ballistic scroll; reversed pull does not refresh',
    (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(
        app(
          M3ERefreshIndicator(
            onRefresh: () async {
              refreshes++;
            },
            child: ListView(children: const [SizedBox(height: 1200)]),
          ),
        ),
      );
      final listener = tester.widget<NotificationListener<ScrollNotification>>(
        find.byWidgetPredicate(
          (w) =>
              w is NotificationListener<ScrollNotification> && w.child is Stack,
        ),
      );
      final context = tester.element(find.byType(ListView));
      void end() => listener.onNotification!(
        ScrollEndNotification(metrics: metrics(0), context: context),
      );
      listener.onNotification!(
        OverscrollNotification(
          metrics: metrics(0),
          context: context,
          overscroll: -120,
        ),
      );
      end();
      await tester.pumpAndSettle();
      expect(refreshes, 0);
      listener.onNotification!(
        ScrollUpdateNotification(
          metrics: metrics(-120),
          context: context,
          depth: 1,
          dragDetails: DragUpdateDetails(globalPosition: Offset.zero),
        ),
      );
      end();
      await tester.pumpAndSettle();
      expect(refreshes, 0);
      listener.onNotification!(
        OverscrollNotification(
          metrics: metrics(0),
          context: context,
          overscroll: -110,
          dragDetails: DragUpdateDetails(globalPosition: Offset.zero),
        ),
      );
      listener.onNotification!(
        ScrollUpdateNotification(
          metrics: metrics(10),
          context: context,
          scrollDelta: 110,
          dragDetails: DragUpdateDetails(globalPosition: Offset.zero),
        ),
      );
      end();
      await tester.pumpAndSettle();
      expect(refreshes, 0);
      expect(find.byType(M3EScallopedSpinner), findsNothing);
      listener.onNotification!(
        OverscrollNotification(
          metrics: metrics(0),
          context: context,
          overscroll: -110,
          dragDetails: DragUpdateDetails(globalPosition: Offset.zero),
        ),
      );
      end();
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    },
  );

  testWidgets('an interrupted pull reset cannot erase a new refresh', (
    tester,
  ) async {
    final done = Completer<void>();
    final key = GlobalKey<M3ERefreshIndicatorState>();
    await tester.pumpWidget(
      app(
        M3ERefreshIndicator(
          key: key,
          onRefresh: () => done.future,
          child: ListView(children: const [SizedBox(height: 1200)]),
        ),
      ),
    );
    final listener = tester.widget<NotificationListener<ScrollNotification>>(
      find.byWidgetPredicate(
        (w) =>
            w is NotificationListener<ScrollNotification> && w.child is Stack,
      ),
    );
    final context = tester.element(find.byType(ListView));
    listener.onNotification!(
      OverscrollNotification(
        metrics: metrics(0),
        context: context,
        overscroll: -50,
        dragDetails: DragUpdateDetails(globalPosition: Offset.zero),
      ),
    );
    listener.onNotification!(
      ScrollEndNotification(metrics: metrics(0), context: context),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final refresh = key.currentState!.show();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
    done.complete();
    await refresh;
    await tester.pumpAndSettle();
    expect(find.byType(M3EScallopedSpinner), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
