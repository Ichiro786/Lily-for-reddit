import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/shape_tokens.dart';

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

  /// Pre-rendered Markdown/spoiler body from the flattened-comment pipeline.
  /// When null (or when collapsed) [body] renders as plain text instead, so
  /// exactly one rendering path is ever used per comment.
  final Widget? richBody;
  final int score;
  final int voteState; // 1 = upvoted, -1 = downvoted, 0 = none
  final bool isSaved;
  final int depth;
  final bool isOp;
  final bool isCollapsed;
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
    this.richBody,
    this.score = 0,
    this.voteState = 0,
    this.isSaved = false,
    this.depth = 0,
    this.isOp = false,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.onReply,
    this.onSave,
    this.onAward,
    this.onOverflow,
    this.onVote,
    this.replyCount = 0,
    this.onLoadMoreReplies,
  });

  /// Depth rails cycle through the scheme's tonal accents at reduced opacity:
  /// expressive enough to trace nesting, subordinate to the card content, and
  /// fully responsive to seed/dynamic color.
  Color _getDepthRailColor(ColorScheme cs, int depth) {
    final accents = [cs.primary, cs.secondary, cs.tertiary];
    return accents[(depth - 1) % accents.length].withValues(alpha: 0.55);
  }

  /// Deterministic per-author avatar colors built from the scheme's container
  /// pairs, so every theme (light/dark/AMOLED/dynamic) yields readable combos.
  ({Color background, Color foreground}) _getAuthorAvatarColor(
      ColorScheme cs, String name) {
    final containers = [
      (
        background: cs.primaryContainer,
        foreground: cs.onPrimaryContainer,
      ),
      (
        background: cs.secondaryContainer,
        foreground: cs.onSecondaryContainer,
      ),
      (
        background: cs.tertiaryContainer,
        foreground: cs.onTertiaryContainer,
      ),
    ];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return containers[hash % containers.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final votes = theme.extension<VoteColors>();
    final upvoteColor = votes?.up ?? colorScheme.primary;
    final hasDepth = depth > 0;

    // Layered M3E surface hierarchy: the comment card floats one tonal step
    // above the scaffold (AMOLED black included) via surfaceContainer.
    final cardSurfaceColor = colorScheme.surfaceContainer;

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
          // 3.5dp tonal depth rail for nested replies (theme-driven accents).
          if (hasDepth)
            Container(
              key: ValueKey<String>('comment-depth-rail-$depth'),
              width: 3.5,
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: _getDepthRailColor(colorScheme, depth),
                borderRadius: ShapeTokens.full,
              ),
            ),

          // Rounded layered card.
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cardSurfaceColor,
                borderRadius: ShapeTokens.medium,
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
                        Builder(builder: (context) {
                          final avatar =
                              _getAuthorAvatarColor(colorScheme, author);
                          return CircleAvatar(
                            radius: 13,
                            backgroundColor: avatar.background,
                            child: Text(
                              author.isNotEmpty
                                  ? author[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: avatar.foreground,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          'u/$author',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color:
                                isOp ? colorScheme.primary : colorScheme.onSurface,
                          ),
                        ),
                        if (isOp) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: ShapeTokens.extraSmall,
                            ),
                            child: Text(
                              'OP',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
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
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: ShapeTokens.full,
                            ),
                            child: Text(
                              '+$replyCount',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Comment body text — the pre-rendered Markdown/spoiler
                  // widget when supplied, plain text otherwise.
                  if (!isCollapsed) ...[
                    const SizedBox(height: 8),
                    if (richBody != null)
                      richBody!
                    else
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
                                ? upvoteColor
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
                                  ? upvoteColor
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
                                ? colorScheme.primary
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
                      borderRadius: ShapeTokens.full,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: ShapeTokens.full,
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
