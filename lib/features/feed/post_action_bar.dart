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
  final bool frontpageStyle;

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
    this.frontpageStyle = false,
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
      roomy: frontpageStyle,
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
      roomy: frontpageStyle,
      commentCount: _formatCount(commentCount),
      onTap: () {
        HapticFeedback.selectionClick();
        onCommentTap?.call();
      },
    );

    final shareButton = _CompactAction(
      roomy: frontpageStyle,
      semanticsLabel: 'Share',
      circular: true,
      onTap: () {
        HapticFeedback.selectionClick();
        onShareTap?.call();
      },
      child: Icon(Icons.shortcut_rounded, size: frontpageStyle ? 22 : 17),
    );

    final saveButton = _CompactAction(
      roomy: frontpageStyle,
      semanticsLabel: isSaved ? 'Unsave' : 'Save',
      circular: true,
      isHighlighted: isSaved,
      foregroundColor: isSaved
          ? colorScheme.primary
          : colorScheme.onSurfaceVariant,
      onTap: () {
        HapticFeedback.selectionClick();
        onSaveTap?.call();
      },
      child: Icon(
        isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
        size: frontpageStyle ? 22 : 17,
      ),
    );

    final moreButton = onMoreTap != null
        ? _CompactAction(
            roomy: frontpageStyle,
            semanticsLabel: 'More options',
            circular: true,
            onTap: () {
              HapticFeedback.selectionClick();
              onMoreTap!();
            },
            child: Icon(
              frontpageStyle
                  ? Icons.more_vert_rounded
                  : Icons.more_horiz_rounded,
              size: frontpageStyle ? 22 : 17,
            ),
          )
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: frontpageStyle ? 0 : 12,
        vertical: 4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep every action visible with larger text and smaller viewports.
          // Other surfaces retain their existing compact horizontal layout.
          if (frontpageStyle) {
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                voteGroup,
                commentButton,
                shareButton,
                saveButton,
                if (moreButton != null) moreButton,
              ],
            );
          }
          final isNarrow = constraints.maxWidth < 360;
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
              if (moreButton != null) ...[const SizedBox(width: 6), moreButton],
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
    this.roomy = false,
  });

  final String score;
  final int voteState;
  final Color upvoteColor;
  final Color downvoteColor;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUpvoted = voteState == 1;
    final isDownvoted = voteState == -1;

    final bgColor = isUpvoted
        ? upvoteColor.withValues(alpha: 0.16)
        : (isDownvoted
              ? downvoteColor.withValues(alpha: 0.16)
              : (roomy
                    ? cs.surfaceContainerLowest
                    : cs.surfaceContainerHigh.withValues(alpha: 0.70)));

    final borderColor = isUpvoted
        ? upvoteColor.withValues(alpha: 0.40)
        : (isDownvoted
              ? downvoteColor.withValues(alpha: 0.40)
              : cs.outlineVariant.withValues(alpha: roomy ? 1 : 0.20));

    final scoreColor = isUpvoted
        ? upvoteColor
        : (isDownvoted ? downvoteColor : cs.onSurface);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: roomy ? 50 : 36,
      padding: EdgeInsets.symmetric(horizontal: roomy ? 0 : 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: ShapeTokens.full,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VoteIcon(
            roomy: roomy,
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
                fontSize: roomy ? 14 : 12,
                fontWeight: FontWeight.w800,
                color: scoreColor,
              ),
            ),
          ),
          _VoteIcon(
            roomy: roomy,
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
    this.roomy = false,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: roomy ? 22 : 17, color: color),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: roomy ? 48 : 32,
        minHeight: roomy ? 48 : 36,
      ),
      visualDensity: roomy ? VisualDensity.standard : VisualDensity.compact,
    );
  }
}

class _CommentAction extends StatelessWidget {
  const _CommentAction({
    required this.commentCount,
    required this.onTap,
    this.roomy = false,
  });

  final String commentCount;
  final VoidCallback onTap;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$commentCount comments',
      onTap: onTap,
      child: Material(
        color: roomy
            ? cs.surfaceContainerLowest
            : cs.surfaceContainerHigh.withValues(alpha: 0.70),
        shape: ShapeTokens.fullShape,
        child: InkWell(
          onTap: onTap,
          customBorder: ShapeTokens.fullShape,
          child: Container(
            constraints: BoxConstraints(
              minWidth: roomy ? 48 : 0,
              minHeight: roomy ? 48 : 36,
            ),
            padding: EdgeInsets.symmetric(horizontal: roomy ? 6 : 10),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: ShapeTokens.full,
                side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: roomy ? 1 : 0.20),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: roomy ? 22 : 17,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  commentCount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: roomy ? 14 : 12,
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
    this.roomy = false,
  });

  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget child;
  final bool circular;
  final bool isHighlighted;
  final Color? foregroundColor;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = circular ? const CircleBorder() : ShapeTokens.fullShape;

    final bgColor = isHighlighted
        ? cs.primaryContainer.withValues(alpha: 0.60)
        : (roomy
              ? cs.surfaceContainerLowest
              : cs.surfaceContainerHigh.withValues(alpha: 0.70));

    final borderColor = isHighlighted
        ? cs.primary.withValues(alpha: 0.35)
        : cs.outlineVariant.withValues(alpha: roomy ? 1 : 0.20);

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
            width: roomy ? 48 : null,
            constraints: BoxConstraints(
              minWidth: roomy ? 48 : 36,
              minHeight: roomy ? 48 : 36,
            ),
            decoration: ShapeDecoration(
              shape: shape is CircleBorder
                  ? CircleBorder(side: BorderSide(color: borderColor, width: 1))
                  : RoundedRectangleBorder(
                      borderRadius: ShapeTokens.full,
                      side: BorderSide(color: borderColor, width: 1),
                    ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: foregroundColor ?? cs.onSurfaceVariant,
                    size: roomy ? 22 : 17,
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
