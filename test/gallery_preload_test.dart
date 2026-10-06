import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/features/media/gallery_preload.dart';

class TestImage extends ImageProvider<TestImage> {
  TestImage(this.id, this.image, {this.controlled = false});
  final int id;
  final ui.Image image;
  final bool controlled;
  final ready = Completer<ImageInfo>();
  late ImageStreamCompleter stream;
  int loads = 0;
  @override
  Future<TestImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(TestImage key, ImageDecoderCallback decode) {
    loads++;
    final result = controlled && !ready.isCompleted
        ? ready.future
        : Future.value(ImageInfo(image: image.clone()));
    return stream = OneFrameImageStreamCompleter(result);
  }

  void complete() => ready.complete(ImageInfo(image: image.clone()));
}

void main() {
  for (final mode in ['normal', 'rapid', 'pressure']) {
    testWidgets(
      'gallery decode window, request deduplication and release: $mode',
      (tester) async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = (await tester.runAsync(() => picture.toImage(8, 8)))!;
        picture.dispose();
        final providers = List.generate(
          12,
          (i) => TestImage(i, image, controlled: i == 0),
        );
        Widget app(int index) => MaterialApp(
          home: GalleryPreload(
            providers: providers,
            index: index,
            child: const SizedBox(),
          ),
        );
        await tester.pumpWidget(app(0));
        await tester.pump();
        expect(providers[0].loads, 1);
        expect(providers.skip(1).every((p) => p.loads == 0), true);
        if (mode == 'rapid') {
          await tester.pumpWidget(app(4));
          await tester.pump();
          providers[0].complete();
          await tester.pump();
          expect(
            providers[1].loads,
            0,
          ); // An obsolete decode cannot launch a window.
          expect(providers[3].loads, 1);
          expect(providers[5].loads, 1);
          expect(providers[2].loads, 0);
          expect(providers[6].loads, 0);
        } else {
          providers[0].complete();
          await tester.pump();
          await tester.pump();
          expect(providers[1].loads, 1);
          expect(providers[2].loads, 0);
          await tester.pumpWidget(app(1));
          await tester.pump();
          await tester.pump();
          expect(providers[0].loads, 1);
          expect(providers[1].loads, 1);
          expect(providers[2].loads, 1);
          expect(providers[3].loads, 0);
          if (mode == 'pressure') {
            tester.binding.handleMemoryPressure();
            await tester.pump();
            expect(
              providers.take(3).every((p) => !p.stream.hasListeners),
              true,
            );
            await tester.pumpWidget(app(1));
            await tester.pump();
            expect(providers[3].loads, 0);
            await tester.pumpWidget(app(2));
            await tester.pump();
            await tester.pump();
            expect(providers[3].loads, 1);
          } else {
            await tester.pumpWidget(app(2));
            await tester.pump();
            await tester.pump();
            expect(providers[0].stream.hasListeners, false);
            await tester.pumpWidget(app(1));
            await tester.pump();
            await tester.pump();
            expect(
              providers[0].loads,
              1,
            ); // Reverse swipe reuses decoded cache.
          }
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(
          providers
              .where((p) => p.loads > 0)
              .every((p) => !p.stream.hasListeners),
          true,
        );
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        image.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
