import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme/shape_tokens.dart';

/// Expressive, horizontally scrollable action bar used by feed post cards.
///
/// The widget is deliberately callback-driven so Riverpod state can remain
/// localized in [PostCard] and only the action bar rebuilds when an override
/// changes.
class M3EPostActionBar extends StatelessWidget {
  const M3EPostActionBar({
    super.key,
    required this.score,
    required this.likes,
    required this.commentCount,
    required this.saved,
    required this.onUpvote,
    required this.onDownvote,
    required this.onComment,
    required this.onSave,
    required this.onShare,
  });

  final int score;
  final bool? likes;
  final int commentCount;
  final bool saved;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  void _tap(VoidCallback callback) {
    HapticFeedback.selectionClick();
    callback();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VoteSegment(
            score: score,
            likes: likes,
            onUpvote: () => _tap(onUpvote),
            onDownvote: () => _tap(onDownvote),
          ),
          const SizedBox(width: 8),
          _ActionPill(
            icon: Icons.mode_comment_outlined,
            label: compactNumber(commentCount),
            onTap: () => _tap(onComment),
          ),
          const SizedBox(width: 8),
          _ActionPill(
            icon: saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            selected: saved,
            onTap: () => _tap(onSave),
          ),
          const SizedBox(width: 8),
          _ActionPill(
            icon: Icons.share_outlined,
            tooltip: 'Share',
            onTap: () => _tap(onShare),
          ),
        ],
      ),
    );
  }
}

class _VoteSegment extends StatelessWidget {
  const _VoteSegment({
    required this.score,
    required this.likes,
    required this.onUpvote,
    required this.onDownvote,
  });

  final int score;
  final bool? likes;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final upvoted = likes == true;
    final downvoted = likes == false;
    final scoreColor = upvoted
        ? colorScheme.primary
        : downvoted
            ? colorScheme.error
            : colorScheme.onSurfaceVariant;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      elevation: 1,
      shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.full),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VoteButton(
            icon: Icons.arrow_upward_rounded,
            color: upvoted ? colorScheme.primary : colorScheme.onSurfaceVariant,
            tooltip: 'Upvote',
            onTap: onUpvote,
          ),
          Container(
            width: 1,
            height: 20,
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              compactNumber(score),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scoreColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          _VoteButton(
            icon: Icons.arrow_downward_rounded,
            color: downvoted ? colorScheme.error : colorScheme.onSurfaceVariant,
            tooltip: 'Downvote',
            onTap: onDownvote,
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(icon, color: color),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.onTap,
    this.label,
    this.selected = false,
    this.tooltip,
  });

  final IconData icon;
  final String? label;
  final bool selected;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip ?? label ?? '',
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.full),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(
            borderRadius: ShapeTokens.full,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? 12 : 11,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                if (label != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    label!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
