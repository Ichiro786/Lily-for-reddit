import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../models/reddit_user.dart';
import 'profile_media.dart';

/// Media dimensions and header spacing are app design decisions based on the
/// supplied concept; typography and colors use Material semantic theme roles.
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.user,
    required this.isSelf,
    this.onManageAccount,
    this.onMessage,
  });
  final RedditUser user;
  final bool isSelf;
  final VoidCallback? onManageAccount, onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final knownAge =
        user.created.year > 1970 && !user.created.isAfter(DateTime.now());
    final days = DateTime.now().difference(user.created).inDays;
    final age = days >= 365 ? '${days ~/ 365}y' : '${days}d';
    final stats = [
      (Icons.auto_awesome_rounded, compactNumber(user.linkKarma), 'Post karma'),
      (Icons.forum_outlined, compactNumber(user.commentKarma), 'Comment karma'),
      if (knownAge) (Icons.cake_outlined, age, 'Reddit age'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: ProfileBanner(url: user.bannerUrl),
              ),
              PositionedDirectional(
                start: 16,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surface,
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: ProfileAvatar(
                    username: user.name,
                    url: user.iconUrl,
                    size: 88,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName.isEmpty ? user.name : user.displayName,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'u/${user.name}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (user.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              user.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isSelf && onManageAccount != null)
                FilledButton.icon(
                  onPressed: onManageAccount,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Manage accounts'),
                ),
              if (!isSelf && onMessage != null)
                FilledButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Message'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
              final columns = largeText || constraints.maxWidth < 300
                  ? 1
                  : stats.length;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: LayoutBuilder(
                  builder: (context, inner) => Wrap(
                    spacing: 12,
                    runSpacing: 16,
                    children: [
                      for (final stat in stats)
                        SizedBox(
                          width:
                              ((inner.maxWidth - (columns - 1) * 12) / columns)
                                  .floorToDouble(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(stat.$1, color: cs.primary),
                              const SizedBox(height: 8),
                              Text(
                                stat.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                stat.$3,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
