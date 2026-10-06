import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

/// Keeps only the visible image and its two neighbors live in Flutter's image
/// cache. Providers must match the renderer, including decode dimensions.
class GalleryPreload extends StatefulWidget {
  const GalleryPreload({
    super.key,
    required this.providers,
    required this.index,
    required this.child,
  });

  final List<ImageProvider> providers;
  final int index;
  final Widget child;

  @override
  State<GalleryPreload> createState() => _GalleryPreloadState();
}

class _GalleryPreloadState extends State<GalleryPreload>
    with WidgetsBindingObserver {
  final _streams = <ImageProvider, (ImageStream, ImageStreamListener)>{};
  List<ImageProvider> _window = const [];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant GalleryPreload oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (widget.providers.isEmpty) return;
    final index = widget.index.clamp(0, widget.providers.length - 1);
    final window = [
      widget.providers[index],
      if (index + 1 < widget.providers.length) widget.providers[index + 1],
      if (index > 0) widget.providers[index - 1],
    ];
    if (listEquals(_window, window)) {
      return;
    }
    _window = window;
    final generation = ++_generation;
    // Let the visible page start its own load and complete its first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      for (final provider in _streams.keys.toList()) {
        if (!window.contains(provider)) _release(provider);
      }
      final current = window.first.resolve(
        createLocalImageConfiguration(context),
      );
      var started = false;
      void neighbors() {
        if (started || !mounted || generation != _generation) return;
        started = true;
        for (final provider in window.skip(1)) {
          _retain(provider);
        }
      }

      // Wait for the current decode before starting speculative work. Resolving
      // the identical key joins an existing request rather than fetching twice.
      _release(window.first);
      final listener = ImageStreamListener((info, _) {
        info.dispose();
        neighbors();
      }, onError: (_, __) => neighbors());
      _streams[window.first] = (current, listener);
      current.addListener(listener);
    });
  }

  void _retain(ImageProvider provider) {
    if (_streams.containsKey(provider)) return;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) => info.dispose(),
      onError: (_, __) {}, // The visible image keeps its existing error UI.
    );
    _streams[provider] = (stream, listener);
    stream.addListener(listener);
  }

  void _release(ImageProvider provider) {
    final entry = _streams.remove(provider);
    if (entry != null) entry.$1.removeListener(entry.$2);
  }

  void _clear() {
    _generation++;
    for (final provider in _streams.keys.toList()) {
      _release(provider);
    }
  }

  @override
  void didHaveMemoryPressure() {
    // Suspend speculation until the page/window changes. Flutter can reclaim
    // decoded neighbors; the visible renderer owns its own listener.
    _clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
