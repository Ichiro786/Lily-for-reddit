import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/root_messenger.dart';
import '../../data/reddit_repository.dart';
import '../../models/inbox_item.dart';
import '../../models/listing.dart';
import '../auth/auth_controller.dart';
import '../settings/settings_controller.dart';

const _keepCursor = Object();

final inboxFailureProvider = Provider<void Function(String)>(
  (ref) =>
      (message) => showRootSnackBar(SnackBar(content: Text(message))),
);

class InboxState {
  const InboxState({required this.items, this.after, this.loadingMore = false});
  final List<InboxItem> items;
  final String? after;
  final bool loadingMore;

  bool get hasMore => after != null && after!.isNotEmpty;

  InboxState copyWith({
    List<InboxItem>? items,
    Object? after = _keepCursor,
    bool? loadingMore,
  }) => InboxState(
    items: items ?? this.items,
    after: identical(after, _keepCursor) ? this.after : after as String?,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// arg = where (inbox | unread | messages | sent)
class InboxController extends FamilyAsyncNotifier<InboxState, String> {
  int _generation = 0;
  bool _disposed = false;
  Future<void> _mutations = Future.value();
  bool _current(int generation) => !_disposed && generation == _generation;

  @override
  Future<InboxState> build(String arg) async {
    ref.watch(authSessionEpochProvider);
    final repo = ref.watch(redditRepositoryProvider);
    _disposed = false;
    ++_generation;
    _mutations = Future.value();
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    final listing = await repo.getInbox(where: arg);
    return InboxState(items: listing.items, after: listing.after);
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final repo = ref.read(redditRepositoryProvider);
    final next = await AsyncValue.guard(() async {
      final listing = await repo.getInbox(where: arg);
      return InboxState(items: listing.items, after: listing.after);
    });
    if (_current(generation)) {
      state = next;
      ref.invalidate(unreadCountProvider);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final generation = _generation;
    state = AsyncData(
      current.copyWith(loadingMore: true, after: current.after),
    );
    try {
      final Listing<InboxItem> listing = await ref
          .read(redditRepositoryProvider)
          .getInbox(where: arg, after: current.after);
      if (!_current(generation)) return;
      final latest = state.valueOrNull;
      if (latest == null) return;
      final ids = {for (final item in latest.items) item.fullname};
      state = AsyncData(
        latest.copyWith(
          items: [
            ...latest.items,
            ...listing.items.where((item) => ids.add(item.fullname)),
          ],
          after: listing.after,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!_current(generation)) return;
      final latest = state.valueOrNull;
      if (latest == null) return;
      state = AsyncData(latest.copyWith(loadingMore: false));
    }
  }

  /// Optimistically marks one item read locally and on the server.
  Future<void> markRead(String fullname) => _setRead(fullname, false);

  /// Optimistically marks one item unread locally and on the server.
  Future<void> markUnread(String fullname) => _setRead(fullname, true);

  Future<void> _setRead(String id, bool unread) => _mutate(
    (s) => s.copyWith(
      items: [
        for (final i in s.items)
          i.fullname == id ? i.copyWith(isNew: unread) : i,
      ],
    ),
    (repo) => unread ? repo.markUnread(id) : repo.markRead(id),
  );

  /// Deletes a private message (t4_). Optimistically removes it from the list.
  Future<void> deleteMessage(String fullname) => _mutate(
    (s) => s.copyWith(
      items: [
        for (final i in s.items)
          if (i.fullname != fullname) i,
      ],
    ),
    (repo) => repo.deleteMessage(fullname),
  );

  Future<void> markAllRead() => _mutate(
    (s) =>
        s.copyWith(items: [for (final i in s.items) i.copyWith(isNew: false)]),
    (repo) => repo.markAllRead(),
  );

  Future<void> _mutate(
    InboxState Function(InboxState) present,
    Future<void> Function(RedditRepository) request,
  ) {
    if (_disposed || ref.read(authTransitionProvider)) return Future.value();
    final generation = _generation;
    final repo = ref.read(redditRepositoryProvider);
    final operation = _mutations.then((_) async {
      if (!_current(generation) || ref.read(authTransitionProvider)) return;
      final before = state.valueOrNull;
      if (before == null) return;
      final optimistic = present(before);
      final optimisticById = {for (final i in optimistic.items) i.fullname: i};
      final touched = {
        for (final i in before.items)
          if (!identical(i, optimisticById[i.fullname])) i.fullname,
      };
      state = AsyncData(optimistic);
      try {
        await request(repo);
        if (_current(generation)) ref.invalidate(unreadCountProvider);
      } catch (_) {
        if (!_current(generation)) return;
        final latest = state.valueOrNull;
        if (latest == null) return;
        final originals = {for (final i in before.items) i.fullname: i};
        final items = [
          for (final i in latest.items)
            touched.contains(i.fullname) ? originals[i.fullname]! : i,
        ];
        final ids = {for (final i in items) i.fullname};
        for (var index = 0; index < before.items.length; index++) {
          final i = before.items[index];
          if (touched.contains(i.fullname) && ids.add(i.fullname)) {
            items.insert(index.clamp(0, items.length), i);
          }
        }
        state = AsyncData(latest.copyWith(items: items));
        ref.read(inboxFailureProvider)(
          'Inbox change failed. Please try again.',
        );
      }
    });
    _mutations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return _mutations;
  }
}

final inboxControllerProvider =
    AsyncNotifierProviderFamily<InboxController, InboxState, String>(
      InboxController.new,
    );

/// SharedPreferences key for the last known unread badge value.
const String kUnreadCountCachePref = 'unreadCountCache';

/// Unread badge value with stale-while-refresh behavior.
///
/// The cached value (or zero when there is no cache) is returned immediately.
/// A fresh `/message/unread` request is scheduled after the first frame, so the
/// initial Posts route never waits for the badge network request.
class UnreadCountController extends AutoDisposeAsyncNotifier<int> {
  bool _refreshScheduled = false;
  bool _refreshInFlight = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  int build() {
    ref.watch(authSessionEpochProvider);
    ref.watch(redditRepositoryProvider);
    ref.watch(authTransitionProvider);
    _disposed = false;
    _generation++;
    _refreshScheduled = false;
    _refreshInFlight = false;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    final username = ref.watch(
      authControllerProvider.select((auth) => auth.valueOrNull?.username),
    );
    final cached = ref.read(sharedPrefsProvider).getInt(_cacheKey(username));
    _scheduleRefresh();
    return cached != null && cached >= 0 ? cached : 0;
  }

  String _cacheKey(String? username) => username == null || username.isEmpty
      ? kUnreadCountCachePref
      : '$kUnreadCountCachePref.$username';

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || generation != _generation) return;
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_disposed || _refreshInFlight || ref.read(authTransitionProvider)) {
      return;
    }
    final generation = _generation;
    final username = ref.read(authControllerProvider).valueOrNull?.username;
    _refreshInFlight = true;
    try {
      final count = await ref.read(redditRepositoryProvider).getUnreadCount();
      if (_disposed || generation != _generation) return;
      state = AsyncData(count);
      await ref.read(sharedPrefsProvider).setInt(_cacheKey(username), count);
    } catch (_) {
      // Keep the cached/current value visible. The next invalidation or app
      // start will schedule another refresh without blocking the UI.
    } finally {
      if (generation == _generation) _refreshInFlight = false;
    }
  }
}

final unreadCountProvider =
    AsyncNotifierProvider.autoDispose<UnreadCountController, int>(
      UnreadCountController.new,
    );
