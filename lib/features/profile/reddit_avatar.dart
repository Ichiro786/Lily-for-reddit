import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import 'profile_media.dart';

typedef AvatarIdentity = ({String name, bool community});

// Limit concurrent metadata requests when a long thread first becomes visible.
class AvatarRequestQueue {
  int _active = 0;
  final _pending = Queue<void Function()>();
  Future<T?> run<T>(Future<T> Function() request, bool Function() isCurrent) {
    final completer = Completer<T?>();
    _pending.add(() async {
      if (!isCurrent()) {
        completer.complete(null);
        _done();
        return;
      }
      try {
        completer.complete(await request());
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _done();
      }
    });
    _drain();
    return completer.future;
  }

  void _done() {
    _active--;
    _drain();
  }

  void _drain() {
    while (_active < 3 && _pending.isNotEmpty) {
      _active++;
      _pending.removeFirst()();
    }
  }
}

final avatarRequestQueueProvider = Provider((ref) => AvatarRequestQueue());

class _AvatarRequest {
  late Future<String?> result;
  int listeners = 0;
  DateTime? expires;
}

/// A small lazy-expiry cache avoids re-fetching repeated authors or leaving
/// background timers running after their rows disappear.
class AvatarMetadataCache {
  AvatarMetadataCache(this.queue);
  final AvatarRequestQueue queue;
  final _entries = <AvatarIdentity, _AvatarRequest>{};

  ({Future<String?> result, void Function() release}) acquire(
    AvatarIdentity identity,
    Future<String?> Function() request,
  ) {
    final now = DateTime.now();
    _entries.removeWhere(
      (_, entry) =>
          entry.listeners == 0 &&
          entry.expires != null &&
          !entry.expires!.isAfter(now),
    );
    // App decision: keep at most 256 inactive identities, with LRU eviction.
    while (_entries.length >= 256) {
      final removable = _entries.keys
          .where((key) => _entries[key]!.listeners == 0)
          .firstOrNull;
      if (removable == null) break;
      _entries.remove(removable);
    }
    final existing = _entries.remove(identity);
    final entry = existing ?? _AvatarRequest();
    entry.listeners++;
    _entries[identity] = entry;
    if (existing == null) {
      entry.result = queue
          .run(() async {
            try {
              final result = await request();
              entry.expires = DateTime.now().add(const Duration(minutes: 5));
              return result;
            } catch (_) {
              entry.expires = DateTime.now().add(const Duration(seconds: 30));
              return null;
            }
          }, () => entry.listeners > 0)
          .then((result) {
            if (entry.expires == null && identical(_entries[identity], entry)) {
              // It was queued for a row that disappeared before any API request.
              _entries.remove(identity);
            }
            return result;
          });
    }
    var released = false;
    return (
      result: entry.result,
      release: () {
        if (!released) {
          released = true;
          entry.listeners--;
        }
      },
    );
  }
}

final avatarMetadataCacheProvider = Provider((ref) {
  ref.watch(authSessionEpochProvider);
  ref.watch(redditRepositoryProvider);
  return AvatarMetadataCache(ref.watch(avatarRequestQueueProvider));
});

final redditAvatarUrlProvider = FutureProvider.autoDispose
    .family<String?, AvatarIdentity>((ref, identity) async {
      final cache = ref.watch(avatarMetadataCacheProvider);
      final repo = ref.watch(redditRepositoryProvider);
      final lease = cache.acquire(
        identity,
        () async => identity.community
            ? (await repo.getSubredditAbout(identity.name)).iconUrl
            : (await repo.getUserAbout(identity.name)).iconUrl,
      );
      ref.onDispose(lease.release);
      return lease.result;
    });

class RedditAvatar extends ConsumerWidget {
  const RedditAvatar({
    super.key,
    required this.name,
    this.community = false,
    this.size = 32,
  });
  final String name;
  final bool community;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalized = name.trim().toLowerCase();
    final url = normalized.isEmpty || normalized == '[deleted]'
        ? null
        : ref
              .watch(
                redditAvatarUrlProvider((
                  name: normalized,
                  community: community,
                )),
              )
              .valueOrNull;
    return ProfileAvatar(username: name, url: url, size: size);
  }
}
