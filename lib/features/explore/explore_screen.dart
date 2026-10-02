import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/root_messenger.dart';
import '../../core/theme/shape_tokens.dart';
import '../../core/widgets/error_view.dart';
import '../../models/subreddit.dart';
import '../history/history_store.dart';
import '../history/visited_subreddits_store.dart';
import '../home/tab_signals.dart';
import '../auth/auth_controller.dart';
import 'm3e_explore_widgets.dart';

final subscribedSubredditsProvider =
    FutureProvider.autoDispose<List<Subreddit>>((ref) async {
      final authReady = ref.watch(authControllerProvider.future);
      final transitioning = ref.watch(authTransitionProvider);
      var active = true;
      ref.onDispose(() => active = false);
      if (transitioning) return const [];
      final session = await authReady;
      if (!active || session == null) return const [];
      return ref.watch(redditRepositoryProvider).getSubscribedSubreddits();
    });

final popularSubredditsProvider = FutureProvider.autoDispose<List<Subreddit>>((
  ref,
) async {
  final authReady = ref.watch(authControllerProvider.future);
  final transitioning = ref.watch(authTransitionProvider);
  var active = true;
  ref.onDispose(() => active = false);
  if (transitioning) return const [];
  await authReady;
  if (!active) return const [];
  return ref.watch(redditRepositoryProvider).getPopularSubreddits();
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
  String _sort = 'default';
  final _pending = <String>{};
  final _updated = <String, Subreddit>{};

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _openCommunity(Subreddit subreddit) {
    ref.read(visitedCommunityStoreProvider.notifier).recordVisit(subreddit);
    context.push('/r/${subreddit.name}');
  }

  Future<void> _updateCommunity(
    Subreddit subreddit, {
    required bool favorite,
  }) async {
    if (ref.read(authTransitionProvider)) return;
    if (ref.read(authControllerProvider).valueOrNull == null) {
      context.push('/login');
      return;
    }
    final name = subreddit.name.toLowerCase();
    if (!_pending.add(name)) return;
    final epoch = ref.read(authSessionEpochProvider);
    final next = favorite
        ? !subreddit.userHasFavorited
        : subreddit.userIsSubscriber != true;
    final repo = ref.read(redditRepositoryProvider);
    try {
      if (favorite) {
        await repo.setSubredditFavorite(subreddit.name, next);
      } else {
        await repo.setSubscribed(subreddit.name, next);
      }
      if (!mounted || epoch != ref.read(authSessionEpochProvider)) return;
      final current = _updated[name] ?? subreddit;
      setState(() {
        _updated[name] = favorite
            ? current.copyWith(userHasFavorited: next)
            : current.copyWith(userIsSubscriber: next);
      });
      final visits = ref.read(visitedCommunityStoreProvider.notifier);
      if (favorite) {
        visits.setFavorite(subreddit.name, next);
      } else {
        visits.setSubscribed(subreddit.name, next);
      }
      ref.invalidate(subscribedSubredditsProvider);
      ref.invalidate(popularSubredditsProvider);
    } catch (_) {
      if (mounted && epoch == ref.read(authSessionEpochProvider)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update community. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted && epoch == ref.read(authSessionEpochProvider)) {
        _pending.remove(name);
      }
    }
  }

  Future<void> _toggleJoin(Subreddit subreddit) =>
      _updateCommunity(subreddit, favorite: false);
  Future<void> _toggleFavorite(Subreddit subreddit) =>
      _updateCommunity(subreddit, favorite: true);

  void _selectFilter(String filter) {
    if (filter == 'posts') {
      final query = _query.trim();
      context.push(
        query.isEmpty ? '/search' : '/search?q=${Uri.encodeComponent(query)}',
      );
      return;
    }
    setState(() => _filter = filter);
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            for (final option in const [
              ('default', 'Recommended'),
              ('name', 'Name'),
              ('members', 'Most members'),
            ])
              ListTile(
                title: Text(option.$2),
                selected: _sort == option.$1,
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _sort = option.$1);
                },
              ),
          ],
        ),
      ),
    );
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
                _openCommunity(subreddit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy community link'),
              onTap: () {
                Navigator.pop(context);
                final url = 'https://reddit.com/r/${subreddit.name}';
                Clipboard.setData(ClipboardData(text: url));
                showRootSnackBar(
                  const SnackBar(content: Text('Community link copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final f in const [
              ('all', 'All', Icons.grid_view_rounded),
              ('communities', 'Communities', Icons.groups_rounded),
              ('posts', 'Posts', Icons.article_rounded),
              ('joined', 'Joined', Icons.check_circle_outline_rounded),
              ('favorites', 'Favorites', Icons.star_border_rounded),
            ])
              ListTile(
                leading: Icon(f.$3),
                title: Text(f.$2),
                selected: _filter == f.$1,
                onTap: () {
                  Navigator.pop(context);
                  _selectFilter(f.$1);
                },
              ),
          ],
        ),
      ),
    );
  }

  List<Subreddit> _filtered(List<Subreddit> input) {
    final query = _query.trim().toLowerCase();
    final result =
        [
              for (final source in input)
                _updated[source.name.toLowerCase()] ?? source,
            ]
            .where(
              (subreddit) =>
                  (query.isEmpty ||
                      subreddit.name.toLowerCase().contains(query) ||
                      subreddit.title.toLowerCase().contains(query)) &&
                  (_filter == 'all' ||
                      _filter == 'communities' ||
                      (_filter == 'favorites' && subreddit.userHasFavorited) ||
                      (_filter == 'joined' &&
                          subreddit.userIsSubscriber == true)),
            )
            .toList();
    if (_sort == 'name') {
      result.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    if (_sort == 'members') {
      result.sort((a, b) => b.subscribers.compareTo(a.subscribers));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loadingSession = ref.watch(authTransitionProvider);
    final subscribed = ref.watch(subscribedSubredditsProvider);
    final communities = loadingSession
        ? const AsyncLoading<List<Subreddit>>()
        : subscribed;
    final popularAsync = ref.watch(popularSubredditsProvider);
    final visitedCommunities = ref.watch(visitedCommunityStoreProvider);

    ref.listen<int>(authSessionEpochProvider, (_, __) {
      setState(() {
        _updated.clear();
        _pending.clear();
      });
    });

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
          onRefresh: () async {
            ref.read(redditRepositoryProvider).clearSubsCache();
            ref.invalidate(subscribedSubredditsProvider);
            ref.invalidate(popularSubredditsProvider);
            // Providers render failures; refreshing must not throw into the gesture.
            await AsyncValue.guard(
              () => Future.wait([
                ref.read(subscribedSubredditsProvider.future),
                ref.read(popularSubredditsProvider.future),
              ]),
            );
          },
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 2. Search dock
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Material(
                    color: colorScheme.surfaceContainerLow,
                    shape: const RoundedRectangleBorder(
                      borderRadius: ShapeTokens.extraLarge,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      onSubmitted: (value) {
                        final q = value.trim();
                        if (q.isNotEmpty) {
                          context.push('/search?q=${Uri.encodeComponent(q)}');
                        }
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search communities & posts',
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

              // 1. Prominent "Explore" headline sliver
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Explore',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),

              // 3. Filter chips row (Filter icon, All, Communities, Posts, Joined)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Filter'),
                        shape: const RoundedRectangleBorder(
                          borderRadius: ShapeTokens.full,
                        ),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        onPressed: () => _showFilterSheet(context),
                      ),
                      const SizedBox(width: 8),
                      for (final filter in const [
                        ('all', 'All'),
                        ('communities', 'Communities'),
                        ('posts', 'Posts'),
                      ]) ...[
                        FilterChip(
                          label: Text(filter.$2),
                          selected: _filter == filter.$1,
                          onSelected: (_) {
                            _selectFilter(filter.$1);
                          },
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
                      IconButton(
                        tooltip: 'Favorites',
                        isSelected: _filter == 'favorites',
                        selectedIcon: const Icon(Icons.star_rounded),
                        icon: const Icon(Icons.star_border_rounded),
                        onPressed: () => _selectFilter(
                          _filter == 'favorites' ? 'all' : 'favorites',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sort communities',
                        icon: const Icon(Icons.sort_rounded),
                        onPressed: _showSortSheet,
                      ),
                    ],
                  ),
                ),
              ),

              // Quick action: search posts for current query
              if (_query.trim().isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Material(
                      color: colorScheme.surfaceContainer,
                      shape: const RoundedRectangleBorder(
                        borderRadius: ShapeTokens.small,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.search_rounded,
                          color: colorScheme.primary,
                        ),
                        title: Text(
                          'Search all posts for "${_query.trim()}"',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        onTap: () => context.push(
                          '/search?q=${Uri.encodeComponent(_query.trim())}',
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. Communities content
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
                      child: ErrorView(
                        message:
                            'Could not load communities. Please try again.',
                        onRetry: () =>
                            ref.invalidate(subscribedSubredditsProvider),
                      ),
                    ),
                  ),
                ],
                data: (_) => const <Widget>[],
              ),
              ..._communitySlivers(
                context,
                communities.valueOrNull ?? const <Subreddit>[],
                popularAsync,
                visitedCommunities,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _communitySlivers(
    BuildContext context,
    List<Subreddit> raw,
    AsyncValue<List<Subreddit>> popularAsync,
    List<Subreddit> visitedCommunities,
  ) {
    final list = _filtered(raw);

    // Determine popular list: prefer repository API / guest fallback,
    // then fall back to subscriber-sorted subscribed list.
    final apiPopular = popularAsync.valueOrNull ?? const [];
    final rawPopular = apiPopular.isNotEmpty
        ? apiPopular
        : ([...raw]..sort((a, b) => b.subscribers.compareTo(a.subscribers)));
    final popular = _filtered(rawPopular);

    // Determine recently visited: prefer VisitedCommunityStore,
    // fallback to history controller matching subscribed list.
    List<Subreddit> recent = _filtered(visitedCommunities);
    if (recent.isEmpty) {
      final recentByName = {
        for (final subreddit in list) subreddit.name.toLowerCase(): subreddit,
      };
      final fallbackRecent = <Subreddit>[];
      final seen = <String>{};
      for (final entry in ref.watch(historyControllerProvider)) {
        final subreddit = recentByName[entry.subreddit.toLowerCase()];
        if (subreddit != null && seen.add(subreddit.name)) {
          fallbackRecent.add(subreddit);
        }
        if (fallbackRecent.length == 8) break;
      }
      recent = fallbackRecent;
    }

    final recentNames = {for (final s in recent) s.name.toLowerCase()};
    final rest = list
        .where(
          (subreddit) => !recentNames.contains(subreddit.name.toLowerCase()),
        )
        .toList();

    return [
      // Section 1: "Recently visited" (preceding popular)
      if (recent.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _SectionTitle(
            title: 'Recently visited',
            icon: Icons.history_rounded,
            actionText: 'See all',
            onAction: () => context.push('/history'),
          ),
        ),
        SliverList.builder(
          itemCount: recent.length,
          itemBuilder: (context, index) {
            final subreddit = recent[index];
            return M3ERecentCommunityTile(
              subreddit: subreddit,
              isFirst: index == 0,
              isLast: index == recent.length - 1,
              onTap: () => _openCommunity(subreddit),
              onFavorite: () => _toggleFavorite(subreddit),
              onMore: () => _showCommunityActions(subreddit),
            );
          },
        ),
      ],

      // Section 2: "Popular near you" horizontal carousel
      if (_filter != 'joined') ...[
        const SliverToBoxAdapter(
          child: _SectionTitle(
            title: 'Popular near you',
            icon: Icons.local_fire_department_rounded,
          ),
        ),
        if (popularAsync.isLoading && popular.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (popularAsync.hasError && popular.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorView(
                message:
                    'Could not load popular communities. Please try again.',
                onRetry: () => ref.invalidate(popularSubredditsProvider),
              ),
            ),
          )
        else if (popular.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Text('No communities match this filter.'),
            ),
          )
        else
          SliverToBoxAdapter(
            child: SizedBox(
              height:
                  190 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 4,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: popular.take(8).length,
                itemBuilder: (context, index) {
                  final subreddit = popular[index];
                  return M3EPopularCommunityCard(
                    subreddit: subreddit,
                    onTap: () => _openCommunity(subreddit),
                    onJoin: () => _toggleJoin(subreddit),
                  );
                },
              ),
            ),
          ),
      ],

      // Section 3: "All communities" list
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
              isFirst: index == 0,
              isLast: index == rest.length - 1,
              onTap: () => _openCommunity(subreddit),
              onFavorite: () => _toggleFavorite(subreddit),
              onMore: () => _showCommunityActions(subreddit),
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 130)),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    this.actionText,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 19, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (actionText != null)
            InkWell(
              onTap: onAction,
              borderRadius: ShapeTokens.small,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionText!,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
