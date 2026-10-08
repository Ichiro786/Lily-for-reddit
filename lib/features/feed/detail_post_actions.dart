part of 'post_action_bar.dart';

class _DetailPostActions extends StatelessWidget {
  const _DetailPostActions({
    required this.score,
    required this.comments,
    required this.voteState,
    required this.isSaved,
    required this.up,
    required this.down,
    this.onVote,
    this.onComments,
    this.onSave,
    this.onShare,
  });
  final String score, comments;
  final int voteState;
  final bool isSaved;
  final Color up, down;
  final ValueChanged<int>? onVote;
  final VoidCallback? onComments, onSave, onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Widget pill(Widget child) => SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            top: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: cs.surfaceContainerHigh,
                shape: StadiumBorder(side: BorderSide(color: cs.outline)),
              ),
            ),
          ),
          child,
        ],
      ),
    );
    Widget icon(
      String label,
      IconData data,
      VoidCallback? callback, {
      Color? color,
      bool selected = false,
    }) => IconButton(
      tooltip: label,
      isSelected: selected,
      onPressed: callback,
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      icon: Icon(data, size: 24, color: color ?? cs.onSurfaceVariant),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          pill(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon(
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
                Text(
                  score,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: voteState == 1
                        ? up
                        : voteState == -1
                        ? down
                        : cs.onSurface,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 20,
                  child: VerticalDivider(width: 1, color: cs.outlineVariant),
                ),
                icon(
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
          const SizedBox(width: 8),
          Semantics(
            button: true,
            onTap: onComments,
            label: '$comments comments',
            excludeSemantics: true,
            child: InkWell(
              onTap: onComments,
              customBorder: ShapeTokens.fullShape,
              child: pill(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mode_comment_outlined,
                        size: 22,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        comments,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          pill(
            icon(
              isSaved ? 'Unsave' : 'Save',
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              onSave,
              color: isSaved ? cs.primary : null,
              selected: isSaved,
            ),
          ),
          const SizedBox(width: 8),
          pill(icon('Share', Icons.ios_share_rounded, onShare)),
        ],
      ),
    );
  }
}
