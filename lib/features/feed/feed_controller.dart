import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/interaction_vault.dart';
import '../../data/reddit_repository.dart';
import '../../models/listing.dart';
import '../../models/post.dart';
import '../history/history_store.dart';
import '../history/interest_store.dart';
import '../settings/settings_controller.dart';
import 'feed_ranker.dart';
import 'feed_resume_store.dart';

const _keepCursor = Object();

class FeedState {
  const FeedState({
    required this.posts,
    required this.sort,
    required this.time,
    this.after,
    this.loadingMore = false,
    this.hasPending = false,
    this.pagesLoaded = 1,
    this.initialScrollOffset = 0,
    this.positionRevision = 0,
  });

  final List<Post> posts;
  final PostSort sort;
  final TopTime time;
  final String? after;
  final bool loadingMore;
  final bool hasPending; // a fresh page is staged behind a "New posts" pill

  final int pagesLoaded;
  final double initialScrollOffset;
  final int positionRevision;

  bool get hasMore => after != null && after!.isNotEmpty;

  FeedState copyWith({
    List<Post>? posts,
    PostSort? sort,
    TopTime? time,
    Object? after = _keepCursor,
    bool? loadingMore,
    bool? hasPending,
    int? pagesLoaded,
    double? initialScrollOffset,
    int? positionRevision,
  }) => FeedState(
    posts: posts ?? this.posts,
    sort: sort ?? this.sort,
    time: time ?? this.time,
    after: identical(after, _keepCursor) ? this.after : after as String?,
    loadingMore: loadingMore ?? this.loadingMore,
    hasPending: hasPending ?? this.hasPending,
    pagesLoaded: pagesLoaded ?? this.pagesLoaded,
    initialScrollOffset: initialScrollOffset ?? this.initialScrollOffset,
    positionRevision: positionRevision ?? this.positionRevision,
  );
}

/// Feed for the frontpage (key == '') or a subreddit (key == name).
class FeedController extends FamilyAsyncNotifier<FeedState, String> {
  String? get _subreddit => arg.isEmpty ? null : arg;
  RedditRepository get _repo => ref.read(redditRepositoryProvider);

  PostSort? _sort;
  TopTime _time = TopTime.day;
  bool _initialized = false;
  DateTime _lastLoaded = DateTime.fromMillisecondsSinceEpoch(0);

  /// A multireddit feed key looks like `m::username::multiname`.
  ({String username, String name})? get _multi {
    if (!arg.startsWith('m::')) return null;
    final parts = arg.split('::');
    if (parts.length != 3) return null;
    return (username: parts[1], name: parts[2]);
  }

  bool get _isFrontpage => arg.isEmpty;
  bool get _forYou =>
      _isFrontpage && ref.read(settingsControllerProvider).forYouFeed;

  bool _enrichmentInFlight = false;
  bool _disposed = false;
  int _positionRevision = 0;
  bool _quietRefreshInFlight = false;
  int _generation = 0;

  bool _current(int generation) => !_disposed && generation == _generation;

  int _beginRequest() {
    _disposed = false;
    _pending = null;
    _pendingAfter = null;
    _enrichmentInFlight = false;
    _quietRefreshInFlight = false;
    _pendingPages = 1;
    return ++_generation;
  }

  void _check(int generation) {
    if (!_current(generation)) {
      throw DioException(
        requestOptions: RequestOptions(path: 'feed'),
        type: DioExceptionType.cancel,
      );
    }
  }

  Future<Listing<Post>> _fetch({
    String? after,
    bool fast = false,
    Listing<Post>? bestSeed,
  }) {
    if (_forYou) {
      final history = ref.read(historyControllerProvider);
      final vault = ref.read(interactionVaultProvider);
      final kw = ref.read(keywordStoreProvider.notifier);
      return _repo.getForYouFeed(
        interest: ref.read(interestStoreProvider),
        muted: ref.read(mutedSubsProvider),
        seen: {for (final e in history) e.id, ...vault.seenPosts.keys},
        impressions: ref.read(impressionStoreProvider),
        titleScore: kw.scoreTitle,
        titleKeyword: kw.topKeywordIn,
        cursors: after, // null = first page; else the encoded cursor bundle
        fast: fast,
        bestSeed: bestSeed,
        excludeIds: after == null
            ? const {}
            : {
                for (final p in state.valueOrNull?.posts ?? const <Post>[])
                  p.id,
              },
      );
    }
    final multi = _multi;
    if (multi != null) {
      return _repo.getMultiPosts(
        username: multi.username,
        multiname: multi.name,
        sort: _sort!,
        time: _time,
        after: after,
      );
    }
    return _repo.getPosts(
      subreddit: _subreddit,
      sort: _sort!,
      time: _time,
      after: after,
    );
  }

