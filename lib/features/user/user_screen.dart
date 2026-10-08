import 'package:flutter/material.dart';

import '../../core/widgets/m3e_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deep_links.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets/error_view.dart';
import '../../core/share.dart';
import '../../core/theme/shape_tokens.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../auth/auth_controller.dart';
import '../feed/paged_list.dart';
import '../feed/post_card.dart';
import '../post/post_actions.dart';
import '../profile/profile_header.dart';
import '../profile/profile_hero.dart';
import '../profile/profile_tabs.dart';
import '../profile/profile_providers.dart';
import '../multireddit/custom_feeds_sheet.dart';

export '../profile/profile_providers.dart' show userAboutProvider;

class UserScreen extends ConsumerWidget {
  const UserScreen({super.key, required this.username, this.embedded = false});
  final String username;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final about = ref.watch(userAboutProvider(username));
    final me = ref.watch(
      authControllerProvider.select((auth) => auth.valueOrNull?.username),
    );
    final isSelf = me != null && me.toLowerCase() == username.toLowerCase();
    final repo = ref.watch(redditRepositoryProvider);
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = embedded
        ? 130.0
        : 24 + MediaQuery.paddingOf(context).bottom;
    final tabs = <Tab>[
      const Tab(text: 'Posts'),
      const Tab(text: 'Comments'),
      if (isSelf) const Tab(text: 'Saved'),
      if (isSelf) const Tab(text: 'Upvoted'),
      const Tab(text: 'About'),
    ];
    Widget header() => about.when(
      loading: () => const SizedBox(
        height: 360,
        child: Center(child: M3ELoadingIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: ErrorView(
          message: error,
          onRetry: () => ref.invalidate(userAboutProvider(username)),
        ),
      ),
      data: (user) => ProfileHero(
        user: user,
        isSelf: isSelf,
        onManageAccount: () => showAccountBottomSheet(context, ref, username),
        onMessage: () => context.push(
          '/compose_message?to=${Uri.encodeComponent(username)}',
        ),
      ),
    );
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !embedded,
          title: Text(
            embedded ? 'Profile' : 'u/$username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (isSelf)
              IconButton(
                tooltip: 'Custom feeds',
                icon: const Icon(Icons.dynamic_feed_rounded),
                onPressed: () => showCustomFeedsSheet(context, ref, username),
              ),
            if (isSelf)
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () =>
                  shareUrl(context, 'https://reddit.com/user/$username'),
            ),
            if (!isSelf)
              IconButton(
                tooltip: 'Block user',
                icon: const Icon(Icons.block_flipped),
                onPressed: () => confirmBlockUser(context, ref, username),
              ),
          ],
        ),
        body: NestedScrollView(
          key: ValueKey((username, isSelf)),
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: header()),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: ProfileTabs(tabs: tabs),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              PagedList<Post>(
                key: PageStorageKey('$username-posts'),
                primary: true,
                padding: EdgeInsets.fromLTRB(10, 0, 10, bottomPadding),
                requestKey: (username, repo, 'posts'),
                fetch: (a) => repo.getUserPosts(username, after: a),
                itemBuilder: (_, p) => PostCard(post: p),
                emptyLabel: 'No posts yet',
              ),
              PagedList<Comment>(
                key: PageStorageKey('$username-comments'),
                primary: true,
                padding: EdgeInsets.fromLTRB(10, 0, 10, bottomPadding),
                requestKey: (username, repo, 'comments'),
                fetch: (a) => repo.getUserComments(username, after: a),
                itemBuilder: (_, c) => _ProfileCommentCard(comment: c),
                emptyLabel: 'No comments yet',
              ),
              if (isSelf)
                PagedList<Object>(
                  key: PageStorageKey('$username-saved'),
                  primary: true,
                  padding: EdgeInsets.fromLTRB(10, 0, 10, bottomPadding),
                  requestKey: (username, repo, 'saved'),
                  fetch: (a) => repo.getUserSaved(username, after: a),
                  itemBuilder: (_, item) => item is Post
                      ? PostCard(post: item)
                      : _ProfileCommentCard(comment: item as Comment),
                  emptyLabel: 'Nothing saved',
                ),
              if (isSelf)
                PagedList<Post>(
                  key: PageStorageKey('$username-upvoted'),
                  primary: true,
                  padding: EdgeInsets.fromLTRB(10, 0, 10, bottomPadding),
                  requestKey: (username, repo, 'upvoted'),
                  fetch: (a) =>
                      repo.getUserPosts(username, where: 'upvoted', after: a),
                  itemBuilder: (_, p) => PostCard(post: p),
                  emptyLabel: 'Nothing upvoted',
                ),
              ListView(
                key: PageStorageKey('$username-about'),
                primary: true,
                padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPadding),
                children: [
                  Text(
                    'About u/$username',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  about.when(
                    loading: () => const Center(child: M3ELoadingIndicator()),
                    error: (e, _) =>
                        const Text('Profile details are unavailable.'),
                    data: (user) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.description.isEmpty
                              ? 'No bio provided.'
                              : user.description,
                        ),
                        if (user.created.year > 1970) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Joined ${user.created.year}-${user.created.month.toString().padLeft(2, '0')}-${user.created.day.toString().padLeft(2, '0')}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCommentCard extends StatelessWidget {
  const _ProfileCommentCard({required this.comment});
  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: ShapeTokens.extraLarge,
        onTap: () {
          final route = comment.permalink.isEmpty
              ? null
              : routeForRedditUrl(
                  Uri.parse('https://reddit.com${comment.permalink}'),
                );
          if (route != null) context.push(route);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (comment.linkTitle.isNotEmpty)
                Text(
                  comment.linkTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              Text(
                'r/${comment.subreddit} · ${compactNumber(comment.score)} pts · ${timeAgo(comment.created)}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                comment.body.replaceAll('\n', ' '),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
