import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Uncropped, bounded-decode image with a retry that stays inside its frame.
class PostMediaImage extends StatefulWidget {
  const PostMediaImage({
    super.key,
    required this.url,
    required this.cacheWidth,
    this.animate = true,
  });
  final String url;
  final int cacheWidth;
  final bool animate;
  @override
  State<PostMediaImage> createState() => _PostMediaImageState();
}

class _PostMediaImageState extends State<PostMediaImage> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TickerMode(
      enabled: widget.animate,
      child: CachedNetworkImage(
        key: ValueKey('${widget.url}:$_attempt'),
        imageUrl: widget.url,
        memCacheWidth: widget.cacheWidth,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        placeholder: (_, __) => ColoredBox(color: cs.surfaceContainerLow),
        errorWidget: (_, __, ___) => ColoredBox(
          color: cs.surfaceContainerLow,
          child: Center(
            child: IconButton(
              tooltip: 'Retry image',
              icon: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
              onPressed: () => setState(() => _attempt++),
            ),
          ),
        ),
      ),
    );
  }
}
