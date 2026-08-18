import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/shape_tokens.dart';
import '../../data/reddit_repository.dart';
import '../../models/subreddit.dart';
import '../settings/settings_controller.dart';

class M3ESubredditHeader extends StatefulWidget {
  const M3ESubredditHeader({
    super.key,
    required this.subreddit,
    required this.joined,
    required this.onJoinToggle,
    required this.notificationsEnabled,
    required this.onNotificationToggle,
    this.onlineCount,
    this.createdAt,
    this.accessLabel,
    this.categoryLabel,
  });

  final Subreddit subreddit;
  final bool joined;
  final VoidCallback onJoinToggle;
  final bool notificationsEnabled;
  final VoidCallback onNotificationToggle;
  final int? onlineCount;
  final DateTime? createdAt;
  final String? accessLabel;
  final String? categoryLabel;

  @override
  State<M3ESubredditHeader> createState() => _M3ESubredditHeaderState();
}

class _M3ESubredditHeaderState extends State<M3ESubredditHeader> {
  bool _descriptionExpanded = false;

  String get _communityTitle {
    final title = widget.subreddit.title.trim();
    return title.isEmpty ? widget.subreddit.namePrefixed : title;
  }

  String get _createdLabel {
    final date = widget.createdAt;
    if (date == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final description = widget.subreddit.description.trim();
    final needsExpansion = description.length > 160;
    final online = widget.onlineCount ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroBanner(
            subreddit: widget.subreddit,
            colorScheme: colorScheme,
          ),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _CommunityAvatar(
                        subreddit: widget.subreddit,
                        colorScheme: colorScheme,
                      ),
                      const Spacer(),
                      _IconPill(
                        icon: widget.notificationsEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        tooltip: widget.notificationsEnabled
                            ? 'Mute notifications'
                            : 'Enable notifications',
                        onPressed: widget.onNotificationToggle,
                      ),
                      const SizedBox(width: 8),
                      _JoinButton(
                        joined: widget.joined,
                        onPressed: widget.onJoinToggle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _communityTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${compactNumber(widget.subreddit.subscribers)} members',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      if (online > 0) ...[
                        const SizedBox(width: 10),
                        const _LiveDot(),
                        const SizedBox(width: 4),
                        Text(
                          '$online online',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      description,
                      maxLines: _descriptionExpanded ? null : 3,
                      overflow: _descriptionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                    if (needsExpansion)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _descriptionExpanded = !_descriptionExpanded;
                          }),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.only(top: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _descriptionExpanded ? 'See less' : 'See more',
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 14),
                  _StatsGrid(
                    createdLabel: _createdLabel,
                    accessLabel: widget.accessLabel ?? 'Public',
                    categoryLabel: widget.categoryLabel ?? 'Community',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 0),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.subreddit, required this.colorScheme});

  final Subreddit subreddit;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        borderRadius: ShapeTokens.large,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.tertiaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (subreddit.bannerUrl != null)
            CachedNetworkImage(
              imageUrl: subreddit.bannerUrl!,
              fit: BoxFit.cover,
              memCacheWidth: 1080,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  colorScheme.scrim.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityAvatar extends StatelessWidget {
  const _CommunityAvatar({required this.subreddit, required this.colorScheme});

  final Subreddit subreddit;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.primary, width: 2),
      ),
      child: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        backgroundImage: subreddit.iconUrl == null
            ? null
            : CachedNetworkImageProvider(subreddit.iconUrl!),
        child: subreddit.iconUrl == null
            ? Text(
                subreddit.name.isEmpty
                    ? '?'
                    : subreddit.name[0].toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              )
            : null,
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.joined, required this.onPressed});

  final bool joined;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor:
            joined ? colorScheme.primaryContainer : colorScheme.primary,
        foregroundColor:
            joined ? colorScheme.onPrimaryContainer : colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        minimumSize: const Size(0, 40),
        shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(joined ? Icons.check_rounded : Icons.add_rounded, size: 18),
          const SizedBox(width: 6),
          Text(joined ? 'Joined' : 'Join'),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      elevation: 1,
      shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.full),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: colorScheme.onSurfaceVariant),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF56D364),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.createdLabel,
    required this.accessLabel,
    required this.categoryLabel,
  });

  final String createdLabel;
  final String accessLabel;
  final String categoryLabel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.calendar_month_rounded,
            label: 'Created',
            value: createdLabel,
          ),
          const SizedBox(width: 8),
          _StatCard(
            icon: Icons.public_rounded,
            label: 'Access',
            value: accessLabel,
          ),
          const SizedBox(width: 8),
          _StatCard(
            icon: Icons.sell_rounded,
            label: 'Category',
            value: categoryLabel,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 122,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: ShapeTokens.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class M3ESubredditControlBar extends StatelessWidget {
  const M3ESubredditControlBar({
    super.key,
    required this.sort,
    required this.onSortChanged,
    required this.display,
    required this.onDisplayChanged,
  });

  final PostSort sort;
  final ValueChanged<PostSort> onSortChanged;
  final PostDisplay display;
  final ValueChanged<PostDisplay> onDisplayChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeDisplay = display == PostDisplay.mini
        ? PostDisplay.mini
        : PostDisplay.card;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Row(
        children: [
          _SortCapsule(
            sort: sort,
            onSelected: onSortChanged,
          ),
          const Spacer(),
          Material(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: ShapeTokens.full,
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewModeButton(
                  icon: Icons.view_agenda_outlined,
                  label: 'Card',
                  active: activeDisplay == PostDisplay.card,
                  onTap: () => onDisplayChanged(PostDisplay.card),
                ),
                _ViewModeButton(
                  icon: Icons.view_list_rounded,
                  label: 'Compact',
                  active: activeDisplay == PostDisplay.mini,
                  onTap: () => onDisplayChanged(PostDisplay.mini),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortCapsule extends StatelessWidget {
  const _SortCapsule({required this.sort, required this.onSelected});

  final PostSort sort;
  final ValueChanged<PostSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<PostSort>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in PostSort.values)
          PopupMenuItem<PostSort>(
            value: option,
            child: Row(
              children: [
                Icon(_sortIcon(option), size: 18),
                const SizedBox(width: 10),
                Text(option.label),
                const Spacer(),
                if (option == sort) const Icon(Icons.check_rounded, size: 18),
              ],
            ),
          ),
      ],
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.full),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort_rounded,
                  size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                sort.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  IconData _sortIcon(PostSort value) => switch (value) {
        PostSort.best => Icons.star_rounded,
        PostSort.hot => Icons.local_fire_department_rounded,
        PostSort.newest => Icons.schedule_rounded,
        PostSort.top => Icons.leaderboard_rounded,
        PostSort.rising => Icons.trending_up_rounded,
      };
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: active
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: active
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
