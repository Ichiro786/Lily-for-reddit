import 'package:flutter/material.dart';

/// Scrolling homepage title and the existing expandable-toolbar entry point.
class FrontpageHeader extends StatelessWidget {
  const FrontpageHeader({super.key, required this.forYou, this.onToolbar});

  final bool forYou;
  final VoidCallback? onToolbar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    forYou ? 'For You' : 'Frontpage',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (forYou)
                  Text(
                    'Personalized on-device · Beta',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (onToolbar != null)
            IconButton.filledTonal(
              tooltip: 'Toolbar',
              onPressed: onToolbar,
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: cs.surfaceContainerLow,
                foregroundColor: cs.onSurface,
              ),
              icon: const Icon(Icons.more_vert_rounded),
            ),
        ],
      ),
    );
  }
}
