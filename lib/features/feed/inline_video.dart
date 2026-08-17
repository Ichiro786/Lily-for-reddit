import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

class _InlineVideoState extends State<InlineVideo> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _muted = true;
  bool _visible = false;
  bool _initializing = false;
  int _generation = 0;

  void _onVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction > 0.6;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      unawaited(_initializeIfVisible());
      return;
    }

    final c = _c;
    if (c == null) return;
    if (!_ready) {
      // Initialization has started but the card left the viewport. Dispose the
      // controller now so a fast fling does not keep a decoder/network request
      // alive for an item the user did not actually see.
      _cancelInitialization(c);
    } else {
      c.pause();
    }
  }

  Future<void> _initializeIfVisible() async {
    if (!mounted || !_visible || _c != null || _initializing) return;
    _initializing = true;
    final generation = ++_generation;
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    c.setLooping(true);
    c.setVolume(0);

    try {
      await c.initialize();
      final active = mounted &&
          _visible &&
          generation == _generation &&
          identical(_c, c);
      if (!active) return;
      _ready = true;
      setState(() {});
      await c.play();
    } catch (_) {
      if (generation == _generation && identical(_c, c)) {
        _c = null;
        _ready = false;
        if (mounted) setState(() {});
        await c.dispose();
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
    unawaited(c.dispose());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _generation++;
    final c = _c;
    _c = null;
    if (c != null) unawaited(c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final posterWidth =
        (MediaQuery.sizeOf(context).width * dpr).round().clamp(1, 1080).toInt();
    final posterHeight =
        (widget.height * dpr).round().clamp(1, 1080).toInt();
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
                  fit: BoxFit.cover,
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
                  memCacheHeight: posterHeight,
                  fit: BoxFit.cover,
                )
              else
                const ColoredBox(color: Colors.black12),
              if (!_ready)
                const Center(
                    child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              // Mute / unmute toggle.
              if (_ready)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _muted = !_muted);
                      c?.setVolume(_muted ? 0 : 1);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
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
