import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controlled presenter for a single comment.
///
/// Vote/save interaction state is owned by the parent tile and passed in via
/// [score], [voteState] and [isSaved]. The card renders those values verbatim
/// — it never applies its own arithmetic — so one user action yields exactly
/// one score delta and the visuals survive rebuilds. [onVote] receives the
/// tapped direction (1 = upvote, -1 = downvote); the parent decides the toggle.
class M3ECommentCard extends StatelessWidget {
  final String author;
  final String timeAgo;
  final String body;
  final int score;
  final int voteState; // 1 = upvoted, -1 = downvoted, 0 = none
  final bool isSaved;
  final int depth;
  final bool isOp;
  final bool isCollapsed;
  final Color? avatarColor;
  final VoidCallback? onToggleCollapse;
  final VoidCallback? onReply;
  final VoidCallback? onSave;
  final VoidCallback? onAward;
  final VoidCallback? onOverflow;
  final ValueChanged<int>? onVote;
  final int replyCount;
  final VoidCallback? onLoadMoreReplies;

  const M3ECommentCard({
    super.key,
    required this.author,
    required this.timeAgo,
    required this.body,
    this.score = 0,
    this.voteState = 0,
    this.isSaved = false,
    this.depth = 0,
    this.isOp = false,
    this.isCollapsed = false,
    this.avatarColor,
    this.onToggleCollapse,
    this.onReply,
    this.onSave,
    this.onAward,
    this.onOverflow,
    this.onVote,
    this.replyCount = 0,
    this.onLoadMoreReplies,
  });

  Color _getDepthRailColor(int depth) {
    const railColors = [
      Color(0xFFA78BFA), // Vibrant Iris Purple
      Color(0xFF38BDF8), // Sky Blue
      Color(0xFFF472B6), // Soft Rose Pink
      Color(0xFFFACC15), // Amber Gold
    ];
    return railColors[(depth - 1) % railColors.length];
  }

  Color _getAuthorAvatarColor(String name) {
    if (avatarColor != null) return avatarColor!;
    const palette = [
      Color(0xFFF97316),
      Color(0xFF06B6D4),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
      Color(0xFFEC4899),
    ];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDepth = depth > 0;

    // Distinct dark charcoal (#16161C) that cleanly contrasts against #000000 AMOLED black.
    const cardSurfaceColor = Color(0xFF16161C);

    return Padding(
      padding: EdgeInsets.only(
        left: hasDepth ? (depth * 16.0).clamp(16.0, 48.0) : 12.0,
        right: 12.0,
        top: 4.0,
        bottom: 4.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3.5dp vibrant multi-color depth rail for nested replies.
          if (hasDepth)
            Container(
              key: ValueKey<String>('comment-depth-rail-$depth'),
              width: 3.5,
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: _getDepthRailColor(depth),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          // 20dp rounded layered card.
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cardSurfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author header row.
                  GestureDetector(
                    onTap: onToggleCollapse,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: _getAuthorAvatarColor(author),
                          child: Text(
                            author.isNotEmpty
                                ? author[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'u/$author',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isOp
                                ? const Color(0xFFA78BFA)
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (isOp) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFA78BFA).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OP',
                              style: TextStyle(
                                color: Color(0xFFA78BFA),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          '· $timeAgo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (isCollapsed && replyCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22222A),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+$replyCount',
                              style: const TextStyle(
                                color: Color(0xFFA78BFA),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Comment body text.
                  if (!isCollapsed) ...[
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Blueprint-aligned action controls.
                    Row(
                      children: [
                        // 1. Upvote — reports the tapped direction; the parent
                        // owns the toggle decision and score arithmetic.
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onVote?.call(1);
                          },
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: voteState == 1
                                ? const Color(0xFFFF5722)
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$score',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: voteState == 1
                                  ? const Color(0xFFFF5722)
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        // 2. Downvote.
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onVote?.call(-1);
                          },
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                            color: voteState == -1
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // 3. Reply action, left-aligned next to votes.
                        InkWell(
                          onTap: onReply,
                          child: Row(
                            children: [
                              Icon(Icons.reply_rounded,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                'Reply',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // 4. Overflow action, grouped left next to Reply.
                        InkWell(
                          onTap: onOverflow,
                          child: Icon(Icons.more_horiz_rounded,
                              size: 18, color: colorScheme.onSurfaceVariant),
                        ),

                        const Spacer(),

                        // 5. Save bookmark, right-aligned — reflects the
                        // parent-owned [isSaved] state.
                        InkWell(
                          onTap: onSave,
                          child: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_outline_rounded,
                            size: 18,
                            color: isSaved
                                ? const Color(0xFFA78BFA)
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 6. Award / badge action, right-aligned.
                        InkWell(
                          onTap: onAward,
                          child: Icon(Icons.military_tech_outlined,
                              size: 18, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],

                  // Nested expansion pill.
                  if (replyCount > 0 &&
                      onLoadMoreReplies != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: onLoadMoreReplies,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22222A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View $replyCount more replies',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
