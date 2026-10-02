import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion_tokens.dart';
import '../../core/theme/shape_tokens.dart';
import '../../core/widgets/m3e_press_bounce.dart';

enum ComposerMediaAction { photo, video, gif, paste, nextThread }

/// One expressive attachment affordance shared by inline and sheet composers.
/// The route owns the menu; the composer owns the selected media and work.
class ComposerMediaMenuButton extends StatefulWidget {
  const ComposerMediaMenuButton({
    super.key,
    required this.onSelected,
    this.enabled = true,
    this.includePaste = false,
    this.includeNextThread = false,
  });

  final ValueChanged<ComposerMediaAction> onSelected;
  final bool enabled, includePaste, includeNextThread;

  @override
  State<ComposerMediaMenuButton> createState() =>
      _ComposerMediaMenuButtonState();
}

class _ComposerMediaMenuButtonState extends State<ComposerMediaMenuButton> {
  bool _open = false;

  Future<void> _show() async {
    if (_open || !widget.enabled) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() => _open = true);
    final selected = await showModalBottomSheet<ComposerMediaAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      requestFocus: false,
      shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.extraLarge),
      sheetAnimationStyle: MotionTokens.reduced(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 240)),
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 12),
                  child: Text(
                    'Add to your comment',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
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
                  if (widget.includePaste)
                    (
                      ComposerMediaAction.paste,
                      'Paste image',
                      'From your clipboard',
                      Icons.content_paste_rounded,
                      cs.surfaceContainerHighest,
                      cs.onSurface,
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
                          onTap: () => Navigator.pop(context, item.$1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (widget.enabled && selected != null) widget.onSelected(selected);
  }

  @override
  Widget build(BuildContext context) => M3EPressBounce(
    child: IconButton.filledTonal(
      tooltip: 'Add media',
      onPressed: widget.enabled ? _show : null,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.medium),
      ),
      icon: AnimatedRotation(
        turns: _open ? 0.125 : 0,
        duration: MotionTokens.feedback(context),
        curve: MotionTokens.emphasized,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    ),
  );
}
