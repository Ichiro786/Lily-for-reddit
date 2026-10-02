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
    return SizedBox(
      width: 144,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Material(
          color: colorScheme.surfaceContainer,
          borderRadius: ShapeTokens.medium,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _CommunityAvatar(subreddit: subreddit, size: 44),
                  const SizedBox(height: 8),
                  Text(
                    subreddit.namePrefixed,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${compactNumber(subreddit.subscribers)} members',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: onJoin,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        joined ? 'Joined' : 'Join',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

class M3ERecentCommunityTile extends StatelessWidget {
  const M3ERecentCommunityTile({
    super.key,
    required this.subreddit,
    required this.onTap,
    required this.onFavorite,
    required this.onMore,
    this.isFirst = true,
    this.isLast = true,
  });

  final Subreddit subreddit;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onMore;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasActive =
        subreddit.accountsActive != null && subreddit.accountsActive! > 0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(24) : Radius.zero,
        bottom: isLast ? const Radius.circular(24) : Radius.zero,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: colorScheme.surfaceContainer,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          shape: shape,
          dense: true,
          minVerticalPadding: 10,
          horizontalTitleGap: 12,
          contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
          leading: _CommunityAvatar(subreddit: subreddit, size: 40),
          title: Text(
            subreddit.namePrefixed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${compactNumber(subreddit.subscribers)} members${hasActive ? ' · ${compactNumber(subreddit.accountsActive!)} online' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            )
          : null,
    );
  }
}
