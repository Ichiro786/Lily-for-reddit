import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/shape_tokens.dart';

class M3EPostActionBar extends StatelessWidget {
  final int score;
  final int commentCount;
  final int voteState; // 1 = upvoted, -1 = downvoted, 0 = none
  final bool isSaved;
  final ValueChanged<int>? onVote;
  final VoidCallback? onCommentTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onMoreTap;

  const M3EPostActionBar({
    super.key,
    required this.score,
    required this.commentCount,
    this.voteState = 0,
    this.isSaved = false,
    this.onVote,
    this.onCommentTap,
    this.onSaveTap,
    this.onShareTap,
    this.onMoreTap,
  });

  String _formatCount(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}k';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final voteColors = theme.extension<VoteColors>();
    final upvoteColor = voteColors?.up ?? colorScheme.primary;
    final downvoteColor = voteColors?.down ?? colorScheme.error;
    final voteGroup = _VoteGroup(
      score: _formatCount(score),
      voteState: voteState,
      upvoteColor: upvoteColor,
      downvoteColor: downvoteColor,
      onUpvote: () {
        HapticFeedback.selectionClick();
        onVote?.call(voteState == 1 ? 0 : 1);
      },
      onDownvote: () {
        HapticFeedback.selectionClick();
        onVote?.call(voteState == -1 ? 0 : -1);
      },
    );

    final commentButton = _CommentAction(
      commentCount: _formatCount(commentCount),
      onTap: () {
        HapticFeedback.selectionClick();
        onCommentTap?.call();
      },
    );

    final shareButton = _CompactAction(
      semanticsLabel: 'Share',
      circular: true,
      onTap: () {
        HapticFeedback.selectionClick();
        onShareTap?.call();
      },
      child: const Icon(Icons.shortcut_rounded, size: 19),
    );

    final saveButton = _CompactAction(
      semanticsLabel: isSaved ? 'Unsave' : 'Save',
      circular: true,
      isHighlighted: isSaved,
      foregroundColor:
          isSaved ? colorScheme.primary : colorScheme.onSurfaceVariant,
      onTap: () {
        HapticFeedback.selectionClick();
        onSaveTap?.call();
      },
      child: Icon(
        isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
        size: 19,
      ),
    );

    final moreButton = onMoreTap != null
        ? _CompactAction(
            semanticsLabel: 'More options',
            circular: true,
            onTap: () {
              HapticFeedback.selectionClick();
              onMoreTap!();
            },
            child: const Icon(Icons.more_horiz_rounded, size: 19),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 280;
          if (isNarrow) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  voteGroup,
                  const SizedBox(width: 6),
                  commentButton,
                  const SizedBox(width: 6),
                  shareButton,
                  const SizedBox(width: 6),
                  saveButton,
                  if (moreButton != null) ...[
                    const SizedBox(width: 6),
                    moreButton,
                  ],
                ],
              ),
            );
          }
          return Row(
            children: [
              voteGroup,
              const SizedBox(width: 8),
              commentButton,
              const Spacer(),
              shareButton,
              const SizedBox(width: 6),
              saveButton,
              if (moreButton != null) ...[
                const SizedBox(width: 6),
                moreButton,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _VoteGroup extends StatelessWidget {
  const _VoteGroup({
    required this.score,
    required this.voteState,
    required this.upvoteColor,
    required this.downvoteColor,
    required this.onUpvote,
    required this.onDownvote,
  });

  final String score;
  final int voteState;
  final Color upvoteColor;
  final Color downvoteColor;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUpvoted = voteState == 1;
    final isDownvoted = voteState == -1;

    final bgColor = isUpvoted
        ? upvoteColor.withValues(alpha: 0.16)
        : (isDownvoted
            ? downvoteColor.withValues(alpha: 0.16)
            : cs.surfaceContainerHigh.withValues(alpha: 0.70));

    final borderColor = isUpvoted
        ? upvoteColor.withValues(alpha: 0.40)
        : (isDownvoted
            ? downvoteColor.withValues(alpha: 0.40)
            : cs.outlineVariant.withValues(alpha: 0.20));

    final scoreColor = isUpvoted
        ? upvoteColor
        : (isDownvoted ? downvoteColor : cs.onSurface);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: ShapeTokens.full,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VoteIcon(
            tooltip: 'Upvote',
            icon: Icons.arrow_upward_rounded,
            color: isUpvoted ? upvoteColor : cs.onSurfaceVariant,
            onPressed: onUpvote,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 20, maxWidth: 76),
            child: Text(
              score,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                  ),
            ),
          ),
          _VoteIcon(
            tooltip: 'Downvote',
            icon: Icons.arrow_downward_rounded,
            color: isDownvoted ? downvoteColor : cs.onSurfaceVariant,
            onPressed: onDownvote,
          ),
        ],
      ),
    );
  }
}

class _VoteIcon extends StatelessWidget {
  const _VoteIcon({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _CommentAction extends StatelessWidget {
  const _CommentAction({
    required this.commentCount,
    required this.onTap,
  });

  final String commentCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      label: '$commentCount comments',
      child: Material(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.70),
        shape: ShapeTokens.fullShape,
        child: InkWell(
          onTap: onTap,
          customBorder: ShapeTokens.fullShape,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: ShapeTokens.full,
                side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  commentCount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
    this.circular = false,
    this.isHighlighted = false,
    this.foregroundColor,
  });

  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget child;
  final bool circular;
  final bool isHighlighted;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = circular ? const CircleBorder() : ShapeTokens.fullShape;

    final bgColor = isHighlighted
        ? cs.primaryContainer.withValues(alpha: 0.60)
        : cs.surfaceContainerHigh.withValues(alpha: 0.70);

    final borderColor = isHighlighted
        ? cs.primary.withValues(alpha: 0.35)
        : cs.outlineVariant.withValues(alpha: 0.20);

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: bgColor,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            decoration: ShapeDecoration(
              shape: shape is CircleBorder
                  ? CircleBorder(side: BorderSide(color: borderColor, width: 1))
                  : RoundedRectangleBorder(
                      borderRadius: ShapeTokens.full,
                      side: BorderSide(color: borderColor, width: 1),
                    ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: foregroundColor ?? cs.onSurfaceVariant,
                    size: 19,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
