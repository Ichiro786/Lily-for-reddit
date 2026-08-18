
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../history/interest_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/share.dart';
import '../../core/url_launcher_helper.dart';
import '../../core/theme/shape_tokens.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../auth/auth_controller.dart';
import '../feed/post_action_bar.dart';
import '../feed/post_overrides.dart';
import '../feed/swipe_actions.dart';
import '../media/attachment.dart';
import '../media/gallery_carousel.dart';
import '../media/media_viewers.dart';
import '../media/nsfw_blur.dart';
import '../settings/settings_controller.dart';
import 'comments_controller.dart';
import 'comment_card.dart';
import 'compose_sheet.dart';
import 'comment_compose_bar.dart';
import 'post_actions.dart';
import 'interactive_spoiler.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.subreddit,
    required this.postId,
    this.initialPost,
    this.focusCommentId,
  });

  final String subreddit;
  final String postId;
  final Post? initialPost;
  final String? focusCommentId; // open a single comment thread (from a permalink)

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Comment> _flat = const [];

  // In-post comment search.
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<int> _matchIndices = []; // list indices (ci + 1) of matching comments
  int _matchPos = 0;
  MediaAttachment? _pendingComposeAttachment;
  MarkdownStyleSheet? _commentMarkdownStyle;
  ThemeData? _commentMarkdownTheme;

  MarkdownStyleSheet _getCommentMarkdownStyle(BuildContext context) {
    final theme = Theme.of(context);
    if (_commentMarkdownStyle == null ||
        !identical(_commentMarkdownTheme, theme)) {
      _commentMarkdownTheme = theme;
      _commentMarkdownStyle = MarkdownStyleSheet(
        p: theme.textTheme.bodyMedium
            ?.copyWith(fontSize: 15, height: 1.45),
      );
    }
    return _commentMarkdownStyle!;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _matchIndices = [];
      }
    });
  }

  void _runSearch(String raw) {
    final q = raw.trim().toLowerCase();
    final m = <int>[];
    if (q.isNotEmpty) {
      for (var ci = 0; ci < _flat.length; ci++) {
        final c = _flat[ci];
        if (!c.isMore && c.body.toLowerCase().contains(q)) m.add(ci + 1);
      }
    }
    setState(() {
      _matchIndices = m;
      _matchPos = 0;
    });
    if (m.isNotEmpty) _scrollToMatch();
  }

  void _scrollToMatch() {
    if (_matchIndices.isEmpty) return;
    final li = _matchIndices[_matchPos];
    _scrollController.animateTo(
      (_scrollController.offset + 260).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _stepMatch(int delta) {
    if (_matchIndices.isEmpty) return;
    setState(() => _matchPos =
        (_matchPos + delta + _matchIndices.length) % _matchIndices.length);
    _scrollToMatch();
  }

  /// Jumps the comment list to the next top-level (depth 0) comment, cycling
  /// back to the first once past the last. List index 0 is the post header, so
  /// comment `ci` lives at list index `ci + 1`.
  Future<void> _sendQuickReply(
    CommentsController notifier,
    PostThread thread,
    String text,
    MediaAttachment? attachment,
  ) async {
    final repo = ref.read(redditRepositoryProvider);
    final reply = attachment == null
        ? await repo.reply(
            parentFullname: thread.post.fullname,
            text: text,
            depth: 0,
          )
        : await repo.replyWithImage(
            parentFullname: thread.post.fullname,
            text: text,
            bytes: attachment.bytes,
            filename: attachment.filename,
            mimeType: attachment.mimeType,
            depth: 0,
          );
    notifier.insertReply(thread.post.fullname, reply);
    ref.read(postOverridesProvider.notifier).bumpComments(thread.post, 1);
    ref
        .read(interestStoreProvider.notifier)
        .bump(thread.post.subreddit, 2.5);
    ref.read(keywordStoreProvider.notifier).bumpTitle(thread.post.title, 1);
  }

  Future<void> _onComposeImageSelected(XFile? file) async {
    if (file == null) {
      if (mounted) setState(() => _pendingComposeAttachment = null);
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingComposeAttachment = MediaAttachment(
        bytes: bytes,
        filename: file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
        isVideo: false,
      );
    });
  }

  void _scrollToComments() {
    if (_flat.isEmpty || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + 320).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _jumpNextTopLevel() {
    if (_flat.isEmpty || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + 280).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.focusCommentId != null
        ? '${widget.subreddit}/${widget.postId}/focus_${widget.focusCommentId}'
        : '${widget.subreddit}/${widget.postId}';
    final async = ref.watch(commentsControllerProvider(key));
    final notifier = ref.read(commentsControllerProvider(key).notifier);
    final username = ref.watch(
          authControllerProvider.select((auth) => auth.valueOrNull?.username),
        ) ??
        '';
    final thread = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                thread?.post.subredditPrefixed ??
                    (widget.subreddit == '_' ? 'Post' : 'r/${widget.subreddit}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
        actions: [
          if (thread != null)
            IconButton(
              tooltip: 'Search comments',
              icon: Icon(
                  _searchOpen ? Icons.search_off_rounded : Icons.search_rounded),
              onPressed: _toggleSearch,
            ),
          if (thread != null)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () =>
                  showPostActionsSheet(context, ref, thread.post),
            ),
          if (thread != null && thread.post.author == username)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final post = thread.post;
                if (v == 'edit' && post.isSelf) {
                  final newText = await showEditSheet(context, ref,
                      thingFullname: post.fullname, initialText: post.selftext);
                  if (newText != null) notifier.applyEdit(post.fullname, newText);
                } else if (v == 'delete') {
                  final ok = await _confirmDelete(context, 'post');
                  if (ok) {
                    await ref
                        .read(redditRepositoryProvider)
                        .deleteThing(post.fullname);
                    if (context.mounted) Navigator.of(context).maybePop();
                  }
                }
              },
              itemBuilder: (_) => [
                if (thread.post.isSelf)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => _LoadingWithHeader(post: widget.initialPost),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load this post.\n$e',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: notifier.refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (thread) {
                final commentMarkdownStyle = _getCommentMarkdownStyle(context);
                final presentations = ref.watch(
                  flattenedCommentPresentationProvider((key, commentMarkdownStyle)),
                );
                final flat = [
                  for (final presentation in presentations) presentation.comment,
                ];
                _flat = flat;
                final colorScheme = Theme.of(context).colorScheme;
                final theme = Theme.of(context);
                final sortHeader = Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: PopupMenuButton<String>(
                    onSelected: notifier.changeSort,
                    itemBuilder: (_) => [
                      for (final s in commentSorts)
                        CheckedPopupMenuItem(
                          value: s,
                          checked: notifier.sort == s,
                          child: Text(commentSortLabels[s] ?? s),
                        ),
                    ],
                    tooltip: 'Sort comments',
                    child: Row(
                      children: [
                        Icon(Icons.sort_rounded,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'BEST COMMENTS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: colorScheme.primary,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: colorScheme.primary),
                      ],
                    ),
                  ),
                );

                return RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (_searchOpen)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: _buildSearchBar(context),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.focusCommentId != null)
                              Material(
                                color: colorScheme.secondaryContainer,
                                child: InkWell(
                                  onTap: () => context.replace(
                                      '/comments/${widget.subreddit}/${widget.postId}'),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.subdirectory_arrow_right_rounded,
                                          size: 18,
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Viewing a single comment thread',
                                            style: TextStyle(
                                              color: colorScheme.onSecondaryContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Show all',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            _PostHeader(
                              post: thread.post,
                              onComments: _scrollToComments,
                            ),
                            sortHeader,
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (flat.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: Text('No comments yet')),
                              );
                            }
                            final c = presentations[index].comment;
                            return RepaintBoundary(
                              child: _CommentTile(
                                key: ValueKey(c.fullname),
                                comment: c,
                                opAuthor: thread.post.author,
                                collapsed: thread.collapsed.contains(c.id),
                                loadingMore:
                                    thread.loadingMore.contains(c.fullname),
                                onToggle: () => notifier.toggleCollapse(c.id),
                                onLoadMore: () => notifier.loadMore(c),
                                onOpenThread: () {
                                  final focusId = c.moreChildren.isNotEmpty
                                      ? c.moreChildren.first
                                      : c.id;
                                  context.push(
                                    '/comments/${Uri.encodeComponent(thread.post.subreddit)}/${thread.post.id}?comment=${Uri.encodeComponent(focusId)}',
                                  );
                                },
                                onReply: () async {
                                  final reply = await showReplySheet(
                                    context,
                                    ref,
                                    parentFullname: c.fullname,
                                    parentDepth: c.depth,
                                    replyingTo: c.author,
                                  );
                                  if (reply != null) {
                                    notifier.insertReply(c.fullname, reply);
                                    ref
                                        .read(postOverridesProvider.notifier)
                                        .bumpComments(thread.post, 1);
                                    ref
                                        .read(interestStoreProvider.notifier)
                                        .bump(thread.post.subreddit, 2.5);
                                  }
                                },
                              ),
                            );
                          },
                          childCount: flat.isEmpty ? 1 : flat.length,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          CommentComposeBar(
            onSubmit: (text) {
              if (thread == null) return;
              final attachment = _pendingComposeAttachment;
              _pendingComposeAttachment = null;
              _sendQuickReply(notifier, thread, text, attachment);
            },
            onImageSelected: _onComposeImageSelected,
            onJumpNext: thread == null || thread.comments.isEmpty
                ? null
                : _jumpNextTopLevel,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _matchIndices.length;
    final has = _searchCtrl.text.trim().isNotEmpty;
    return Material(
      elevation: 4,
      borderRadius: ShapeTokens.extraLarge,
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const SizedBox(width: 6),
            Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _runSearch,
                onSubmitted: (_) => _stepMatch(1),
                decoration: const InputDecoration(
                  hintText: 'Search comments',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (has)
              Text(total == 0 ? '0/0' : '${_matchPos + 1}/$total',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            IconButton(
              tooltip: 'Previous',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed: total == 0 ? null : () => _stepMatch(-1),
            ),
            IconButton(
              tooltip: 'Next',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: total == 0 ? null : () => _stepMatch(1),
            ),
            IconButton(
              tooltip: 'Close',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded),
              onPressed: _toggleSearch,
            ),
          ],
        ),
      ),
    );
  }
}


