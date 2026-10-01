import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/m3e_animated_size.dart';
import '../../core/theme/shape_tokens.dart';
import '../../core/theme/thread_colors.dart';

/// Controlled presenter; voting, saving and collapse remain parent-owned.
class M3ECommentCard extends StatelessWidget {
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
  final String author, timeAgo, body;
  final Widget? richBody;
  final int score, voteState, depth, replyCount;
  final bool isSaved, isOp, isCollapsed;
  final VoidCallback? onToggleCollapse,
      onReply,
      onSave,
      onAward,
      onOverflow,
      onLoadMoreReplies;
  final ValueChanged<int>? onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final votes = theme.extension<VoteColors>();
    final up = votes?.up ?? cs.primary;
    final down = votes?.down ?? cs.tertiary;
    final accents =
        theme.extension<ThreadColors>() ?? ThreadColors.fromScheme(cs);
    final pairs = [
      (cs.primaryContainer, cs.onPrimaryContainer),
      (cs.secondaryContainer, cs.onSecondaryContainer),
      (cs.tertiaryContainer, cs.onTertiaryContainer),
    ];
    final avatar =
        pairs[author.codeUnits.fold(0, (a, b) => a + b) % pairs.length];
    Widget action(
      String label,
      IconData icon,
      VoidCallback? callback, {
      Color? color,
      bool selected = false,
    }) => IconButton(
      tooltip: label,
      isSelected: selected,
      onPressed: callback,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.all(12),
      icon: Icon(icon, size: 22, color: color ?? cs.onSurfaceVariant),
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: depth > 0 ? (depth * 12.0).clamp(16.0, 40.0) : 12,
        end: 12,
        top: 4,
        bottom: 4,
      ),
      child: Stack(
        children: [
          if (depth > 0)
            PositionedDirectional(
              start: 0,
              top: 4,
              bottom: 4,
              child: Container(
                key: ValueKey<String>('comment-depth-rail-$depth'),
                width: 3.5,
                decoration: BoxDecoration(
                  color: accents.atDepth(depth),
                  borderRadius: ShapeTokens.full,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsetsDirectional.only(start: depth > 0 ? 11.5 : 0),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: ShapeTokens.medium,
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: ShapeTokens.medium,
                child: M3EAnimatedSize(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          button: onToggleCollapse != null,
                          expanded: !isCollapsed,
                          label:
                              '${isCollapsed ? 'Expand' : 'Collapse'} comment by $author',
                          child: InkWell(
                            onTap: onToggleCollapse,
                            borderRadius: ShapeTokens.small,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: avatar.$1,
                                    child: Text(
                                      author.isEmpty
                                          ? 'U'
                                          : author.characters.first
                                                .toUpperCase(),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: avatar.$2,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'u/$author',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: isOp
                                                ? cs.primary
                                                : cs.onSurface,
                                          ),
                                    ),
                                  ),
                                  if (isOp) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      'OP',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: cs.primary),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 100,
                                    ),
                                    child: Text(
                                      '· $timeAgo',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  if (isCollapsed && replyCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '+$replyCount',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: cs.primary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(height: 4),
                          richBody ??
                              Text(
                                body,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.45,
                                ),
                              ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 2,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: cs.surfaceContainerHigh.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    action(
                                      'Upvote',
                                      Icons.arrow_upward_rounded,
                                      onVote == null
                                          ? null
                                          : () {
                                              HapticFeedback.selectionClick();
                                              onVote!(1);
                                            },
                                      color: voteState == 1 ? up : null,
                                      selected: voteState == 1,
                                    ),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 64,
                                      ),
                                      child: Text(
                                        '$score',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: voteState == 1
                                                  ? up
                                                  : voteState == -1
                                                  ? down
                                                  : cs.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                    action(
                                      'Downvote',
                                      Icons.arrow_downward_rounded,
                                      onVote == null
                                          ? null
                                          : () {
                                              HapticFeedback.selectionClick();
                                              onVote!(-1);
                                            },
                                      color: voteState == -1 ? down : null,
                                      selected: voteState == -1,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: onReply,
                                icon: const Icon(Icons.reply_rounded, size: 22),
                                label: const Text('Reply'),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.onSurfaceVariant,
                                  minimumSize: const Size(0, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                              action(
                                'More comment options',
                                Icons.more_horiz_rounded,
                                onOverflow,
                              ),
                              action(
                                isSaved ? 'Unsave comment' : 'Save comment',
                                isSaved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_outline_rounded,
                                onSave,
                                color: isSaved ? cs.primary : null,
                                selected: isSaved,
                              ),
                              if (onAward != null)
                                action(
                                  'Award',
                                  Icons.military_tech_outlined,
                                  onAward,
                                ),
                            ],
                          ),
                        ],
                        if (replyCount > 0 && onLoadMoreReplies != null)
                          TextButton.icon(
                            onPressed: onLoadMoreReplies,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                            ),
                            label: Text('View $replyCount more replies'),
                            style: TextButton.styleFrom(
                              backgroundColor: cs.surfaceContainerHigh,
                              foregroundColor: cs.onSurfaceVariant,
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
