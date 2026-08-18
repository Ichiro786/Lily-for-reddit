import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/share.dart';
import '../../models/subreddit.dart';
import '../feed/feed_controller.dart';
import '../feed/post_list_view.dart';
import '../settings/settings_controller.dart';
import 'subreddit_header.dart';

final subredditAboutProvider =
    FutureProvider.autoDispose.family<Subreddit, String>((ref, name) {
  return ref.watch(redditRepositoryProvider).getSubredditAbout(name);
});

class SubredditScreen extends ConsumerStatefulWidget {
  const SubredditScreen({super.key, required this.name});

  final String name;

  @override
  ConsumerState<SubredditScreen> createState() => _SubredditScreenState();
}

class _SubredditScreenState extends ConsumerState<SubredditScreen> {
  bool? _subOverride;
  bool _notificationsEnabled = false;

  @override
  Widget build(BuildContext context) {
    final about = ref.watch(subredditAboutProvider(widget.name));
    final feed = ref.watch(feedControllerProvider(widget.name));
    final defaultSort =
        ref.watch(settingsControllerProvider.select((s) => s.defaultSort));
    final display =
        ref.watch(settingsControllerProvider.select((s) => s.postDisplay));
    final selectedSort = feed.valueOrNull?.sort ?? defaultSort;

    return Scaffold(
      appBar: AppBar(
        title: Text('r/${widget.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search?sr=${widget.name}'),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () =>
                shareUrl(context, 'https://reddit.com/r/${widget.name}'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/submit?sr=${widget.name}'),
        child: const Icon(Icons.edit_rounded),
      ),
      body: PostListView(
        feedKey: widget.name,
        showSortBar: false,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            about.when(
              loading: () => const SizedBox(
                height: 4,
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (s) => _header(context, s),
            ),
            M3ESubredditControlBar(
              sort: selectedSort,
              onSortChanged: (sort) => ref
                  .read(feedControllerProvider(widget.name).notifier)
                  .changeSort(sort),
              display: display,
              onDisplayChanged: (next) => ref
                  .read(settingsControllerProvider.notifier)
                  .setPostDisplay(next),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Subreddit s) {
    final subscribed = _subOverride ?? s.userIsSubscriber ?? false;
    return M3ESubredditHeader(
      subreddit: s,
      joined: subscribed,
      onJoinToggle: () => _toggleSub(s, subscribed),
      notificationsEnabled: _notificationsEnabled,
      onNotificationToggle: () {
        setState(() => _notificationsEnabled = !_notificationsEnabled);
      },
      accessLabel: s.over18 ? '18+ public' : 'Public',
      categoryLabel: s.title.isEmpty ? 'Community' : s.title,
    );
  }

  Future<void> _toggleSub(Subreddit s, bool currentlySubscribed) async {
    final next = !currentlySubscribed;
    setState(() => _subOverride = next);
    try {
      await ref.read(redditRepositoryProvider).setSubscribed(s.name, next);
    } catch (_) {
      if (mounted) setState(() => _subOverride = currentlySubscribed);
    }
  }
}
