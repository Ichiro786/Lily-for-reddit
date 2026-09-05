import 'package:flutter/material.dart';

import '../../core/theme/shape_tokens.dart';

/// Compact feed presentation used by [PostDisplay.mini].
///
/// The shell is intentionally presentational: PostCard owns data, navigation,
/// media selection, and Riverpod subscriptions while this widget owns the
/// compact layout geometry.
class CompactPostCard extends StatelessWidget {
  const CompactPostCard({
    super.key,
    required this.header,
    required this.title,
    required this.actions,
    required this.onTap,
    this.flair,
    this.thumbnail,
  });

  final Widget header;
  final Widget title;
  final Widget actions;
  final VoidCallback onTap;
  final Widget? flair;
  final Widget? thumbnail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: ShapeTokens.large,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0),
        child: InkWell(
          onTap: onTap,
          borderRadius: ShapeTokens.large,
          splashColor: colorScheme.onSurface.withValues(alpha: 0.08),
          highlightColor: colorScheme.onSurface.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 8),
                      title,
                      if (flair != null) ...[
                        const SizedBox(height: 6),
                        flair!,
                      ],
                      const SizedBox(height: 8),
                      actions,
                    ],
                  ),
                ),
                if (thumbnail != null) ...[
                  const SizedBox(width: 12),
                  thumbnail!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
