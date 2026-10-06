import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reddit_repository.dart';
import '../history/interest_store.dart';
import '../settings/settings_controller.dart';

const feedResumeMaxAge = Duration(minutes: 10);
const feedResumeMaxPages = 20;

class FeedBookmark {
  const FeedBookmark({
    required this.sort,
    required this.time,
    required this.offset,
    required this.ids,
    required this.pages,
    required this.savedAt,
  });
  final PostSort sort;
  final TopTime time;
  final double offset;
  final List<String> ids;
  final int pages;
  final DateTime savedAt;

  bool get isRecent {
    final age = DateTime.now().difference(savedAt);
    return !age.isNegative && age <= feedResumeMaxAge;
  }

  Map<String, Object> toJson() => {
    'sort': sort.index,
    'time': time.index,
    'offset': offset,
    'ids': ids,
    'pages': pages,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  factory FeedBookmark.fromJson(Map<String, dynamic> json) {
    final offset = (json['offset'] as num).toDouble();
    if (!offset.isFinite || offset < 0) {
      throw const FormatException('Invalid feed offset');
    }
    return FeedBookmark(
      sort: PostSort.values[json['sort'] as int],
      time: TopTime.values[json['time'] as int],
      offset: offset,
      ids: (json['ids'] as List)
          .map((id) => id as String)
          .toList(growable: false),
      pages: (json['pages'] as int).clamp(1, feedResumeMaxPages),
      savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int),
    );
  }
}

class FeedResumeState {
  const FeedResumeState({this.lastFeed = '', this.feeds = const {}});
  final String lastFeed;
  final Map<String, FeedBookmark> feeds;
}

/// Small account-scoped bookmarks, rather than copies of post/vote data. A
/// resumed feed is re-fetched in Reddit order, and its position is used only
/// when the IDs still match. Long returns and explicit refresh start at zero.
class FeedResumeStore extends Notifier<FeedResumeState> {
  Future<void>? _pendingWrite;
  late Future<void> Function(FeedResumeState) _persist;

  @override
  FeedResumeState build() {
    final key = userScopedPrefsKey(ref, 'feed_resume');
    final prefs = ref.read(sharedPrefsProvider);
    // Saves happen at scroll end or lifecycle boundaries, not every frame.
    // Capture the account key and preferences so in-flight writes remain safe
    // after provider disposal/account changes, and leave no background timers.
    _persist = (snapshot) async {
      await prefs.setString(
        key,
        jsonEncode({
          'lastFeed': snapshot.lastFeed,
          'feeds': {
            for (final entry in snapshot.feeds.entries)
              entry.key: entry.value.toJson(),
          },
        }),
      );
    };
    try {
      final raw =
          jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
      final feeds = <String, FeedBookmark>{};
      for (final entry in (raw['feeds'] as Map? ?? {}).entries) {
        try {
          feeds[entry.key as String] = FeedBookmark.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (_) {
          /* A corrupt bookmark must not prevent feed loading. */
        }
      }
      return FeedResumeState(
        lastFeed: raw['lastFeed'] as String? ?? '',
        feeds: feeds,
      );
    } catch (_) {
      return const FeedResumeState();
    }
  }

  void save(String feed, FeedBookmark bookmark, {bool active = true}) {
    // Eight recent destinations bound disk use; exceptionally long sessions
    // keep their sort but intentionally resume at the top.
    final feeds = {...state.feeds}..remove(feed);
    feeds[feed] = bookmark;
    while (feeds.length > 8) {
      feeds.remove(feeds.keys.first);
    }
    state = FeedResumeState(
      lastFeed: active ? feed : state.lastFeed,
      feeds: feeds,
    );
    _pendingWrite = _persist(state);
  }

  Future<void> flush() async => _pendingWrite;
}

final feedResumeStoreProvider =
    NotifierProvider<FeedResumeStore, FeedResumeState>(FeedResumeStore.new);
