import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/shape_tokens.dart';
import '../../models/subreddit.dart';

class M3EPopularCommunityCard extends StatelessWidget {
  const M3EPopularCommunityCard({
    super.key,
    required this.subreddit,
    required this.onTap,
    required this.onJoin,
  });

  final Subreddit subreddit;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final joined = subreddit.userIsSubscriber == true;
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: ShapeTokens.medium,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: ShapeTokens.medium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CommunityAvatar(subreddit: subreddit, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subreddit.namePrefixed,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${compactNumber(subreddit.subscribers)} members',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: colorScheme.primaryContainer,
                shape: const RoundedRectangleBorder(
                  borderRadius: ShapeTokens.full,
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onJoin,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      joined ? 'Joined' : 'Join',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class M3ERecentCommunityTile extends StatelessWidget {
  const M3ERecentCommunityTile({
    super.key,
    required this.subreddit,
    required this.onTap,
    required this.onFavorite,
    required this.onMore,
  });

  final Subreddit subreddit;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: ShapeTokens.small,
      ),
      child: ListTile(
        onTap: onTap,
        shape: const RoundedRectangleBorder(
          borderRadius: ShapeTokens.small,
        ),
        leading: _CommunityAvatar(subreddit: subreddit, size: 40),
        title: Text(
          subreddit.namePrefixed,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                '${compactNumber(subreddit.subscribers)} members',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.circle, size: 7, color: colorScheme.tertiary),
            const SizedBox(width: 4),
            Text(
              'Live unavailable',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onFavorite,
              tooltip: subreddit.userHasFavorited
                  ? 'Remove favorite'
                  : 'Add favorite',
              icon: Icon(
                subreddit.userHasFavorited
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: subreddit.userHasFavorited
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              onPressed: onMore,
              tooltip: 'More community actions',
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityAvatar extends StatelessWidget {
  const _CommunityAvatar({required this.subreddit, required this.size});

  final Subreddit subreddit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colorScheme.secondaryContainer,
      foregroundColor: colorScheme.onSecondaryContainer,
      backgroundImage: subreddit.iconUrl == null
          ? null
          : CachedNetworkImageProvider(subreddit.iconUrl!),
      child: subreddit.iconUrl == null
          ? Text(
              subreddit.name.isEmpty ? '?' : subreddit.name[0].toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            )
          : null,
    );
  }
}
