import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class M3ECommentCard extends StatefulWidget {
  final String author;
  final String timeAgo;
  final String body;
  final int score;
  final int depth;
  final bool isOp;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final VoidCallback? onReply;
  final VoidCallback? onSave;
  final ValueChanged<int>? onVote;
  final int replyCount;

  const M3ECommentCard({
    super.key,
    required this.author,
    required this.timeAgo,
    required this.body,
    this.score = 0,
    this.depth = 0,
    this.isOp = false,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.onReply,
    this.onSave,
    this.onVote,
    this.replyCount = 0,
  });

  @override
  State<M3ECommentCard> createState() => _M3ECommentCardState();
}

class _M3ECommentCardState extends State<M3ECommentCard> {
  int _voteState = 0;

  Color _getDepthRailColor(ColorScheme scheme, int depth) {
    switch ((depth - 1) % 4) {
      case 0:
        return const Color(0xFFA78BFA); // Iris Purple
      case 1:
        return const Color(0xFF7DD3FC); // Sky Blue
      case 2:
        return const Color(0xFFF9A8D4); // Soft Pink
      default:
        return const Color(0xFFFDE047); // Soft Amber
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDepth = widget.depth > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: hasDepth ? (widget.depth * 12.0).clamp(12.0, 48.0) : 12.0,
        right: 12.0,
        top: 4.0,
        bottom: 4.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasDepth) ...[
            Container(
              width: 3.5,
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: _getDepthRailColor(colorScheme, widget.depth),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author row
                  GestureDetector(
                    onTap: widget.onToggleCollapse,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            widget.author.isNotEmpty ? widget.author[0].toUpperCase() : 'U',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'u/${widget.author}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: widget.isOp ? colorScheme.primary : colorScheme.onSurface,
                          ),
                        ),
                        if (widget.isOp) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'OP',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          '· ${widget.timeAgo}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (widget.isCollapsed && widget.replyCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+${widget.replyCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!widget.isCollapsed) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Action items
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _voteState = _voteState == 1 ? 0 : 1);
                            widget.onVote?.call(_voteState);
                          },
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: _voteState == 1 ? const Color(0xFFFF5722) : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '${widget.score + _voteState}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _voteState == 1 ? const Color(0xFFFF5722) : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _voteState = _voteState == -1 ? 0 : -1);
                            widget.onVote?.call(_voteState);
                          },
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                            color: _voteState == -1 ? colorScheme.error : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: widget.onReply,
                          child: Row(
                            children: [
                              Icon(Icons.reply_rounded, size: 18, color: colorScheme.onSurfaceVariant),
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
                        const Spacer(),
                        InkWell(
                          onTap: widget.onSave,
                          child: Icon(Icons.bookmark_outline_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.more_horiz_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                      ],
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