Future<bool> _confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $what?'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete')),
      ],
    ),
  );
  return ok ?? false;
}

class _LoadingWithHeader extends StatelessWidget {
  const _LoadingWithHeader({this.post});
  final Post? post;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (post != null) _PostHeader(post: post!),
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _PostHeader extends ConsumerStatefulWidget {
  const _PostHeader({required this.post, this.onComments});
  final Post post;
  final VoidCallback? onComments;
  @override
  ConsumerState<_PostHeader> createState() => _PostHeaderState();
}

class _PostHeaderState extends ConsumerState<_PostHeader> {
  @override
  void initState() {
    super.initState();
    // Seed the shared overrides from this fresh fetch (esp. the comment count)
    // so the feed card reflects it when you go back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(postOverridesProvider.notifier).syncFromServer(widget.post);
      }
    });
  }

  Future<void> _vote(int dir) async {
    final overrides = ref.read(postOverridesProvider.notifier);
    final cur = overrides.effective(widget.post);
    final current = cur.likes == true ? 1 : (cur.likes == false ? -1 : 0);
    final target = current == dir ? 0 : dir;
    overrides.setVote(widget.post, target);
    if (target == 1) {
      ref.read(interestStoreProvider.notifier).bump(widget.post.subreddit, 2);
    } else if (target == -1) {
      ref.read(interestStoreProvider.notifier).bump(widget.post.subreddit, -1.5);
    }
    try {
      await ref.read(redditRepositoryProvider).vote(widget.post.fullname, target);
    } catch (_) {
      overrides.setVote(widget.post, current);
    }
  }

  void _openMedia() {
    final p = widget.post;
    switch (p.type) {
      case PostType.image:
      case PostType.gif:
        openImageViewer(context, p.previewUrl ?? p.url, title: p.title);
      case PostType.gallery:
        openGalleryViewer(context, p.gallery, title: p.title);
      case PostType.video:
        if (isYouTubeUrl(p.url)) {
          launchSmartUrl(p.url);
          break;
        }
        openVideoViewer(
            context, p.hlsUrl ?? p.fallbackVideoUrl ?? resolveVideoUrl(p.url),
            title: p.title,
            downloadUrl: p.fallbackVideoUrl ?? resolveVideoUrl(p.url),
            externalUrl: p.url);
      case PostType.link:
        launchSmartUrl(p.url);
      case PostType.self:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.push('/r/${p.subreddit}'),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    p.subreddit.isEmpty ? '?' : p.subreddit[0].toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/r/${p.subreddit}'),
                      child: Text(
                        p.subredditPrefixed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => context.push('/u/${p.author}'),
                      child: Text(
                        'u/${p.author} · ${timeAgo(p.created)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(p.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
          if (p.linkFlairText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: ShapeTokens.extraSmall),
              child: Text(p.linkFlairText!,
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ),
          ],
          if (p.crosspostFrom != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.repeat_rounded, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Crossposted from r/${p.crosspostFrom}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          _media(cs),
          if (p.pollOptions.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final opt in p.pollOptions)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: ShapeTokens.small,
                ),
                child: Text(opt),
              ),
            Text('Vote in the official app',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
          if (p.isSelf && p.selftext.isNotEmpty)
            MarkdownBody(
              data: normalizeRedditSpoilers(p.selftext),
              builders: {
                'spoiler': RedditSpoilerBuilder(),
              },
              selectable: true,
              onTapLink: (_, href, __) {
                if (href != null) {
                  launchSmartUrl(href);
                }
              },
            ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final ov =
                ref.watch(postOverridesProvider.select((m) => m[p.id]));
            final likes = ov != null ? ov.likes : p.likes;
            final score = ov?.score ?? p.score;
            final saved = ov?.saved ?? p.saved;
            final numComments = ov?.numComments ?? p.numComments;
            return M3EPostActionBar(
              score: score,
              commentCount: numComments,
              voteState: likes == true ? 1 : (likes == false ? -1 : 0),
              isSaved: saved,
              onVote: _vote,
              onCommentTap: widget.onComments,
              onSaveTap: () async {
                final overrides = ref.read(postOverridesProvider.notifier);
                final next = !overrides.effective(p).saved;
                overrides.setSaved(p, next);
                try {
                  await ref
                      .read(redditRepositoryProvider)
                      .setSaved(p.fullname, next);
                } catch (_) {
                  overrides.setSaved(p, !next);
                }
              },
              onShareTap: () => shareUrl(
                context,
                p.url,
                subject: p.title,
              ),
            );
          }),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _media(ColorScheme cs) {
    final p = widget.post;
    if (p.type == PostType.self) return const SizedBox.shrink();
    final blurNsfw =
        ref.watch(settingsControllerProvider.select((s) => s.blurNsfw));
    final blur = (p.over18 && blurNsfw) || p.spoiler;
    if (p.type == PostType.gallery && p.gallery.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NsfwBlur(
          blur: blur,
          child: GalleryCarousel(images: p.gallery, title: p.title),
        ),
      );
    }
    if (p.type == PostType.link) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          onPressed: _openMedia,
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(p.domain, overflow: TextOverflow.ellipsis),
        ),
      );
    }
    final url =
        p.previewUrl ?? (p.gallery.isNotEmpty ? p.gallery.first.url : null);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final viewport = MediaQuery.sizeOf(context);
    final maxHeight = viewport.height * 0.65;
    final cacheWidth =
        (viewport.width * dpr).round().clamp(1, 1080).toInt();
    final cacheHeight = (maxHeight * dpr).ceil().clamp(1, 1080).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NsfwBlur(
        blur: blur,
        child: ClipRRect(
          borderRadius: ShapeTokens.large,
          child: GestureDetector(
            onTap: _openMedia,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 120,
                maxHeight: maxHeight,
              ),
              child: Container(
                width: double.infinity,
                color: cs.surfaceContainerLowest,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (url != null)
                      CachedNetworkImage(
                        imageUrl: url,
                        width: double.infinity,
                        memCacheWidth: cacheWidth,
                        memCacheHeight: cacheHeight,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      )
                    else
                      Container(color: cs.surfaceContainerHighest),
                    if (p.type == PostType.video)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.scrim.withValues(alpha: 0.54),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: cs.onSurface,
                          size: 36,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.opAuthor,
    required this.collapsed,
    required this.loadingMore,
    required this.onToggle,
    required this.onLoadMore,
    required this.onOpenThread,
    required this.onReply,
  });

  final Comment comment;
  final String opAuthor;
  final bool collapsed;
  final bool loadingMore;
  final VoidCallback onToggle;
  final VoidCallback onLoadMore;
  final VoidCallback onOpenThread;
  final VoidCallback onReply;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  late bool? _likes = widget.comment.likes;
  late int _score = widget.comment.score;
  late bool _saved = widget.comment.saved;


  Future<void> _vote(int dir) async {
    final current = _likes == true ? 1 : (_likes == false ? -1 : 0);
    final target = current == dir ? 0 : dir;
    setState(() {
      _score += target - current;
      _likes = target == 1 ? true : (target == -1 ? false : null);
    });
    try {
      await ref
          .read(redditRepositoryProvider)
          .vote(widget.comment.fullname, target);
    } catch (_) {
      if (mounted) {
        setState(() {
          _score -= target - current;
          _likes = current == 1 ? true : (current == -1 ? false : null);
        });
      }
    }
  }

  Future<void> _toggleSave() async {
    final next = !_saved;
    setState(() => _saved = next);
    try {
      await ref
          .read(redditRepositoryProvider)
          .setSaved(widget.comment.fullname, next);
    } catch (_) {
      if (mounted) setState(() => _saved = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final colorScheme = Theme.of(context).colorScheme;

    if (comment.isMore) {
      return Padding(
        padding: EdgeInsets.only(
          left: (comment.depth * 12.0).clamp(12.0, 48.0),
          right: 12,
          top: 4,
          bottom: 4,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: widget.loadingMore
                ? null
                : (comment.moreChildren.isNotEmpty
                    ? widget.onOpenThread
                    : widget.onLoadMore),
            borderRadius: ShapeTokens.full,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: ShapeTokens.full,
              ),
              child: widget.loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          comment.moreChildren.isEmpty
                              ? 'Continue thread'
                              : 'View ${comment.moreCount} more replies',
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    return SwipeActions(
      enabled: ref.watch(
        settingsControllerProvider.select((s) => s.swipeActions),
      ),
      onRight: () => _vote(1),
      onLeft: () => _vote(-1),
      child: M3ECommentCard(
        author: comment.author,
        timeAgo: timeAgo(comment.created),
        body: comment.body,
        depth: comment.depth,
        isOp: comment.author == widget.opAuthor,
        score: _score,
        replyCount: comment.replies.length,
        avatarColor: colorScheme.primaryContainer,
        isCollapsed: widget.collapsed,
        onToggleCollapse: widget.onToggle,
        onVote: _vote,
        onReply: widget.onReply,
        onSave: _toggleSave,
        onAward: () {},
        onOverflow: () {},
        onLoadMoreReplies: comment.replies.isNotEmpty
            ? widget.onOpenThread
            : null,
      ),
    );
  }

}
