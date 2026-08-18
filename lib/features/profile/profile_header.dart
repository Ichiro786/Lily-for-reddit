import 'package:flutter/material.dart';

import '../../core/theme/shape_tokens.dart';

class M3EProfileHeader extends StatelessWidget {
  const M3EProfileHeader({
    super.key,
    required this.username,
    required this.onSwitchAccount,
    required this.onViewProfile,
    this.subtitle,
    this.details,
  });

  final String username;
  final VoidCallback onSwitchAccount;
  final VoidCallback onViewProfile;
  final String? subtitle;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: ShapeTokens.medium,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary, width: 2),
            ),
            child: Text(
              initial,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onSwitchAccount,
                  borderRadius: ShapeTokens.extraSmall,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'u/$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                if (details != null)
                  Text(
                    details!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                TextButton(
                  onPressed: onViewProfile,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View profile  ›'),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onSwitchAccount,
            tooltip: 'Switch or add account',
            icon: const Icon(Icons.people_alt_rounded),
          ),
        ],
      ),
    );
  }
}
