import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class M3EPostActionBar extends StatelessWidget {
  final int score;
  final int commentCount;
  final int voteState; // 1 = upvoted, -1 = downvoted, 0 = none
  final bool isSaved;
  final ValueChanged<int>? onVote;
  final VoidCallback? onCommentTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onShareTap;

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
    // Distinct dark tonal surface for action capsules.
    final pillBg = colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 1. Upvote / Score / Downvote Capsule
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                    size: 20,
                    color: voteState == 1
                        ? const Color(0xFFFF5722)
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onVote?.call(voteState == 1 ? 0 : 1);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    _formatCount(score + voteState),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: voteState == 1
                          ? const Color(0xFFFF5722)
                          : (voteState == -1
                              ? colorScheme.error
                              : colorScheme.onSurface),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_downward_rounded,
                    size: 20,
                    color: voteState == -1
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onVote?.call(voteState == -1 ? 0 : -1);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 2. Comment Count Capsule
          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onCommentTap?.call();
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 19, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      _formatCount(commentCount),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Bookmark Pill
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onSaveTap?.call();
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 44,
              width: 52,
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                size: 20,
                color: isSaved ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. Smooth Curved Share Pill
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onShareTap?.call();
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 44,
              width: 52,
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.shortcut_rounded,
                size: 22,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
