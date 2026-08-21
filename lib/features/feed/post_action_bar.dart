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
    final gaps = <Widget>[];

    void addGap() {
      if (gaps.isNotEmpty) gaps.add(const SizedBox(width: 6));
    }

    addGap();
    gaps.add(
      _VoteGroup(
        score: _formatCount(score + voteState),
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
      ),
    );
    addGap();
    gaps.add(
      _CompactAction(
        semanticsLabel: '${_formatCount(commentCount)} comments',
        onTap: () {
          HapticFeedback.selectionClick();
          onCommentTap?.call();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            const SizedBox(width: 4),
            Text(
              _formatCount(commentCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    addGap();
    gaps.add(
      _CompactAction(
        semanticsLabel: 'Share',
        circular: true,
        onTap: () {
          HapticFeedback.selectionClick();
          onShareTap?.call();
        },
        child: const Icon(Icons.shortcut_rounded, size: 19),
      ),
    );
    addGap();
    gaps.add(
      _CompactAction(
        semanticsLabel: isSaved ? 'Unsave' : 'Save',
        circular: true,
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
      ),
    );
    if (onMoreTap != null) {
      addGap();
      gaps.add(
        _CompactAction(
          semanticsLabel: 'More options',
          circular: true,
          onTap: onMoreTap!,
          child: const Icon(Icons.more_horiz_rounded, size: 19),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: gaps),
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
    final scoreColor = voteState == 1
        ? upvoteColor
        : (voteState == -1 ? downvoteColor : cs.onSurface);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: ShapeTokens.full,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VoteIcon(
            tooltip: 'Upvote',
            icon: Icons.arrow_upward_rounded,
            color: voteState == 1 ? upvoteColor : cs.onSurfaceVariant,
            onPressed: onUpvote,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 24, maxWidth: 76),
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
            color: voteState == -1 ? downvoteColor : cs.onSurfaceVariant,
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

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
    this.circular = false,
    this.foregroundColor,
  });

  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget child;
  final bool circular;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = circular
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: ShapeTokens.small);
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: cs.surfaceContainerLow.withValues(alpha: 0.72),
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
