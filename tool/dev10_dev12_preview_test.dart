import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/navigation/m3e_floating_nav_bar.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ?? '.tools/flutter';
    final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final family in ['Roboto', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final name
          in family == 'Roboto'
              ? ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']
              : ['MaterialIcons-Regular.otf']) {
        final bytes = await File('$fonts/$name').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });

  for (final light in [true, false]) {
    testWidgets('review composer and nav, light=$light', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final base = light
          ? AppTheme.light(null)
          : AppTheme.dark(null, amoled: true);
      final theme = base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      );
      final boundary = GlobalKey();
      final controller = TextEditingController(text: 'Hi');
      addTearDown(controller.dispose);
      Widget app(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RepaintBoundary(key: boundary, child: child),
          ),
        ),
      );
      Future<void> capture(String name) async {
        final rendered =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await rendered.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final dir = Directory('build/dev10-dev12-previews')
            ..createSync(recursive: true);
          File(
            '${dir.path}/$name-${light ? 'light' : 'dark'}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      await tester.pumpWidget(
        app(
          CommentComposeBar(
            controller: controller,
            onSubmit: (_) {},
            onPickGif: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture('composer-closed');
      await tester.tap(find.byTooltip('Add media'));
      if (!light) {
        await tester.pump();
        for (var frame = 0; frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 32));
          await capture('composer-motion-${frame.toString().padLeft(2, '0')}');
        }
      }
      await tester.pumpAndSettle();
      await capture('composer-open');
      if (!light) {
        await tester.tap(find.byTooltip('Close media'));
        await tester.pump();
        for (var frame = 40; frame < 64; frame++) {
          await tester.pump(const Duration(milliseconds: 32));
          await capture('composer-motion-${frame.toString().padLeft(2, '0')}');
        }
        await tester.pumpAndSettle();
      }
      for (var index = 0; index < 4; index++) {
        await tester.pumpWidget(
          app(M3EFloatingNavBar(currentIndex: index, onTap: (_) {})),
        );
        await tester.pumpAndSettle();
        await capture('nav-$index');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
