import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/inbox_item.dart';
import '../../models/listing.dart';
import '../auth/auth_controller.dart';

class InboxState {
  const InboxState({
    required this.items,
    this.after,
    this.loadingMore = false,
  });
  final List<InboxItem> items;
  final String? after;
  final bool loadingMore;

  bool get hasMore => after != null && after!.isNotEmpty;

  InboxState copyWith({
    List<InboxItem>? items,
    String? after,
    bool? loadingMore,
  }) =>
      InboxState(
        items: items ?? this.items,
        after: after,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// arg = where (inbox | unread | messages | sent)
class InboxController extends FamilyAsyncNotifier<InboxState, String> {
  @override
  Future<InboxState> build(String arg) async {
    final listing =
        await ref.read(redditRepositoryProvider).getInbox(where: arg);
    return InboxState(items: listing.items, after: listing.after);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => build(arg));
    ref.invalidate(unreadCountProvider);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, after: current.after));
    try {
      final Listing<InboxItem> listing = await ref
          .read(redditRepositoryProvider)
          .getInbox(where: arg, after: current.after);
      state = AsyncData(current.copyWith(
        items: [...current.items, ...listing.items],
        after: listing.after,
        loadingMore: false,
      ));
    } catch (_) {
      state =
          AsyncData(current.copyWith(loadingMore: false, after: current.after));
    }
  }

  /// Optimistically marks one item read locally and on the server.
  Future<void> markRead(String fullname) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(items: [
        for (final i in current.items)
          i.fullname == fullname ? i.copyWith(isNew: false) : i,
      ]));
    }
    try {
      await ref.read(redditRepositoryProvider).markRead(fullname);
      ref.invalidate(unreadCountProvider);
    } catch (_) {/* keep optimistic state */}
  }

  /// Optimistically marks one item unread locally and on the server.
  Future<void> markUnread(String fullname) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(items: [
        for (final i in current.items)
          i.fullname == fullname ? i.copyWith(isNew: true) : i,
      ]));
    }
    try {
      await ref.read(redditRepositoryProvider).markUnread(fullname);
      ref.invalidate(unreadCountProvider);
    } catch (_) {/* keep optimistic state */}
  }

  /// Deletes a private message (t4_). Optimistically removes it from the list.
  Future<void> deleteMessage(String fullname) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
          items: [for (final i in current.items) if (i.fullname != fullname) i]));
    }
    try {
      await ref.read(redditRepositoryProvider).deleteMessage(fullname);
      ref.invalidate(unreadCountProvider);
    } catch (_) {/* keep optimistic removal */}
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
          items: [for (final i in current.items) i.copyWith(isNew: false)]));
    }
    await ref.read(redditRepositoryProvider).markAllRead();
    ref.invalidate(unreadCountProvider);
  }
}

final inboxControllerProvider =
    AsyncNotifierProviderFamily<InboxController, InboxState, String>(
        InboxController.new);

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

  @override
  int build() {
    ref.onDispose(() => _disposed = true);
    final username = ref.watch(authControllerProvider).valueOrNull?.username;
    final cached = ref
        .read(sharedPrefsProvider)
        .getInt(_cacheKey(username));
    _scheduleRefresh();
    return cached != null && cached >= 0 ? cached : 0;
  }

  String _cacheKey(String? username) => username == null || username.isEmpty
      ? kUnreadCountCachePref
      : '$kUnreadCountCachePref.$username';

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_disposed || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final count =
          await ref.read(redditRepositoryProvider).getUnreadCount();
      if (_disposed) return;
      state = AsyncData(count);
      final username = ref.read(authControllerProvider).valueOrNull?.username;
      await ref
          .read(sharedPrefsProvider)
          .setInt(_cacheKey(username), count);
    } catch (_) {
      // Keep the cached/current value visible. The next invalidation or app
      // start will schedule another refresh without blocking the UI.
    } finally {
      _refreshInFlight = false;
    }
  }
}

final unreadCountProvider =
    AsyncNotifierProvider.autoDispose<UnreadCountController, int>(
        UnreadCountController.new);