  Future<Listing<Post>> _fetchWithRetry({
    String? after,
    bool fast = false,
    Listing<Post>? bestSeed,
  }) async {
    final generation = _generation;
    try {
      return await _fetch(after: after, fast: fast, bestSeed: bestSeed);
    } on DioException catch (error) {
      if (!_isRetryableTransport(error)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _check(generation);
      return _fetch(after: after, fast: fast, bestSeed: bestSeed);
    }
  }

  bool _isRetryableTransport(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    _ => false,
  };

  Set<String> get _readIds => {
    for (final entry in ref.read(historyControllerProvider)) entry.id,
    ...ref.read(interactionVaultProvider).seenPosts.keys,
  };

  bool get _shouldFilterViewedForYou =>
      ref.read(settingsControllerProvider).hideReadPosts;

  Future<List<Post>> _rankForYouPosts(Iterable<Post> posts) {
    final history = ref.read(historyControllerProvider);
    final vault = ref.read(interactionVaultProvider);
    return FeedRanker.rank(
      posts,
      now: DateTime.now(),
      affinityBySubreddit: ref.read(interestStoreProvider),
      viewedIds: {
        for (final entry in history) entry.id,
        ...vault.seenPosts.keys,
      },
      interactionsByPostId: vault.interactedPosts,
      filterViewed: _shouldFilterViewedForYou,
      filterInteracted: true,
    );
  }

  List<Post> _filterReadPosts(List<Post> posts) {
    if (!ref.read(settingsControllerProvider).hideReadPosts) return posts;
    final read = _readIds;
    return [
      for (final post in posts)
        if (!read.contains(post.id)) post,
    ];
  }

  /// Skip fully filtered/duplicate pages without changing Reddit's ordering.
  /// Bound each operation, reject repeated cursors, and leave a usable cursor
  /// for "Keep looking" when ten pages contain no unread posts.
  Future<({Listing<Post> listing, Listing<Post> seed, int pages})> _visiblePage(
    int generation, {
    String? after,
    bool fast = false,
    Listing<Post>? bestSeed,
    Set<String> exclude = const {},
  }) async {
    var cursor = after;
    final visited = <String?>{after};
    Listing<Post>? seed;
    for (var page = 1; ; page++) {
      final raw = await _fetchWithRetry(
        after: cursor,
        fast: fast,
        bestSeed: bestSeed,
      );
      _check(generation);
      seed ??= raw;
      final prepared = _forYou
          ? await _rankForYouPosts(raw.items)
          : _filterReadPosts(raw.items);
      _check(generation);
      final ids = {...exclude};
      final posts = prepared.where((post) => ids.add(post.id)).toList();
      final next = raw.hasMore && visited.add(raw.after) ? raw.after : null;
      if (posts.isNotEmpty || next == null || page >= 10) {
        return (
          listing: Listing(items: posts, after: next),
          seed: seed,
          pages: page,
        );
      }
      cursor = next;
    }
  }

  void savePosition(double offset, {bool active = true}) {
    final current = state.valueOrNull;
    if (state.isLoading ||
        current == null ||
        !ref.read(settingsControllerProvider).resumeFeeds) {
      return;
    }
    final bounded = current.pagesLoaded <= feedResumeMaxPages;
    ref
        .read(feedResumeStoreProvider.notifier)
        .save(
          arg,
          FeedBookmark(
            sort: current.sort,
            time: current.time,
            offset: bounded && offset.isFinite
                ? offset.clamp(0, double.maxFinite)
                : 0,
            ids: bounded
                ? [for (final post in current.posts) post.id]
                : const [],
            pages: bounded ? current.pagesLoaded : 1,
            savedAt: DateTime.now(),
          ),
          active: active,
        );
  }

  @override
  Future<FeedState> build(String arg) async {
    ref.watch(redditRepositoryProvider);
    ref.watch(settingsControllerProvider.select((s) => s.hideReadPosts));
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    final generation = _beginRequest();
    if (!_initialized) {
      _sort = ref.read(settingsControllerProvider).defaultSort;
      _initialized = true;
    }
    final bookmark = ref.read(settingsControllerProvider).resumeFeeds
        ? ref.read(feedResumeStoreProvider).feeds[arg]
        : null;
    if (bookmark != null) {
      _sort = bookmark.sort;
      _time = bookmark.time;
    }
    return _loadInitial(generation, bookmark: bookmark);
  }

  Future<FeedState> _loadInitial(
    int generation, {
    FeedBookmark? bookmark,
  }) async {
    final resume = bookmark != null && bookmark.isRecent && bookmark.offset > 0;
    final first = await _visiblePage(generation, fast: _forYou && !resume);
    _check(generation);
    var posts = first.listing.items;
    var after = first.listing.after;
    var pages = first.pages;
    final prefixMatches =
        resume &&
        bookmark.ids.isNotEmpty &&
        posts.isNotEmpty &&
        posts
            .asMap()
            .entries
            .take(bookmark.ids.length)
            .every((entry) => entry.value.id == bookmark.ids[entry.key]);
    if (prefixMatches) {
      final visited = <String?>{after};
      while (pages < bookmark.pages && after != null) {
        final next = await _visiblePage(
          generation,
          after: after,
          exclude: {for (final post in posts) post.id},
        );
        _check(generation);
        posts = [...posts, ...next.listing.items];
        after = next.listing.after;
        pages += next.pages;
        if (!visited.add(after)) {
          after = null;
          break;
        }
      }
    }
    final matches =
        resume &&
        bookmark.ids.isNotEmpty &&
        posts.length >= bookmark.ids.length &&
        bookmark.ids.asMap().entries.every(
          (entry) => posts[entry.key].id == entry.value,
        );
    _lastLoaded = DateTime.now();
    final nextState = FeedState(
      posts: posts,
      sort: _sort!,
      time: _time,
      after: after,
      pagesLoaded: pages,
      initialScrollOffset: matches ? bookmark.offset : 0,
      positionRevision: _positionRevision,
    );
    if (_forYou && !resume) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_current(generation)) {
          unawaited(_enrichForYou(nextState, first.seed, generation));
        }
      });
    }
    return nextState;
  }

  Future<void> _reload({bool loading = false}) async {
    final generation = _beginRequest();
    if (loading) state = const AsyncLoading();
    final next = await AsyncValue.guard(() => _loadInitial(generation));
    if (_current(generation)) state = next;
  }

  Future<void> changeSort(PostSort sort, {TopTime? time}) async {
    _positionRevision++;
    _sort = sort;
    if (time != null) _time = time;
    // Persist the frontpage sort + turn off the For You feed.
    if (_isFrontpage) {
      final s = ref.read(settingsControllerProvider.notifier);
      s.setDefaultSort(sort);
      s.setForYouFeed(false);
    }
    await _reload(loading: true);
    if (!_disposed) savePosition(0);
  }

  /// Switches the frontpage to the "For You (Beta)" feed (persisted).
  Future<void> selectForYou() async {
    _positionRevision++;
    ref.read(settingsControllerProvider.notifier).setForYouFeed(true);
    await _reload(loading: true);
    if (!_disposed) savePosition(0);
  }

  Future<void> refresh() async {
    _positionRevision++;
    await _reload();
    if (!_disposed) savePosition(0);
  }

  Future<void> _enrichForYou(
    FeedState preview,
    Listing<Post> bestSeed,
    int generation,
  ) async {
    if (!_current(generation) || _enrichmentInFlight || !_forYou) return;
    _enrichmentInFlight = true;
    try {
      final listing = await _fetchWithRetry(bestSeed: bestSeed);
      if (!_current(generation) || !_forYou || state.valueOrNull != preview) {
        return;
      }
      final current = state.valueOrNull;
      if (current == null || listing.items.isEmpty) return;
      final rankedItems = await _rankForYouPosts(listing.items);
      if (!_current(generation) || state.valueOrNull != preview) return;
      final currentIds = {for (final p in current.posts) p.id};
      final changed =
          rankedItems.length != current.posts.length ||
          rankedItems.asMap().entries.any(
            (e) => e.value.id != current.posts[e.key].id,
          );
      final readIds = _readIds;
      final hasNew = rankedItems.any(
        (p) => !currentIds.contains(p.id) && !readIds.contains(p.id),
      );
      if (changed && hasNew) {
        _pending = rankedItems;
        _pendingAfter = listing.after;
        state = AsyncData(
          current.copyWith(hasPending: true, after: current.after),
        );
      } else if (listing.after != current.after) {
        // Keep the visible preview stable while adopting the full cursor bundle.
        state = AsyncData(current.copyWith(after: listing.after));
      }
    } catch (_) {
      // The preview remains usable when enrichment is unavailable.
    } finally {
      if (_current(generation)) _enrichmentInFlight = false;
    }
  }

  // A freshly-fetched first page staged behind the "New posts" pill.
  List<Post>? _pending;
  String? _pendingAfter;
  int _pendingPages = 1;

  /// When returning to a stale feed, quietly fetch the first page. If it has
  /// posts we're not already showing, stage them behind a "New posts" pill
  /// instead of yanking the list out from under the user.
  Future<void> refreshIfStale([
    Duration maxAge = const Duration(minutes: 5),
  ]) async {
    if (state.isLoading) return;
    final cur = state.valueOrNull;
    if (cur == null) return;
    if (cur.hasPending ||
        cur.loadingMore ||
        _enrichmentInFlight ||
        _quietRefreshInFlight) {
      return;
    }
    if (DateTime.now().difference(_lastLoaded) < maxAge) return;
    final generation = _generation;
    _quietRefreshInFlight = true;
    try {
      final page = await _visiblePage(generation);
      final listing = page.listing;
      if (!_current(generation) || state.valueOrNull != cur) return;
      _lastLoaded = DateTime.now();
      final pending = listing.items;
      if (!_current(generation) || state.valueOrNull != cur) return;
      final currentIds = {for (final p in cur.posts) p.id};
      final readIds = _readIds;
      final hasNew = pending.any(
        (p) => !currentIds.contains(p.id) && !readIds.contains(p.id),
      );
      if (hasNew) {
        _pending = pending;
        _pendingAfter = listing.after;
        _pendingPages = page.pages;
        state = AsyncData(cur.copyWith(hasPending: true, after: cur.after));
      }
    } catch (_) {
      /* leave the current feed in place */
    } finally {
      if (_current(generation)) _quietRefreshInFlight = false;
    }
  }

  /// Swaps the staged "New posts" page in (called when the pill is tapped).
  bool applyPending() {
    final cur = state.valueOrNull;
    if (cur == null || _pending == null) return false;
    final posts = _filterReadPosts(_pending!);
    final ids = {for (final post in cur.posts) post.id};
    final read = _readIds;
    final hasNew = posts.any(
      (post) => !ids.contains(post.id) && !read.contains(post.id),
    );
    _generation++;
    _enrichmentInFlight = false;
    _quietRefreshInFlight = false;
    state = AsyncData(
      hasNew
          ? cur.copyWith(
              posts: posts,
              after: _pendingAfter,
              hasPending: false,
              pagesLoaded: _pendingPages,
              initialScrollOffset: 0,
              positionRevision: ++_positionRevision,
            )
          : cur.copyWith(hasPending: false),
    );
    _pending = null;
    _pendingAfter = null;
    if (hasNew) savePosition(0);
    return hasNew;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        current.hasPending ||
        _enrichmentInFlight) {
      return;
    }
    state = AsyncData(
      current.copyWith(loadingMore: true, after: current.after),
    );
    final generation = _generation;
    try {
      final page = await _visiblePage(
        generation,
        after: current.after,
        exclude: {for (final post in current.posts) post.id},
      );
      final listing = page.listing;
      if (!_current(generation)) return;
      final nextItems = listing.items;
      if (!_current(generation)) return;
      final latest = state.valueOrNull;
      if (latest == null) return;
      final ids = {for (final p in latest.posts) p.id};
      state = AsyncData(
        latest.copyWith(
          posts: [...latest.posts, ...nextItems.where((p) => ids.add(p.id))],
          after: listing.after,
          pagesLoaded: latest.pagesLoaded + page.pages,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!_current(generation)) return;
      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData(
          latest.copyWith(loadingMore: false, after: latest.after),
        );
      }
    }
  }
}

final feedControllerProvider =
    AsyncNotifierProviderFamily<FeedController, FeedState, String>(
      FeedController.new,
    );
