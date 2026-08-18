import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/shape_tokens.dart';
import '../../models/subreddit.dart';
import '../history/history_store.dart';
import '../home/tab_signals.dart';
import 'm3e_explore_widgets.dart';

final subscribedSubredditsProvider =
    FutureProvider.autoDispose<List<Subreddit>>((ref) async {
  return ref.watch(redditRepositoryProvider).getSubscribedSubreddits();
});

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggleJoin(Subreddit subreddit) async {
    final next = subreddit.userIsSubscriber != true;
    try {
      await ref.read(redditRepositoryProvider).setSubscribed(subreddit.name, next);
      ref.invalidate(subscribedSubredditsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update community: $error')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Subreddit subreddit) async {
    try {
      await ref
          .read(redditRepositoryProvider)
          .setSubredditFavorite(subreddit.name, !subreddit.userHasFavorited);
      ref.invalidate(subscribedSubredditsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update favorite: $error')),
        );
      }
    }
  }

  void _showCommunityActions(Subreddit subreddit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: Text('Open ${subreddit.namePrefixed}'),
              onTap: () {
                Navigator.pop(context);
                this.context.push('/r/${subreddit.name}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy community link'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Subreddit> _filtered(List<Subreddit> input) {
    final query = _query.trim().toLowerCase();
    return [
      for (final subreddit in input)
        if ((query.isEmpty ||
                subreddit.name.toLowerCase().contains(query) ||
                subreddit.title.toLowerCase().contains(query)) &&
            (_filter == 'all' ||
                (_filter == 'favorites' && subreddit.userHasFavorited) ||
                (_filter == 'joined' && subreddit.userIsSubscriber == true)))
          subreddit,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final communities = ref.watch(subscribedSubredditsProvider);

    ref.listen<int>(tabReselectProvider(1), (_, __) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(subscribedSubredditsProvider),
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Material(
                    color: colorScheme.surfaceContainerLow,
                    shape: const RoundedRectangleBorder(
                      borderRadius: ShapeTokens.extraLarge,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search communities and posts',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      for (final filter in const [
                        ('all', 'All'),
                        ('favorites', 'Favorites'),
                        ('joined', 'Joined'),
                      ]) ...[
                        FilterChip(
                          label: Text(filter.$2),
                          selected: _filter == filter.$1,
                          onSelected: (_) =>
                              setState(() => _filter = filter.$1),
                          shape: const RoundedRectangleBorder(
                            borderRadius: ShapeTokens.full,
                          ),
                          selectedColor: colorScheme.primaryContainer,
                          checkmarkColor: colorScheme.onPrimaryContainer,
                          labelStyle: TextStyle(
                            color: _filter == filter.$1
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                          side: BorderSide(
                            color: _filter == filter.$1
                                ? Colors.transparent
                                : colorScheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              ...communities.when(
                loading: () => const [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ],
                error: (error, _) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('Could not load communities: $error'),
                      ),
                    ),
                  ),
                ],
                data: (raw) {
                  final list = _filtered(raw);
                  final popular = [...list]
                    ..sort((a, b) => b.subscribers.compareTo(a.subscribers));
                  final recentByName = {
                    for (final subreddit in list) subreddit.name.toLowerCase(): subreddit,
                  };
                  final recent = <Subreddit>[];
                  final seen = <String>{};
                  for (final entry in ref.watch(historyControllerProvider)) {
                    final subreddit =
                        recentByName[entry.subreddit.toLowerCase()];
                    if (subreddit != null && seen.add(subreddit.name)) {
                      recent.add(subreddit);
                    }
                    if (recent.length == 8) break;
                  }
                  final recentNames = {for (final s in recent) s.name};
                  final rest = list
                      .where((subreddit) => !recentNames.contains(subreddit.name))
                      .toList();
                  return [
                    SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'Popular near you',
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ),
                    if (popular.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
                          child: Text('No communities match this filter.'),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 190,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            itemCount: popular.take(8).length,
                            itemBuilder: (context, index) {
                              final subreddit = popular[index];
                              return M3EPopularCommunityCard(
                                subreddit: subreddit,
                                onTap: () =>
                                    context.push('/r/${subreddit.name}'),
                                onJoin: () => _toggleJoin(subreddit),
                              );
                            },
                          ),
                        ),
                      ),
                    if (recent.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionTitle(
                          title: 'Recently visited',
                          icon: Icons.history_rounded,
                        ),
                      ),
                      SliverList.builder(
                        itemCount: recent.length,
                        itemBuilder: (context, index) {
                          final subreddit = recent[index];
                          return M3ERecentCommunityTile(
                            subreddit: subreddit,
                            onTap: () => context.push('/r/${subreddit.name}'),
                            onFavorite: () => _toggleFavorite(subreddit),
                            onMore: () => _showCommunityActions(subreddit),
                          );
                        },
                      ),
                    ],
                    SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: recent.isEmpty ? 'Communities' : 'All communities',
                        icon: Icons.groups_rounded,
                      ),
                    ),
                    if (rest.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Text('You have reached the end of this list.'),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: rest.length,
                        itemBuilder: (context, index) {
                          final subreddit = rest[index];
                          return M3ERecentCommunityTile(
                            subreddit: subreddit,
                            onTap: () => context.push('/r/${subreddit.name}'),
                            onFavorite: () => _toggleFavorite(subreddit),
                            onMore: () => _showCommunityActions(subreddit),
                          );
                        },
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 130)),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 19, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
