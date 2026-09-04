import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/route_observer.dart';
import '../../core/startup_metrics.dart';
import '../../core/theme/shape_tokens.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/m3e_loading_indicator.dart';
import '../../core/widgets/m3e_refresh_indicator.dart';
import '../../data/reddit_repository.dart';
import '../../models/post.dart';
import '../history/history_store.dart';
import '../settings/settings_controller.dart';
import 'feed_controller.dart';
import 'post_card.dart';
import 'post_skeleton.dart';

/// Bumped to ask the frontpage feed to scroll to top (or refresh if already
/// there) — e.g. when the Posts tab is tapped while already selected.
final frontpageScrollSignalProvider = StateProvider<int>((ref) => 0);

/// Scrollable list of posts for a feed key ('' = frontpage, else subreddit).
/// [header] is rendered as the first scrolling item (e.g. a big title).
class PostListView extends ConsumerStatefulWidget {
  const PostListView({
    super.key,
    required this.feedKey,
    this.header,
    this.showSortBar = true,
  });
  final String feedKey;
  final Widget? header;
  final bool showSortBar;

  @override
  ConsumerState<PostListView> createState() => _PostListViewState();
}

class _PostListViewState extends ConsumerState<PostListView> with RouteAware {
  final _scroll = ScrollController();
  final _refreshKey = GlobalKey<M3ERefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 600) {
        ref.read(feedControllerProvider(widget.feedKey).notifier).loadMore();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  /// Returning to the feed after a pushed route (e.g. a post) is popped:
  /// pull in fresh posts if the feed has gone stale.
  @override
  void didPopNext() {
    ref.read(feedControllerProvider(widget.feedKey).notifier).refreshIfStale();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTopOrRefresh() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset > 20) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else {
      HapticFeedback.mediumImpact();
      // Drive the RefreshIndicator so the user gets a visible spinner while the
      // re-tap refresh runs (its onRefresh calls notifier.refresh()).
      _refreshKey.currentState?.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Frontpage only: respond to the "tap active tab" signal.
    if (widget.feedKey.isEmpty) {
      ref.listen<int>(frontpageScrollSignalProvider,
          (_, __) => _scrollToTopOrRefresh());
    }
    final async = ref.watch(feedControllerProvider(widget.feedKey));
    final notifier =
        ref.read(feedControllerProvider(widget.feedKey).notifier);
    final hasPending = async.valueOrNull?.hasPending ?? false;

    final refreshable = M3ERefreshIndicator(
      key: _refreshKey,
      onRefresh: notifier.refresh,
      child: async.when(
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 130),
          children: [
            if (widget.header != null) widget.header!,
            const SizedBox(height: 8),
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: PostSkeleton(),
              ),
          ],
        ),
        error: (e, _) => ListView(
          children: [
            if (widget.header != null) widget.header!,
            SizedBox(
              height: 360,
              child: ErrorView(message: e, onRetry: notifier.refresh),
            ),
          ],
        ),
        data: (state) {
          final forYouFeed =
              ref.watch(settingsControllerProvider.select((s) => s.forYouFeed));
          final autoHideReadForYou = ref.watch(
              settingsControllerProvider.select((s) => s.autoHideReadForYou));
          var posts = state.posts;
          // Auto-hide already-read items in the For You feed (live: rebuilds
          // when history changes).
          if (autoHideReadForYou) {
            ref.watch(historyControllerProvider);
            final history = ref.read(historyControllerProvider.notifier);
            posts = posts
                .where((p) =>
                    !(p.feedReason != null && history.containsId(p.id)))
                .toList();
          }
          if (posts.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 130),
              children: [
                if (widget.header != null) widget.header!,
                if (widget.showSortBar)
                  _SortBar(
                    sort: state.sort,
                    time: state.time,
                    onPick: notifier.changeSort,
                    forYou: forYouFeed && widget.feedKey.isEmpty,
                    onForYou: widget.feedKey.isEmpty
                        ? notifier.selectForYou
                        : null,
                  ),
                _EmptyFeed(onRefresh: notifier.refresh),
              ],
            );
          }
          final itemCount =
              (widget.showSortBar ? 1 : 0) + posts.length + 1;
          final bottomPadding =
              88.0 + MediaQuery.paddingOf(context).bottom;
          return ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(10, 0, 10, bottomPadding),
            itemCount: (widget.header != null ? 1 : 0) + itemCount,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            itemBuilder: (context, rawIndex) {
              var index = rawIndex;
              if (widget.header != null) {
                if (index == 0) return widget.header!;
                index -= 1;
              }
              if (widget.showSortBar) {
                if (index == 0) {
                  return _SortBar(
                    sort: state.sort,
                    time: state.time,
                    onPick: notifier.changeSort,
                    forYou: forYouFeed && widget.feedKey.isEmpty,
                    onForYou: widget.feedKey.isEmpty
                        ? notifier.selectForYou
                        : null,
                  );
                }
                index -= 1;
              }
              if (index < posts.length) {
                final post = posts[index];
                if (widget.feedKey.isEmpty && index == 0) {
                  return RepaintBoundary(
                    child: _StartupFirstPostVisibility(post: post),
                  );
                }
                return RepaintBoundary(
                  key: ValueKey<String>('post-card-${post.id}'),
                  child: PostCard(post: post),
                );
              }
              // footer
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: state.loadingMore
                      ? const M3ELoadingIndicator.small()
                      : state.hasMore
                          ? const SizedBox.shrink()
                          : Text('— end —',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                ),
              );
            },
          );
        },
      ),
    );

    return Stack(
      children: [
        refreshable,
        if (hasPending)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: _NewPostsPill(
                onTap: () {
                  notifier.applyPending();
                  if (_scroll.hasClients) {
                    _scroll.animateTo(0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOut);
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 42, color: cs.primary),
          const SizedBox(height: 14),
          Text(
            'No posts yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull to refresh or try another feed sort.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _StartupFirstPostVisibility extends StatelessWidget {
  const _StartupFirstPostVisibility({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey<String>('startup-first-post-${post.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0) {
          StartupMetrics.instance.markFirstFeedItemVisible();
        }
      },
      child: PostCard(post: post),
    );
  }
}

/// Tappable pill shown when a fresh page is staged after returning to a
/// stale feed — applies it and scrolls to top.
class _NewPostsPill extends StatelessWidget {
  const _NewPostsPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      elevation: 3,
      borderRadius: ShapeTokens.full,
      child: InkWell(
        borderRadius: ShapeTokens.full,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_upward_rounded, size: 16, color: cs.onPrimary),
              const SizedBox(width: 6),
              Text('New posts',
                  style: TextStyle(
                      color: cs.onPrimary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sort,
    required this.time,
    required this.onPick,
    this.forYou = false,
    this.onForYou,
  });

  final PostSort sort;
  final TopTime time;
  final void Function(PostSort, {TopTime? time}) onPick;
  final bool forYou;
  final VoidCallback? onForYou;

  static const _frontpageSorts = <PostSort>[
    PostSort.hot,
    PostSort.newest,
    PostSort.rising,
    PostSort.top,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            if (onForYou != null) ...[
              _chip(
                context,
                label: 'For You',
                icon: Icons.auto_awesome_rounded,
                selected: forYou,
                onPressed: onForYou!,
              ),
              const SizedBox(width: 8),
            ],
            for (var i = 0; i < _frontpageSorts.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _chip(
                context,
                label: _frontpageSorts[i].label,
                icon: _iconFor(_frontpageSorts[i]),
                selected: !forYou && sort == _frontpageSorts[i],
                onPressed: () => onPick(
                  _frontpageSorts[i],
                  time: _frontpageSorts[i] == PostSort.top ? time : null,
                ),
              ),
            ],
            if (sort == PostSort.best && !forYou) ...[
              const SizedBox(width: 8),
              _chip(
                context,
                label: 'Best',
                icon: Icons.star_rounded,
                selected: true,
                onPressed: () => onPick(PostSort.best),
              ),
            ],
            if (sort == PostSort.top && !forYou) ...[
              const SizedBox(width: 8),
              ActionChip(
                avatar: Icon(Icons.schedule_rounded, size: 16, color: cs.primary),
                label: Text(time.label),
                labelStyle: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _showTimeSheet(context);
                },
                backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 0.65),
                side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25)),
                shape: const StadiumBorder(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected,
      showCheckmark: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onPressed();
      },
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: selected ? cs.onSecondaryContainer : cs.onSurface,
      ),
      selectedColor: cs.secondaryContainer,
      backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 0.65),
      checkmarkColor: cs.onSecondaryContainer,
      side: BorderSide(
        color: selected
            ? cs.secondaryContainer.withValues(alpha: 0.5)
            : cs.outlineVariant.withValues(alpha: 0.25),
        width: 1,
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    );
  }

  void _showTimeSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Top posts from',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                  ),
                ],
              ),
            ),
            for (final t in TopTime.values)
              ListTile(
                title: Text(
                  t.label,
                  style: TextStyle(
                    fontWeight: t == time ? FontWeight.w700 : FontWeight.w500,
                    color: t == time ? cs.primary : cs.onSurface,
                  ),
                ),
                trailing: t == time
                    ? Icon(Icons.check_rounded, color: cs.primary)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(ctx);
                  onPick(PostSort.top, time: t);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(PostSort s) => switch (s) {
        PostSort.best => Icons.star_rounded,
        PostSort.hot => Icons.local_fire_department_rounded,
        PostSort.newest => Icons.schedule_rounded,
        PostSort.top => Icons.leaderboard_rounded,
        PostSort.rising => Icons.trending_up_rounded,
      };
}
