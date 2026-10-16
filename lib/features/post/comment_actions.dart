import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/format.dart';
import '../../core/theme/app_theme.dart';

/// Deliberate one/two-row composition: More always anchors the first row.
/// App geometry adapts to indentation; every icon retains a 48dp touch target.
class CommentActions extends StatelessWidget {
  const CommentActions({
    super.key,
    required this.score,
    required this.voteState,
    required this.isSaved,
    this.onVote,
    this.onReply,
    this.onSave,
    this.onOverflow,
    this.onAward,
  });
  final int score, voteState;
  final bool isSaved;
  final ValueChanged<int>? onVote;
  final VoidCallback? onReply, onSave, onOverflow, onAward;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = theme.extension<VoteColors>();
    final voteColor = voteState == 1
        ? colors?.up ?? cs.primary
        : voteState == -1
        ? colors?.down ?? cs.tertiary
        : cs.onSurfaceVariant;
    Widget icon(
      String label,
      IconData data,
      VoidCallback? onPressed, {
      Color? color,
      bool selected = false,
      bool contained = true,
    }) => IconButton(
      tooltip: label,
      onPressed: onPressed,
      isSelected: selected,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.all(12),
      style: IconButton.styleFrom(
        foregroundColor: color ?? cs.onSurfaceVariant,
        backgroundColor: contained
            ? cs.surfaceContainerLow
            : Colors.transparent,
        side: contained ? BorderSide(color: cs.outline) : BorderSide.none,
      ),
      icon: Icon(data, size: 22, color: color ?? cs.onSurfaceVariant),
    );
    final vote = DecoratedBox(
      decoration: ShapeDecoration(
        color: cs.surfaceContainerLow,
        shape: StadiumBorder(side: BorderSide(color: cs.outline)),
      ),
      child: Row(
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
            color: voteState == 1 ? voteColor : null,
            selected: voteState == 1,
            contained: false,
          ),
          Flexible(
            child: Semantics(
              label: '$score points',
              excludeSemantics: true,
              child: Text(
                compactNumber(score),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: voteColor,
                ),
              ),
            ),
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
            color: voteState == -1 ? voteColor : null,
            selected: voteState == -1,
            contained: false,
          ),
        ],
      ),
    );
    final reply = OutlinedButton.icon(
      onPressed: onReply,
      icon: const Icon(Icons.reply_rounded, size: 22),
      label: const Text('Reply'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: cs.onSurfaceVariant,
        backgroundColor: cs.surfaceContainerLow,
      ),
    );
    final save = icon(
      isSaved ? 'Unsave comment' : 'Save comment',
      isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
      onSave,
      selected: isSaved,
      color: isSaved ? cs.primary : null,
    );
    final more = icon(
      'More comment options',
      Icons.more_horiz_rounded,
      onOverflow,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // The measured label budget includes system font scaling. Narrow threads
        // use a second intentional action row, never an orphan overflow menu.
        final scorePainter = TextPainter(
          text: TextSpan(
            text: compactNumber(score),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final voteWidth = 96 + scorePainter.width;
        scorePainter.dispose();
        final inline = constraints.maxWidth >= voteWidth + 3 * 48 + 18;
        final replyPainter = TextPainter(
          text: TextSpan(text: 'Reply', style: theme.textTheme.labelLarge),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        // App decision: reserve icon, gap, padding and border space around Reply.
        final replyWidth = replyPainter.width + 64;
        replyPainter.dispose();
        final labelled =
            constraints.maxWidth >= voteWidth + replyWidth + 2 * 48 + 18;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: math.min(voteWidth, constraints.maxWidth - 54),
                  child: vote,
                ),
                const SizedBox(width: 6),
                if (inline) ...[
                  if (labelled)
                    reply
                  else
                    icon('Reply', Icons.reply_rounded, onReply),
                  const SizedBox(width: 6),
                  save,
                  const SizedBox(width: 6),
                ],
                const Spacer(),
                more,
              ],
            ),
            if (!inline) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(child: reply),
                  const SizedBox(width: 6),
                  save,
                ],
              ),
            ],
            if (onAward != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: icon('Award', Icons.workspace_premium_rounded, onAward),
              ),
          ],
        );
      },
    );
  }
}
