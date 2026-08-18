import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/shape_tokens.dart';

class M3ECommentCard extends StatelessWidget {
  const M3ECommentCard({
    super.key,
    required this.author,
    required this.created,
    required this.depth,
    required this.isOp,
    required this.isDeleted,
    required this.collapsed,
    required this.score,
    required this.scoreHidden,
    required this.likes,
    required this.saved,
    required this.onToggle,
    required this.onUpvote,
    required this.onDownvote,
    required this.onReply,
    required this.onSave,
    this.body,
    this.media,
    this.overflowAction,
    this.collapsedPreview,
    this.highlighted = false,
  });

  final String author;
  final DateTime created;
  final int depth;
  final bool isOp;
  final bool isDeleted;
  final bool collapsed;
  final int score;
  final bool scoreHidden;
  final bool? likes;
  final bool saved;
  final Widget? body;
  final Widget? media;
  final Widget? overflowAction;
  final String? collapsedPreview;
  final bool highlighted;
  final VoidCallback onToggle;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback onReply;
  final VoidCallback onSave;

  Color _railColor(ColorScheme colorScheme) {
    final palette = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
    ];
    if (depth <= 0) return palette.first;
    return palette[(depth - 1) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final railColor = _railColor(colorScheme);
    final upvoted = likes == true;
    final downvoted = likes == false;
    final scoreColor = upvoted
        ? colorScheme.primary
        : downvoted
            ? colorScheme.error
            : colorScheme.onSurfaceVariant;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: highlighted
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainer,
          borderRadius: ShapeTokens.medium,
          border: highlighted
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (depth > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Container(
                    key: ValueKey<String>('comment-depth-rail-$depth'),
                    width: 3,
                    decoration: BoxDecoration(
                      color: railColor,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(left: depth > 0 ? 18 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 12, 8),
                      child: Row(
                        children: [
                          _AuthorAvatar(
                            author: author,
                            deleted: isDeleted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isDeleted ? '[deleted]' : 'u/$author',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: isDeleted
                                              ? colorScheme.onSurfaceVariant
                                              : colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                if (isOp && !isDeleted) ...[
                                  const SizedBox(width: 6),
                                  _OpBadge(colorScheme: colorScheme),
                                ],
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '·  ${timeAgo(created)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            collapsed
                                ? Icons.expand_more_rounded
                                : Icons.expand_less_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: collapsed
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                              child: Text(
                                collapsedPreview ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (body != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: body,
                                  ),
                                if (media != null) media!,
                                _CommentActions(
                                  score: score,
                                  scoreHidden: scoreHidden,
                                  scoreColor: scoreColor,
                                  upvoted: upvoted,
                                  downvoted: downvoted,
                                  saved: saved,
                                  onUpvote: onUpvote,
                                  onDownvote: onDownvote,
                                  onReply: onReply,
                                  onSave: onSave,
                                  overflowAction: overflowAction,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.author, required this.deleted});

  final String author;
  final bool deleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: deleted
            ? colorScheme.surfaceContainerHighest
            : colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        deleted || author.isEmpty ? '?' : author[0].toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _OpBadge extends StatelessWidget {
  const _OpBadge({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: ShapeTokens.extraSmall,
      ),
      child: Text(
        'OP',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _CommentActions extends StatelessWidget {
  const _CommentActions({
    required this.score,
    required this.scoreHidden,
    required this.scoreColor,
    required this.upvoted,
    required this.downvoted,
    required this.saved,
    required this.onUpvote,
    required this.onDownvote,
    required this.onReply,
    required this.onSave,
    this.overflowAction,
  });

  final int score;
  final bool scoreHidden;
  final Color scoreColor;
  final bool upvoted;
  final bool downvoted;
  final bool saved;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback onReply;
  final VoidCallback onSave;
  final Widget? overflowAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: colorScheme.surfaceContainerHighest,
              shape: const RoundedRectangleBorder(
                borderRadius: ShapeTokens.full,
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallIconButton(
                    icon: Icons.arrow_upward_rounded,
                    color: upvoted
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    tooltip: 'Upvote',
                    onPressed: onUpvote,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      scoreHidden ? '–' : compactNumber(score),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scoreColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  _SmallIconButton(
                    icon: Icons.arrow_downward_rounded,
                    color: downvoted
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    tooltip: 'Downvote',
                    onPressed: onDownvote,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CommentPill(
              icon: Icons.reply_rounded,
              label: 'Reply',
              onPressed: onReply,
            ),
            const SizedBox(width: 8),
            _SmallIconButton(
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: saved ? colorScheme.primary : colorScheme.onSurfaceVariant,
              tooltip: saved ? 'Unsave' : 'Save',
              onPressed: onSave,
              background: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(width: 4),
            overflowAction ??
                _SmallIconButton(
                  icon: Icons.more_horiz_rounded,
                  color: colorScheme.onSurfaceVariant,
                  tooltip: 'More actions',
                  onPressed: () {},
                  background: colorScheme.surfaceContainerHighest,
                ),
          ],
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.background,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final child = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
    );
    if (background == null) return child;
    return Material(
      color: background,
      shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.full),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CommentPill extends StatelessWidget {
  const _CommentPill({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class M3ECommentMorePill extends StatelessWidget {
  const M3ECommentMorePill({
    super.key,
    required this.label,
    required this.depth,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final int depth;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
    ];
    final accent = palette[depth <= 0 ? 0 : (depth - 1) % palette.length];
    final indent = (depth * 12).clamp(0, 72).toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(8 + indent, 4, 8, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: colorScheme.surfaceContainerHighest,
          shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.full),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: accent,
                    ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
