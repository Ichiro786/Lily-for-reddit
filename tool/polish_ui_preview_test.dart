import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/media/giphy_picker.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';

class _Store extends SecureStore {
  @override
  Future<String?> get giphyKey async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts =
        '${Platform.environment['FLUTTER_ROOT'] ?? '.tools/flutter'}/bin/cache/artifacts/material_fonts';
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
    for (final gif in [true, false]) {
      testWidgets('render polish, light=$light gif=$gif', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        final base = light
            ? AppTheme.light(null)
            : AppTheme.dark(null, amoled: true);
        final theme = base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
          primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
          appBarTheme: base.appBarTheme.copyWith(
            titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
              fontFamily: 'Roboto',
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: base.filledButtonTheme.style?.copyWith(
              textStyle: WidgetStatePropertyAll(
                (base.filledButtonTheme.style?.textStyle?.resolve({}) ??
                        const TextStyle())
                    .copyWith(fontFamily: 'Roboto'),
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [secureStoreProvider.overrideWithValue(_Store())],
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: Scaffold(
                  appBar: AppBar(title: const Text('Comments')),
                  body: Consumer(
                    builder: (context, ref, _) => Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('A conversation in r/flutter'),
                        ),
                        TextButton(
                          onPressed: () => showGiphyPicker(context, ref),
                          child: const Text('Open GIF'),
                        ),
                        const Spacer(),
                        CommentComposeBar(
                          onSubmit: (_) {},
                          onPickGif: () => showGiphyPicker(context, ref),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(
          gif ? find.text('Open GIF') : find.byTooltip('Add media'),
        );
        await tester.pumpAndSettle();
        final rendered =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await rendered.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final dir = Directory('build/polish_previews')
            ..createSync(recursive: true);
          File(
            '${dir.path}/${gif ? 'giphy' : 'media-menu'}-${light ? 'light' : 'dark'}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
