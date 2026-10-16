import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/widgets/m3e_animated_size.dart';
import 'comment_actions.dart';

/// Controlled presenter; voting, saving and collapse remain parent-owned.
class M3ECommentCard extends StatelessWidget {
  const M3ECommentCard({
    super.key,
    required this.author,
    required this.timeAgo,
    required this.body,
    this.richBody,
    this.avatar,
    this.score = 0,
    this.voteState = 0,
    this.isSaved = false,
    this.depth = 0,
    this.isOp = false,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.onViewProfile,
    this.onReply,
    this.onSave,
    this.onAward,
    this.onOverflow,
    this.onVote,
    this.replyCount = 0,
    this.onLoadMoreReplies,
  });
  final String author, timeAgo, body;
  final Widget? richBody, avatar;
  final int score, voteState, depth, replyCount;
  final bool isSaved, isOp, isCollapsed;
  final VoidCallback? onToggleCollapse,
      onViewProfile,
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
    final profileAction = onViewProfile ?? onToggleCollapse;
    // App layout decision: cap visual indentation so deep threads stay readable.
    final levels = math.min(math.max(depth, 0), 4);
    final inset = levels * 16.0;
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        children: [
          for (var level = 0; level < levels; level++)
            PositionedDirectional(
              start: level * 16 + 8,
              top: 0,
              bottom: 0,
              child: Container(
                key: level == levels - 1
                    ? ValueKey('comment-depth-rail-$depth')
                    : null,
                width: 1,
                decoration: BoxDecoration(color: cs.outlineVariant),
              ),
            ),
          if (levels > 0)
            PositionedDirectional(
              start: inset - 8,
              top: 12,
              child: Container(
                width: 12,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                  borderRadius: const BorderRadiusDirectional.only(
                    bottomStart: Radius.circular(12),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsetsDirectional.only(start: inset),
            child: Material(
              color: Colors.transparent,
              child: M3EAnimatedSize(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Semantics(
                            button: profileAction != null,
                            label: 'View profile of $author',
                            onTap: profileAction,
                            excludeSemantics: true,
                            child: InkResponse(
                              onTap: profileAction,
                              radius: 24,
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child:
                                      avatar ??
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            cs.surfaceContainerHighest,
                                        foregroundColor: cs.onSurface,
                                        child: Text(
                                          author.isEmpty
                                              ? 'U'
                                              : author.characters.first
                                                    .toUpperCase(),
                                          style: theme.textTheme.titleSmall,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: profileAction,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        'u/$author',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: isOp
                                                  ? cs.primary
                                                  : cs.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (isOp)
                                        Text(
                                          'OP',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: cs.primary),
                                        ),
                                      Text(
                                        '· $timeAgo',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                      if (isCollapsed && replyCount > 0)
                                        Text(
                                          '+$replyCount',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: cs.primary),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (onToggleCollapse != null)
                            Semantics(
                              expanded: !isCollapsed,
                              child: action(
                                isCollapsed
                                    ? 'Expand comment'
                                    : 'Collapse comment',
                                isCollapsed
                                    ? Icons.unfold_more_rounded
                                    : Icons.unfold_less_rounded,
                                onToggleCollapse,
                              ),
                            ),
                        ],
                      ),
                      if (!isCollapsed)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              richBody ??
                                  Text(
                                    body,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      height: 1.5,
                                    ),
                                  ),
                              const SizedBox(height: 4),
                              CommentActions(
                                score: score,
                                voteState: voteState,
                                isSaved: isSaved,
                                onVote: onVote,
                                onReply: onReply,
                                onSave: onSave,
                                onOverflow: onOverflow,
                                onAward: onAward,
                              ),
                            ],
                          ),
                        ),
                      if (replyCount > 0 && onLoadMoreReplies != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 48),
                          child: TextButton.icon(
                            onPressed: onLoadMoreReplies,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                            ),
                            label: Text('View $replyCount more replies'),
                            style: TextButton.styleFrom(
                              foregroundColor: cs.primary,
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                    ],
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
