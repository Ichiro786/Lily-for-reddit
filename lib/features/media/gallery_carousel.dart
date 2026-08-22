import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/media_aspect_ratio.dart';
import '../../core/theme/shape_tokens.dart';
import '../../core/widgets/m3e_loading_indicator.dart';
import '../../models/post.dart';
import 'media_viewers.dart';

/// An inline, swipeable gallery preview with a page counter and dot indicator.
/// Tapping any image opens the full-screen viewer at that index.
class GalleryCarousel extends StatefulWidget {
  const GalleryCarousel({
    super.key,
    required this.images,
    this.title,
    this.height,
  });

  final List<GalleryImage> images;
  final String? title;

  /// Optional explicit viewport height for a caller with a deliberate stable
  /// gallery policy. Feed and post detail callers leave this null so the
  /// viewport derives from the first image and available width.
  final double? height;

  @override
  State<GalleryCarousel> createState() => _GalleryCarouselState();
}

class _GalleryCarouselState extends State<GalleryCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final first = widget.images.first;
    final aspect = intrinsicMediaAspectRatio(
      width: first.width,
      height: first.height,
    );
    final maxHeight = mediaViewportMaxHeight(
      viewportHeight: MediaQuery.sizeOf(context).height,
      verticalPadding: MediaQuery.viewPaddingOf(context).vertical,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final naturalHeight = width / aspect;
        final displayHeight = widget.height ??
            (naturalHeight > maxHeight ? maxHeight : naturalHeight);
        final capped = widget.height == null && naturalHeight > maxHeight;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = (width * dpr).round().clamp(1, 1080).toInt();
        final cacheHeight =
            (displayHeight * dpr).round().clamp(1, 1080).toInt();

        final stack = Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => openGalleryViewer(
                  context,
                  widget.images,
                  title: widget.title,
                  initialIndex: i,
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.images[i].url,
                  memCacheWidth: cacheWidth,
                  memCacheHeight: cacheHeight,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: M3ELoadingIndicator.medium(),
                  ),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.scrim.withValues(alpha: 0.54),
                  borderRadius: ShapeTokens.extraSmall,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.collections_rounded,
                      size: 14,
                      color: colorScheme.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_index + 1}/${widget.images.length}',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.images.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                  ],
                ),
              ),
            if (capped)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.scrim.withValues(alpha: 0.54),
                    borderRadius: ShapeTokens.extraSmall,
                  ),
                  child: Text(
                    'View full',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );

        final viewport = widget.height == null && !capped
            ? AspectRatio(aspectRatio: aspect, child: stack)
            : SizedBox(width: double.infinity, height: displayHeight, child: stack);
        return ClipRRect(
          borderRadius: ShapeTokens.large,
          child: viewport,
        );
      },
    );
  }
}
