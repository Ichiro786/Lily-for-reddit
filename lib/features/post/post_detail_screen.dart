import 'package:flutter/material.dart';
import '../../core/widgets/m3e_refresh_indicator.dart';

import '../../core/widgets/m3e_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../core/theme/motion_tokens.dart';
import '../media/expandable_post_media.dart';
import '../media/post_media_image.dart';
import '../feed/inline_video.dart';
import 'comment_media_helper.dart';
import 'comment_content.dart';
import 'comment_search_dialog.dart';

import '../history/interest_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/interaction_actions.dart';
import '../../core/media_aspect_ratio.dart';
import '../../core/providers.dart';
import '../../core/root_messenger.dart';
import '../../core/share.dart';
import '../../core/url_launcher_helper.dart';
import '../../core/theme/shape_tokens.dart';
import '../../core/widgets/error_view.dart';
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
import 'comment_overrides.dart';
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
  final String?
  focusCommentId; // open a single comment thread (from a permalink)

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositions = ItemPositionsListener.create();
  List<Comment> _flat = const [];

  // In-post comment search.
  bool _searchOpen = false;
  String _searchQuery = '';
  // Owned here so a failed quick reply can restore the user's text.
  final TextEditingController _composeCtrl = TextEditingController();
  MediaAttachment? _pendingComposeAttachment;
  MarkdownStyleSheet? _commentMarkdownStyle;
  ThemeData? _commentMarkdownTheme;

  MarkdownStyleSheet _getCommentMarkdownStyle(BuildContext context) {
    final theme = Theme.of(context);
    if (_commentMarkdownStyle == null ||
        !identical(_commentMarkdownTheme, theme)) {
      _commentMarkdownTheme = theme;
      _commentMarkdownStyle = buildM3EMarkdownStyleSheet(theme);
    }
    return _commentMarkdownStyle!;
  }

  void _showCommentOverflowMenu(
    BuildContext context,
    Comment comment,
    Post post,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: ShapeTokens.extraLargeShape,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: comment.body));
                showRootSnackBar(
                  const SnackBar(content: Text('Comment copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share comment'),
              onTap: () {
                Navigator.pop(ctx);
                final permalink = comment.permalink.isNotEmpty
                    ? (comment.permalink.startsWith('http')
                          ? comment.permalink
                          : 'https://reddit.com${comment.permalink}')
                    : 'https://reddit.com${post.permalink}${comment.id}/';
                shareUrl(
                  context,
                  permalink,
                  subject: 'Comment by u/${comment.author}',
                );
              },
            ),
            if (comment.author.isNotEmpty && comment.author != '[deleted]')
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text('View u/${comment.author}\'s profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/u/${comment.author}');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _composeCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCommentSearch() async {
    if (_searchOpen) return;
    _searchOpen = true;
    final key = widget.focusCommentId != null
        ? '${widget.subreddit}/${widget.postId}/focus_${widget.focusCommentId}'
        : '${widget.subreddit}/${widget.postId}';
    try {
      final fullname = await showDialog<String>(
        context: context,
        animationStyle: AnimationStyle(
          duration: MotionTokens.feedback(context),
          reverseDuration: MotionTokens.feedback(context),
          curve: MotionTokens.emphasized,
        ),
        builder: (_) => CommentSearchDialog(
          threadKey: key,
          initialQuery: _searchQuery,
          onQueryChanged: (query) {
            if (mounted) _searchQuery = query;
          },
        ),
      );
      if (!mounted || fullname == null) return;
      final thread = ref.read(commentsControllerProvider(key)).valueOrNull;
      if (thread == null) return;
      final index = visibleComments(
        thread,
      ).indexWhere((c) => c.fullname == fullname);
      if (index >= 0) {
        FocusManager.instance.primaryFocus?.unfocus();
        _scrollToIndex(index + 1);
      }
    } finally {
      _searchOpen = false;
    }
  }

  void _scrollToIndex(int index) {
    if (!_itemScrollController.isAttached) return;
    if (MotionTokens.reduced(context)) {
      _itemScrollController.jumpTo(index: index);
    } else {
      _itemScrollController.scrollTo(
        index: index,
        duration: MotionTokens.content(context),
        curve: MotionTokens.emphasized,
      );
    }
  }

  Future<void> _sendQuickReply(
    CommentsController notifier,
    PostThread thread,
    String text,
    MediaAttachment? attachment,
  ) async {
    final repo = ref.read(redditRepositoryProvider);
    try {
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
      ref.read(interestStoreProvider.notifier).bump(thread.post.subreddit, 2.5);
      ref.read(keywordStoreProvider.notifier).bumpTitle(thread.post.title, 1);
    } catch (e) {
      if (!mounted) return;
      // The compose bar already cleared the text; put it back so a transient
      // failure doesn't eat the user's comment.
      if (_composeCtrl.text.trim().isEmpty) _composeCtrl.text = text;
      if (_pendingComposeAttachment == null) {
        setState(() => _pendingComposeAttachment = attachment);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't post the comment: ${friendlyError(e)}"),
        ),
      );
    }
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
    if (_flat.isNotEmpty) _scrollToIndex(1);
  }

  void _jumpNextTopLevel() {
    if (_flat.isEmpty || !_itemScrollController.isAttached) return;
    final visible = _itemPositions.itemPositions.value.where(
      (p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1,
    );
    final first = visible.isEmpty
        ? 0
        : visible.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    for (var i = first; i < _flat.length; i++) {
      if (_flat[i].depth == 0 && !_flat[i].isMore) {
        _scrollToIndex(i + 1);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.focusCommentId != null
        ? '${widget.subreddit}/${widget.postId}/focus_${widget.focusCommentId}'
        : '${widget.subreddit}/${widget.postId}';
    final async = ref.watch(commentsControllerProvider(key));
    final notifier = ref.read(commentsControllerProvider(key).notifier);
    final username =
        ref.watch(
          authControllerProvider.select((auth) => auth.valueOrNull?.username),
        ) ??
        '';
    final thread = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: 'Double-tap to search comments',
          child: Semantics(
            button: thread != null,
            onTap: thread == null ? null : _openCommentSearch,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: thread == null ? null : _openCommentSearch,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      thread?.post.subredditPrefixed ??
                          (widget.subreddit == '_'
                              ? 'Post'
                              : 'r/${widget.subreddit}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (thread != null)
            PopupMenuButton<String>(
              tooltip: 'Sort comments',
              icon: const Icon(Icons.sort_rounded),
              shape: ShapeTokens.largeShape,
              popUpAnimationStyle: AnimationStyle(
                duration: MotionTokens.content(context),
                reverseDuration: MotionTokens.feedback(context),
                curve: MotionTokens.emphasized,
              ),
              onSelected: notifier.changeSort,
              itemBuilder: (_) => [
                for (final sort in commentSorts)
                  CheckedPopupMenuItem(
                    value: sort,
                    checked: notifier.sort == sort,
                    child: Text(commentSortLabels[sort] ?? sort),
                  ),
              ],
            ),
          if (thread != null)
            IconButton.filledTonal(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Post options',
              onPressed: () => showPostActionsSheet(
                context,
                ref,
                thread.post,
                onSearchComments: _openCommentSearch,
              ),
            ),
          if (thread != null && thread.post.author == username)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final post = thread.post;
                if (v == 'edit' && post.isSelf) {
                  final newText = await showEditSheet(
                    context,
                    ref,
                    thingFullname: post.fullname,
                    initialText: post.selftext,
                  );
                  if (newText != null) {
                    notifier.applyEdit(post.fullname, newText);
                  }
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
                      Text(
                        'Could not load this post.\n$e',
                        textAlign: TextAlign.center,
                      ),
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
                  flattenedCommentPresentationProvider((
                    key,
                    commentMarkdownStyle,
                  )),
                );
                final flat = [
                  for (final presentation in presentations)
                    presentation.comment,
                ];
                _flat = flat;
                final colorScheme = Theme.of(context).colorScheme;
                final theme = Theme.of(context);
                final sortHeader = Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: PopupMenuButton<String>(
                        popUpAnimationStyle: AnimationStyle(
                          duration: MotionTokens.content(context),
                          reverseDuration: MotionTokens.feedback(context),
                          curve: MotionTokens.emphasized,
                        ),
                        shape: ShapeTokens.largeShape,
                        position: PopupMenuPosition.under,
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sort_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                // Reflect the controller's active sort; the label
                                // mapping is the single canonical source.
                                (commentSortLabels[notifier.sort] ??
                                        notifier.sort)
                                    .toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'COMMENTS',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                return M3ERefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositions,
                    physics: const AlwaysScrollableScrollPhysics(),
                    minCacheExtent: 320,
                    itemCount: flat.isEmpty ? 2 : flat.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.focusCommentId != null)
                                  Material(
                                    color: colorScheme.secondaryContainer,
                                    child: InkWell(
                                      onTap: () => context.replace(
                                        '/comments/${widget.subreddit}/${widget.postId}',
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .subdirectory_arrow_right_rounded,
                                              size: 18,
                                              color: colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Viewing a single comment thread',
                                                style: TextStyle(
                                                  color: colorScheme
                                                      .onSecondaryContainer,
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
                                Divider(
                                  height: 16,
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                sortHeader,
                                const SizedBox(height: 8),
                              ],
                            ),
                          ],
                        );
                      }
                      if (flat.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No comments yet')),
                        );
                      }
                      final presentation = presentations[index - 1];
                      final c = presentation.comment;
                      return RepaintBoundary(
                        child: _CommentTile(
                          key: ValueKey(c.isMore ? moreNodeKey(c) : c.fullname),
                          comment: c,
                          richBody: presentation.markdownBody,
                          opAuthor: thread.post.author,
                          collapsed: thread.collapsed.contains(c.id),
                          loadingMore: thread.loadingMore.contains(
                            moreNodeKey(c),
                          ),
                          onToggle: () => notifier.toggleCollapse(c.id),
                          onLoadMore: () => notifier.loadMore(c),
                          onOverflow: () =>
                              _showCommentOverflowMenu(context, c, thread.post),
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
                  ),
                );
              },
            ),
          ),
          CommentComposeBar(
            controller: _composeCtrl,
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
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
          child: Center(child: M3ELoadingIndicator()),
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

  Future<void> _vote(int dir) =>
      ref.read(interactionActionsProvider).votePost(widget.post, dir);

  void _openMedia() {
    final p = widget.post;
    switch (p.type) {
      case PostType.image:
      case PostType.gif:
        openImageViewer(
          context,
          p.type == PostType.gif && isCommentGifUrl(p.url)
              ? normalizedCommentMediaUrl(p.url)
              : p.previewUrl ?? p.url,
          title: p.title,
        );
      case PostType.gallery:
        openGalleryViewer(context, p.gallery, title: p.title);
      case PostType.video:
        if (isYouTubeUrl(p.url)) {
          launchSmartUrl(p.url);
          break;
        }
        openVideoViewer(
          context,
          p.hlsUrl ?? p.fallbackVideoUrl ?? resolveVideoUrl(p.url),
          title: p.title,
          downloadUrl: p.fallbackVideoUrl ?? resolveVideoUrl(p.url),
          externalUrl: p.url,
        );
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
              if (p.stickied)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 16,
                    color: cs.primary,
                  ),
                ),
              if (p.over18)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: ShapeTokens.extraSmall,
                  ),
                  child: Text(
                    'NSFW',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          if (p.linkFlairText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.72),
                borderRadius: ShapeTokens.full,
              ),
              child: Text(
                p.linkFlairText!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ],
          if (p.crosspostFrom != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Crossposted from r/${p.crosspostFrom}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _media(cs),
          if (p.pollOptions.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final opt in p.pollOptions)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: ShapeTokens.small,
                ),
                child: Text(opt),
              ),
            Text(
              'Vote in the official app',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
          if (p.isSelf && p.selftext.isNotEmpty)
            CommentContent(
              body: p.selftext,
              styleSheet: buildM3EMarkdownStyleSheet(Theme.of(context)),
            ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final ov = ref.watch(
                postOverridesProvider.select((m) => m[p.id]),
              );
              final likes = ov != null ? ov.likes : p.likes;
              final score = ov?.score ?? p.score;
              final saved = ov?.saved ?? p.saved;
              final numComments = ov?.numComments ?? p.numComments;
              return M3EPostActionBar(
                detailStyle: true,
                score: score,
                commentCount: numComments,
                voteState: likes == true ? 1 : (likes == false ? -1 : 0),
                isSaved: saved,
                onVote: _vote,
                onCommentTap: widget.onComments,
                onSaveTap: () =>
                    ref.read(interactionActionsProvider).toggleSavePost(p),
                onShareTap: () => shareUrl(context, p.url, subject: p.title),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _media(ColorScheme cs) {
    final p = widget.post;
    if (p.type == PostType.self) return const SizedBox.shrink();
    final blurNsfw = ref.watch(
      settingsControllerProvider.select((s) => s.blurNsfw),
    );
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
        child: InkWell(
          onTap: _openMedia,
          borderRadius: ShapeTokens.medium,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: ShapeTokens.medium,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                if (p.thumbnailUrl != null && p.thumbnailUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: ShapeTokens.small,
                    child: CachedNetworkImage(
                      imageUrl: p.thumbnailUrl!,
                      memCacheWidth:
                          (72 * MediaQuery.devicePixelRatioOf(context))
                              .round()
                              .clamp(1, 300)
                              .toInt(),
                      memCacheHeight:
                          (72 * MediaQuery.devicePixelRatioOf(context))
                              .round()
                              .clamp(1, 300)
                              .toInt(),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorWidget: (_, __, ___) =>
                          const SizedBox(width: 72, height: 72),
                    ),
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.link_rounded, color: cs.onSurfaceVariant),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.domain,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final url = p.type == PostType.gif && isCommentGifUrl(p.url)
        ? normalizedCommentMediaUrl(p.url)
        : p.previewUrl ?? (p.gallery.isNotEmpty ? p.gallery.first.url : null);
    final renderAspect = intrinsicMediaAspectRatio(
      width: p.previewWidth,
      height: p.previewHeight,
      fallback: p.type == PostType.video ? 16 / 9 : 4 / 3,
    );
    final cacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(1, 1080);
    final autoplay =
        ref.watch(settingsControllerProvider.select((s) => s.autoplayMedia)) &&
        !MotionTokens.reduced(context);
    final videoUrl = p.hlsUrl ?? p.fallbackVideoUrl ?? resolveVideoUrl(p.url);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NsfwBlur(
        blur: blur,
        child: ExpandablePostMedia(
          key: ValueKey(p.fullname),
          aspectRatio: renderAspect,
          onOpen: _openMedia,
          builder: (context, height) {
            if (p.type == PostType.video &&
                autoplay &&
                videoUrl.isNotEmpty &&
                !isYouTubeUrl(p.url) &&
                !isCommentGifUrl(videoUrl)) {
              return InlineVideo(
                key: ValueKey('detail-video-${p.id}'),
                url: videoUrl,
                poster: url,
                height: height,
                onTap: _openMedia,
              );
            }
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                if (url != null)
                  PostMediaImage(
                    url: url,
                    cacheWidth: cacheWidth,
                    animate: autoplay || p.type != PostType.gif,
                  ),
                if (p.type == PostType.video)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.scrim.withValues(alpha: 0.54),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                if (p.type == PostType.gif)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Chip(
                      label: const Text('GIF'),
                      backgroundColor: cs.surfaceContainerHigh,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    this.richBody,
    required this.opAuthor,
    required this.collapsed,
    required this.loadingMore,
    required this.onToggle,
    required this.onLoadMore,
    required this.onOpenThread,
    required this.onReply,
    this.onOverflow,
  });

  final Comment comment;

  /// Pre-rendered Markdown/spoiler body from the flattened-comment pipeline
  /// (null when collapsed or empty).
  final Widget? richBody;
  final String opAuthor;
  final bool collapsed;
  final bool loadingMore;
  final VoidCallback onToggle;
  final VoidCallback onLoadMore;
  final VoidCallback onOpenThread;
  final VoidCallback onReply;
  final VoidCallback? onOverflow;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  Future<void> _vote(int dir) =>
      ref.read(interactionActionsProvider).voteComment(widget.comment, dir);

  Future<void> _toggleSave() =>
      ref.read(interactionActionsProvider).toggleSaveComment(widget.comment);

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
                : comment.moreChildren.isNotEmpty
                ? widget.onLoadMore
                : widget.onOpenThread,
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
                      child: M3ELoadingIndicator.small(),
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
      child: Builder(
        builder: (context) {
          // Narrow subscription: only this comment's override triggers a
          // rebuild, mirroring the M3EPostActionBar pattern.
          final ov = ref.watch(
            commentOverridesProvider.select((m) => m[comment.fullname]),
          );
          final effective =
              ov ??
              CommentOverride(
                likes: comment.likes,
                score: comment.score,
                saved: comment.saved,
              );
          return M3ECommentCard(
            author: comment.author,
            timeAgo: timeAgo(comment.created),
            body: comment.body,
            richBody: widget.richBody,
            depth: comment.depth,
            isOp: comment.author == widget.opAuthor,
            score: effective.score,
            voteState: effective.voteDirection,
            isSaved: effective.saved,
            replyCount: comment.replies.length,
            isCollapsed: widget.collapsed,
            onToggleCollapse: widget.onToggle,
            onVote: _vote,
            onReply: widget.onReply,
            onSave: _toggleSave,
            onOverflow: widget.onOverflow,
            onLoadMoreReplies: widget.collapsed ? widget.onToggle : null,
          );
        },
      ),
    );
  }
}
