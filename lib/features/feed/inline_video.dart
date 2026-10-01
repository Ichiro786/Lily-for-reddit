import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/widgets/m3e_loading_indicator.dart';
import '../../core/route_observer.dart';

/// A feed video that autoplays (muted, looping) while it's on screen and pauses
/// when scrolled away. Tap opens the full-screen viewer (with sound).
class InlineVideo extends StatefulWidget {
  const InlineVideo({
    super.key,
    required this.url,
    required this.height,
    required this.onTap,
    this.poster,
  });

  final String url;
  final double height;
  final VoidCallback onTap;
  final String? poster;

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _muted = true;
  bool _visible = false;
  bool _initializing = false;
  int _generation = 0;
  bool _foreground = true;
  bool _routeActive = true;
  bool _failed = false;
  bool get _canPlay => mounted && _visible && _foreground && _routeActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
      _routeActive = route.isCurrent;
    }
  }

  @override
  void didPushNext() {
    _routeActive = false;
    unawaited(_syncPlayback());
  }

  @override
  void didPopNext() {
    _routeActive = true;
    unawaited(_syncPlayback());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_syncPlayback());
  }

  @override
  void didUpdateWidget(covariant InlineVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _visible = false;
      final c = _c;
      if (c != null) _cancelInitialization(c);
      _muted = true;
      _failed = false;
    }
  }

  void _onVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction > 0.6;
    if (visible == _visible) return;
    _visible = visible;
    unawaited(_syncPlayback());
  }

  Future<void> _syncPlayback() async {
    final c = _c;
    if (!_canPlay) {
      if (c == null) return;
      if (!_ready) {
        _cancelInitialization(c);
      } else {
        try {
          await c.pause();
        } catch (_) {}
      }
    } else if (_ready && c != null) {
      try {
        await c.play();
      } catch (_) {
        if (identical(c, _c)) _cancelInitialization(c);
      }
    } else {
      await _initializeIfVisible();
    }
  }

  Future<void> _initializeIfVisible() async {
    if (!_canPlay || _c != null || _initializing) return;
    final uri = Uri.tryParse(widget.url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    _initializing = true;
    _failed = false;
    final generation = ++_generation;
    // This widget owns app/route/visibility playback. Disable the controller's
    // competing automatic resume observer, which can play an offscreen card.
    final c = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    );
    _c = c;

    try {
      await c.initialize();
      final active =
          mounted && _canPlay && generation == _generation && identical(_c, c);
      if (!active) return;
      await c.setLooping(true);
      await c.setVolume(_muted ? 0 : 1);
      if (!_canPlay || generation != _generation || !identical(_c, c)) return;
      _ready = true;
      setState(() {});
      await c.play();
    } catch (_) {
      if (generation == _generation && identical(_c, c)) {
        _c = null;
        _ready = false;
        _initializing = false;
        _failed = true;
        if (mounted) setState(() {});
        try {
          await c.dispose();
        } catch (_) {}
      }
    } finally {
      if (generation == _generation && identical(_c, c)) {
        _initializing = false;
      }
    }
  }

  void _cancelInitialization(VideoPlayerController c) {
    _generation++;
    _initializing = false;
    _c = null;
    _ready = false;
    unawaited(c.dispose().catchError((Object _) {}));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _generation++;
    final c = _c;
    _c = null;
    if (c != null) unawaited(c.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final colorScheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final posterWidth = (MediaQuery.sizeOf(context).width * dpr)
        .round()
        .clamp(1, 1080)
        .toInt();
    final poster = widget.poster;
    return VisibilityDetector(
      key: Key('inlinevid_${widget.url}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready && c != null)
                FittedBox(
                  fit: BoxFit.contain,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                )
              else if (poster != null)
                CachedNetworkImage(
                  imageUrl: poster,
                  memCacheWidth: posterWidth,
                  fit: BoxFit.contain,
                )
              else
                ColoredBox(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.12,
                  ),
                ),
              if (!_ready && !_failed)
                const Center(child: M3ELoadingIndicator.small()),
              if (_failed)
                Center(
                  child: IconButton(
                    tooltip: 'Retry video',
                    onPressed: () => unawaited(_syncPlayback()),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              // Mute / unmute toggle.
              if (_ready)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: IconButton(
                    tooltip: _muted ? 'Unmute video' : 'Mute video',
                    onPressed: () {
                      setState(() => _muted = !_muted);
                      if (c != null) {
                        unawaited(
                          c.setVolume(_muted ? 0 : 1).catchError((Object _) {}),
                        );
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.scrim.withValues(alpha: 0.5),
                      minimumSize: const Size(48, 48),
                    ),
                    icon: Icon(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
