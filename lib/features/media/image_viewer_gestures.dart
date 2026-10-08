import 'package:flutter/material.dart';

/// Observes dismissal gestures without competing with PhotoView's scale
/// recognizer. Adding a second finger cancels dismissal for the whole gesture.
class ImageViewerGestures extends StatefulWidget {
  const ImageViewerGestures({
    super.key,
    required this.child,
    required this.zoomed,
    required this.onDragChanged,
    required this.onDismiss,
  });
  final Widget child;
  final bool zoomed;
  final ValueChanged<double> onDragChanged;
  final VoidCallback onDismiss;

  @override
  State<ImageViewerGestures> createState() => _ImageViewerGesturesState();
}

class _ImageViewerGesturesState extends State<ImageViewerGestures> {
  final _pointers = <int>{};
  Offset? _start;
  Duration? _startedAt;
  double _drag = 0;
  bool _multiTouch = false;

  void _resetDrag() {
    _start = null;
    if (_drag != 0) {
      _drag = 0;
      widget.onDragChanged(0);
    }
  }

  void _down(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length == 1) {
      _multiTouch = false;
      _start = widget.zoomed ? null : event.position;
      _startedAt = event.timeStamp;
    } else {
      _multiTouch = true;
      _resetDrag();
    }
  }

  void _move(PointerMoveEvent event) {
    final start = _start;
    if (widget.zoomed ||
        _multiTouch ||
        _pointers.length != 1 ||
        start == null) {
      return;
    }
    final delta = event.position - start;
    // App gesture thresholds: keep short taps and horizontal paging untouched.
    if (delta.dy.abs() > 24 && delta.dy.abs() > delta.dx.abs() * 1.3) {
      _drag = delta.dy;
      widget.onDragChanged(_drag);
    }
  }

  void _up(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isNotEmpty) return;
    final start = _start;
    final elapsed = event.timeStamp - (_startedAt ?? event.timeStamp);
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final delta = start == null ? Offset.zero : event.position - start;
    final velocity = seconds > 0 ? delta.dy / seconds : 0;
    final dismiss =
        !widget.zoomed &&
        !_multiTouch &&
        (_drag.abs() > 130 || (_drag.abs() > 24 && velocity.abs() > 800));
    final edgeBack =
        !widget.zoomed &&
        !_multiTouch &&
        start != null &&
        start.dx < 26 &&
        delta.dx > 80 &&
        delta.dx > delta.dy.abs() * 1.3;
    _resetDrag();
    if (dismiss || edgeBack) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: (event) {
      _pointers.remove(event.pointer);
      _multiTouch = true;
      _resetDrag();
    },
    child: widget.child,
  );
}
