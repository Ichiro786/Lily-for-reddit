import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/theme/motion_tokens.dart';
import '../../core/theme/shape_tokens.dart';
import '../../core/widgets/m3e_press_bounce.dart';
import 'composer_media_menu.dart';

/// Attachment options in the composer's layout, immediately above the IME.
/// Keeps the editor and selection alive; opening never creates a modal route.
class ComposerMediaTray extends StatefulWidget {
  const ComposerMediaTray({
    super.key,
    required this.open,
    required this.maxHeight,
    required this.onSelected,
    this.enabled = true,
    this.gifEnabled = true,
    this.includeNextThread = false,
  });

  final bool open, enabled, gifEnabled, includeNextThread;
  final double maxHeight;
  final ValueChanged<ComposerMediaAction> onSelected;

  @override
  State<ComposerMediaTray> createState() => _ComposerMediaTrayState();
}

class _ComposerMediaTrayState extends State<ComposerMediaTray>
    with TickerProviderStateMixin {
  // M3 Expressive default spatial and fast effects spring tokens. Flutter's
  // dampingRatio is the ratio in M3, rather than a raw damping coefficient.
  static final _spatialSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.8,
  );
  static final _effectsSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 3800,
    ratio: 1,
  );
  late final _spatial = AnimationController.unbounded(
    vsync: this,
    value: widget.open ? 1 : 0,
  );
  late final _effects = AnimationController.unbounded(
    vsync: this,
    value: widget.open ? 1 : 0,
  );

  bool? _reduced;

  void _sync() {
    final target = widget.open ? 1.0 : 0.0;
    if (MotionTokens.reduced(context)) {
      _spatial.value = target;
      _effects.value = target;
      return;
    }
    _spatial.animateWith(
      SpringSimulation(
        _spatialSpring,
        _spatial.value,
        target,
        _spatial.velocity,
      ),
    );
    _effects.animateWith(
      SpringSimulation(
        _effectsSpring,
        _effects.value,
        target,
        _effects.velocity,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MotionTokens.reduced(context);
    if (_reduced != reduced) {
      _reduced = reduced;
      _sync();
    }
  }

  @override
  void didUpdateWidget(covariant ComposerMediaTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) _sync();
  }

  @override
  void dispose() {
    _spatial.dispose();
    _effects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Tray padding, gaps, and the 72dp minimum row height are Lily design
    // decisions. The rows mirror the user's concept, with room for large text.
    final options = RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in [
                  (
                    ComposerMediaAction.photo,
                    'Photo',
                    'Choose from your gallery',
                    Icons.photo_rounded,
                    cs.primaryContainer,
                    cs.onPrimaryContainer,
                  ),
                  (
                    ComposerMediaAction.video,
                    'Video',
                    'Uploads as a public video link',
                    Icons.videocam_rounded,
                    cs.secondaryContainer,
                    cs.onSecondaryContainer,
                  ),
                  (
                    ComposerMediaAction.gif,
                    'GIF',
                    'Search GIPHY',
                    Icons.gif_box_rounded,
                    cs.tertiaryContainer,
                    cs.onTertiaryContainer,
                  ),
                  if (widget.includeNextThread)
                    (
                      ComposerMediaAction.nextThread,
                      'Next comment thread',
                      'Jump to the next conversation',
                      Icons.forum_rounded,
                      cs.surfaceContainerHighest,
                      cs.onSurface,
                    ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: M3EPressBounce(
                      child: Material(
                        color: cs.surfaceContainerLow,
                        borderRadius: ShapeTokens.large,
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          enabled:
                              widget.enabled &&
                              (item.$1 != ComposerMediaAction.gif ||
                                  widget.gifEnabled),
                          minTileHeight: 72,
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: item.$5,
                              borderRadius: ShapeTokens.medium,
                            ),
                            child: Icon(item.$4, color: item.$6),
                          ),
                          title: Text(
                            item.$2,
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Text(item.$3),
                          onTap: () => widget.onSelected(item.$1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_spatial, _effects]),
      child: options,
      builder: (context, child) {
        if (!widget.open && !_spatial.isAnimating) {
          return const SizedBox.shrink();
        }
        return ExcludeSemantics(
          excluding: !widget.open,
          child: IgnorePointer(
            ignoring: !widget.open || !widget.enabled,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _spatial.value.clamp(0.0, 1.0),
                child: Opacity(
                  opacity: _effects.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    // Small reveal offset is a Lily design decision; the
                    // spatial spring handles reversal and physical settling.
                    offset: Offset(0, (1 - _spatial.value) * 12),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
