import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:luli_for_reddit/features/media/image_viewer_gestures.dart';

class _Viewer extends StatefulWidget {
  const _Viewer({
    required this.controller,
    required this.dismiss,
    this.gallery = false,
  });
  final PhotoViewController controller;
  final VoidCallback dismiss;
  final bool gallery;
  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  bool zoomed = false;
  double drag = 0;
  final galleryScale = PhotoViewScaleStateController();
  @override
  void dispose() {
    galleryScale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: ImageViewerGestures(
        zoomed: zoomed,
        onDragChanged: (v) => setState(() => drag = v),
        onDismiss: widget.dismiss,
        child: widget.gallery
            ? PhotoViewGallery.builder(
                itemCount: 2,
                scaleStateChangedCallback: (s) =>
                    setState(() => zoomed = s != PhotoViewScaleState.initial),
                builder: (_, i) => PhotoViewGalleryPageOptions.customChild(
                  controller: i == 1 ? widget.controller : null,
                  scaleStateController: i == 1 ? galleryScale : null,
                  child: ColoredBox(
                    color: i == 0 ? Colors.blue : Colors.green,
                    child: Center(child: Text('Page $i')),
                  ),
                  childSize: const Size(400, 400),
                  gestureDetectorBehavior: HitTestBehavior.opaque,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                ),
              )
            : PhotoView.customChild(
                controller: widget.controller,
                childSize: const Size(400, 400),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4,
                gestureDetectorBehavior: HitTestBehavior.opaque,
                scaleStateChangedCallback: (s) =>
                    setState(() => zoomed = s != PhotoViewScaleState.initial),
                child: const ColoredBox(color: Colors.blue),
              ),
      ),
    ),
  );
}

Future<void> _pinch(WidgetTester tester, Offset center) async {
  final first = await tester.startGesture(
    center - const Offset(30, 0),
    pointer: 1,
  );
  // The first finger moves before the second is placed: vertical parent
  // recognizers previously won this gesture and prevented subsequent zoom.
  await first.moveBy(const Offset(0, 30));
  await tester.pump(const Duration(milliseconds: 30));
  final second = await tester.startGesture(
    center + const Offset(30, 30),
    pointer: 2,
  );
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await first.moveBy(const Offset(-20, 0));
    await second.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 20));
  }
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final center in [const Offset(100, 280), const Offset(300, 500)]) {
    testWidgets(
      'pinch zoom works after initial one-finger movement at $center',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = PhotoViewController();
        addTearDown(controller.dispose);
        var dismisses = 0;
        await tester.pumpWidget(
          _Viewer(controller: controller, dismiss: () => dismisses++),
        );
        await tester.pumpAndSettle();
        final initial = controller.scale!;
        await _pinch(tester, center);
        expect(controller.scale, greaterThan(initial * 1.5));
        expect(dismisses, 0);
        final position = controller.position;
        await tester.dragFrom(const Offset(200, 400), const Offset(0, 160));
        await tester.pumpAndSettle();
        expect(controller.position, isNot(position));
        expect(dismisses, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('single-finger swipe still dismisses at minimum scale', (
    tester,
  ) async {
    final controller = PhotoViewController();
    addTearDown(controller.dispose);
    var dismisses = 0;
    await tester.pumpWidget(
      _Viewer(controller: controller, dismiss: () => dismisses++),
    );
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(300, 200), const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(dismisses, 1);
  });

  testWidgets(
    'horizontal gallery paging remains available before and after pinch',
    (tester) async {
      final controller = PhotoViewController();
      addTearDown(controller.dispose);
      var dismisses = 0;
      await tester.pumpWidget(
        _Viewer(
          controller: controller,
          gallery: true,
          dismiss: () => dismisses++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(500, 300), const Offset(-650, 0));
      await tester.pumpAndSettle();
      expect(find.text('Page 1').hitTestable(), findsOneWidget);
      final initial = controller.scale!;
      await _pinch(tester, const Offset(400, 300));
      expect(controller.scale, greaterThan(initial * 1.5));
      expect(dismisses, 0);
      final photo = tester.widgetList<PhotoView>(find.byType(PhotoView)).last;
      expect(photo.scaleStateController, isNotNull);
      photo.scaleStateController!.scaleState = PhotoViewScaleState.initial;
      await tester.pumpAndSettle();
      expect(controller.scale, closeTo(initial, .01));
      await tester.dragFrom(const Offset(300, 300), const Offset(650, 0));
      await tester.pumpAndSettle();
      expect(find.text('Page 0').hitTestable(), findsOneWidget);
      expect(dismisses, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'two-finger motion never triggers dismissal even at minimum scale',
    (tester) async {
      var dismisses = 0;
      var drag = 0.0;
      await tester.pumpWidget(
        MaterialApp(
          home: ImageViewerGestures(
            zoomed: false,
            onDismiss: () => dismisses++,
            onDragChanged: (v) => drag = v,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      );
      final first = await tester.startGesture(
        const Offset(200, 100),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(300, 100),
        pointer: 2,
      );
      await first.moveBy(const Offset(0, 240));
      await second.moveBy(const Offset(0, 240));
      await first.up();
      await second.up();
      expect(dismisses, 0);
      expect(drag, 0);
    },
  );
}
