import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/media/attachment.dart';
import 'package:luli_for_reddit/features/media/composer_media_tray.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';

Widget app(
  Widget composer, {
  bool light = false,
  bool reduced = false,
  double scale = 1,
}) => MaterialApp(
  theme: light ? AppTheme.light(null) : AppTheme.dark(null, amoled: true),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduced,
        textScaler: TextScaler.linear(scale),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              const Expanded(child: SizedBox()),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: composer,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void phone(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double keyboard = 300,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

void main() {
  for (final light in [false, true]) {
    testWidgets(
      'left plus opens above keyboard and preserves draft: light=$light',
      (tester) async {
        phone(tester);
        final controller = TextEditingController(text: 'before after');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          app(
            CommentComposeBar(
              controller: controller,
              onSubmit: (_) {},
              onPickGif: () async => null,
            ),
            light: light,
          ),
        );
        await tester.tap(find.byType(TextField));
        controller.selection = const TextSelection.collapsed(offset: 7);
        final selection = controller.selection;
        final send = tester.getRect(find.byTooltip('Send comment'));
        final editor = tester.getRect(find.byType(TextField));
        expect(
          tester.getRect(find.byTooltip('Add media')).right,
          lessThanOrEqualTo(editor.left),
        );
        expect(send.left, greaterThan(editor.right));
        final hides = tester.testTextInput.log
            .where((call) => call.method == 'TextInput.hide')
            .length;
        await tester.tap(find.byTooltip('Add media'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final initialHeight = tester
            .getSize(find.byType(ComposerMediaTray))
            .height;
        expect(initialHeight, greaterThan(0));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(ComposerMediaTray)).height,
          greaterThan(initialHeight),
        );
        expect(find.byType(BottomSheet), findsNothing);
        expect(controller.text, 'before after');
        expect(controller.selection, selection);
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue,
        );
        expect(
          tester.testTextInput.log
              .where((call) => call.method == 'TextInput.hide')
              .length,
          hides,
        );
        expect(
          tester.getRect(find.byType(ComposerMediaTray)).bottom,
          lessThanOrEqualTo(544),
        );
        expect(tester.getRect(find.byTooltip('Send comment')).size, send.size);
        for (final label in ['Photo', 'Video', 'GIF']) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(find.byTooltip('Close media'));
        await tester.pumpAndSettle();
        expect(find.text('Photo'), findsNothing);
        expect(controller.selection, selection);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('send stays in place when draft content changes', (tester) async {
    phone(tester);
    var sends = 0;
    await tester.pumpWidget(app(CommentComposeBar(onSubmit: (_) => sends++)));
    final before = tester.getRect(find.byTooltip('Send comment'));
    await tester.tap(find.byTooltip('Send comment'));
    expect(sends, 0);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(tester.getRect(find.byTooltip('Send comment')), before);
    await tester.tap(find.byTooltip('Send comment'));
    expect(sends, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('tray reverses during rapid taps and back closes it', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(const CommentComposeBar()));
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.text('Photo'), findsNothing);
    await tester.tap(find.byTooltip('Add media'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CommentComposeBar), findsOneWidget);
    expect(find.text('Photo'), findsNothing);
  });

  testWidgets('reduced motion snaps the tray and disabling closes it', (
    tester,
  ) async {
    phone(tester);
    Widget composer(bool enabled) =>
        app(CommentComposeBar(enabled: enabled), reduced: true);
    await tester.pumpWidget(composer(true));
    await tester.tap(find.byTooltip('Add media'));
    await tester.pump();
    expect(find.text('Photo').hitTestable(), findsOneWidget);
    await tester.pumpWidget(composer(false));
    await tester.pump();
    expect(find.text('Photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(740, 420)]) {
    testWidgets('long draft and tray fit a small window: $size', (
      tester,
    ) async {
      phone(tester, size: size, keyboard: size.height > 500 ? 260 : 160);
      await tester.pumpWidget(
        app(
          CommentComposeBar(onPickGif: () async => null, onSubmit: (_) {}),
          scale: 2,
        ),
      );
      await tester.enterText(find.byType(TextField), 'A long comment\n' * 12);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add media'));
      await tester.pumpAndSettle();
      final gif = find.text('GIF');
      await tester.ensureVisible(gif);
      await tester.pumpAndSettle();
      expect(gif.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('picker completion after removing composer is harmless', (
    tester,
  ) async {
    phone(tester);
    final pending = Completer<MediaAttachment?>();
    var changed = false;
    await tester.pumpWidget(
      app(
        CommentComposeBar(
          videoPicker: () => pending.future,
          onMediaSelected: (_) => changed = true,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(null);
    await tester.pump();
    expect(changed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
