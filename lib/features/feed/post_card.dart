import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics.dart';
import '../../core/format.dart';
import '../../core/media_aspect_ratio.dart';
import '../../core/providers.dart';
import '../../core/root_messenger.dart';
import '../../core/share.dart';
import '../../core/theme/shape_tokens.dart';
import '../../core/storage/interaction_vault.dart';
import '../../core/url_launcher_helper.dart';
import '../../core/widgets/tap_guard.dart';
import 'inline_video.dart';
import 'post_overrides.dart';
import '../../models/post.dart';
import '../history/history_store.dart';
import '../history/interest_store.dart';
import '../media/gallery_carousel.dart';
import '../media/media_viewers.dart';
import '../media/nsfw_blur.dart';
import '../post/post_actions.dart';
import '../settings/settings_controller.dart';
import 'swipe_actions.dart';
import 'compact_post_card.dart';
import 'post_action_bar.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post});
  final Post post;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  String? _dwellPostId;

  // Vote / score / saved / comment-count live in the shared post-overrides
  // store (keyed by post id) so the card stays in sync with the post-detail
  // screen and survives scrolling.
  PostOverride get _ov =>
      ref.read(postOverridesProvider.notifier).effective(widget.post);

  Future<void> _vote(int dir) async {
    final overrides = ref.read(postOverridesProvider.notifier);
    final current = _ov.likes == true ? 1 : (_ov.likes == false ? -1 : 0);
    final target = current == dir ? 0 : dir;
    ref.read(interactionVaultProvider.notifier).recordUpvote(
          widget.post.id,
          target == 1,
        );
    if (target == -1) {
      ref.read(interactionVaultProvider.notifier).recordDismissal(widget.post.id);
    } else if (current == -1) {
      ref.read(interactionVaultProvider.notifier).recordDismissal(widget.post.id, false);
    }
    overrides.setVote(widget.post, target);
    // Learn: upvoting a community raises its affinity; downvoting lowers it.
    if (target == 1) {
      ref.read(interestStoreProvider.notifier).bump(widget.post.subreddit, 2);
      ref.read(keywordStoreProvider.notifier).bumpTitle(widget.post.title, 1);
    } else if (target == -1) {
      ref.read(interestStoreProvider.notifier).bump(widget.post.subreddit, -1.5);
      ref.read(keywordStoreProvider.notifier).bumpTitle(widget.post.title, -0.8);
    }
    try {
      await ref.read(redditRepositoryProvider).vote(widget.post.fullname, target);
    } catch (_) {
      overrides.setVote(widget.post, current); // revert
    }
  }

  Future<void> _toggleSave() async {
    final overrides = ref.read(postOverridesProvider.notifier);
    final next = !_ov.saved;
    ref.read(interactionVaultProvider.notifier).recordSave(widget.post.id, next);
    overrides.setSaved(widget.post, next);
    ref.read(interestStoreProvider.notifier).bump(widget.post.subreddit, next ? 3 : -3);
    if (next) {
      ref.read(keywordStoreProvider.notifier).bumpTitle(widget.post.title, 1.5);
    }
    try {
      await ref.read(redditRepositoryProvider).setSaved(widget.post.fullname, next);
    } catch (_) {
      overrides.setSaved(widget.post, !next);
    }
  }

  void _openDetail() {
    Analytics.track('post_opened');
    if (ref.read(settingsControllerProvider).trackHistory) {
      ref.read(interactionVaultProvider.notifier).recordCommentOpened(widget.post.id);
      ref.read(historyControllerProvider.notifier).markViewed(widget.post);
      ref.read(interestStoreProvider.notifier).bump(widget.post.subreddit, 0.5);
    }
    context.push(
      '/comments/${widget.post.subreddit}/${widget.post.id}',
      extra: widget.post,
    );
  }

  void _openMedia() {
    final p = widget.post;
    // Viewing media is engagement too (slightly stronger than a plain open).
    if (p.type != PostType.self &&
        ref.read(settingsControllerProvider).trackHistory) {
      ref.read(interestStoreProvider.notifier).bump(p.subreddit, 1);
    }
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
        final src = p.hlsUrl ?? p.fallbackVideoUrl ?? resolveVideoUrl(p.url);
        openVideoViewer(context, src,
            title: p.title,
            downloadUrl: p.fallbackVideoUrl ?? resolveVideoUrl(p.url),
            externalUrl: p.url);
      case PostType.link:
        launchSmartUrl(p.url);
      case PostType.self:
        _openDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final postDisplay =
        ref.watch(settingsControllerProvider.select((s) => s.postDisplay));
    final trackHistory =
        ref.watch(settingsControllerProvider.select((s) => s.trackHistory));
    final swipeActions =
        ref.watch(settingsControllerProvider.select((s) => s.swipeActions));
    final seen = ref.watch(historyContainsProvider(widget.post.id));
    Widget card = switch (postDisplay) {
      PostDisplay.large => _largeCard(context),
      PostDisplay.card => _cardsCard(context),
      PostDisplay.mini => _miniCard(context),
    };
    // Dim already-viewed posts when history tracking is on.
    if (seen && trackHistory) {
      card = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.45),
          BlendMode.srcOver,
        ),
        child: card,
      );
    }
    // "Why you're seeing this" banner (For You feed only).
    final reason = widget.post.feedReason;
    if (reason != null) {
      // Count the impression: shown-but-never-opened posts get demoted on the
      // next feed build (batched + deduped inside the store).
      ref.read(impressionStoreProvider.notifier).record(widget.post.id);
      final cs = Theme.of(context).colorScheme;
      card = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 8, 0),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 13, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cs.primary),
                  ),
                ),
                // Discoverable entry to the feed-tuning sheet (also on long-press)
                // so "show less from this subreddit" isn't hidden.
                InkWell(
                  onTap: _showTuneSheet,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 13, color: cs.primary),
                        const SizedBox(width: 4),
                        Text('Tune',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: cs.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          card,
        ],
      );
    }
    return VisibilityDetector(
      key: ValueKey<String>('dwell-${widget.post.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.6 && _dwellPostId != widget.post.id) {
          _dwellPostId = widget.post.id;
          ref.read(interactionVaultProvider.notifier).recordDwell(widget.post.id);
        }
      },
      child: GestureDetector(
        onLongPress: _showTuneSheet,
        child: SwipeActions(
          enabled: swipeActions,
          onRight: () => _vote(1),
          onLeft: () => _vote(-1),
          child: card,
        ),
      ),
    );
  }

  /// Long-press → "tune your feed": teach the on-device model faster.
  void _showTuneSheet() {
    HapticFeedback.mediumImpact();
    final sub = widget.post.subreddit;
    final muted = ref.read(mutedSubsProvider.notifier).contains(sub);
    final interest = ref.read(interestStoreProvider.notifier);
    void toast(String msg) => showRootSnackBar(
          SnackBar(
            content: Text(msg),
            action: SnackBarAction(
              label: 'Manage',
              onPressed: () => context.push('/manage_for_you'),
            ),
          ),
        );

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      // Ignore taps briefly so the gesture that opened the sheet can't fall
      // through onto an item (which fired More/Less directly with no sheet).
      builder: (ctx) => TapGuard(
        child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 18, color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Tune your feed',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.thumb_up_alt_outlined),
              title: const Text('More like this'),
              subtitle: Text('Show more from r/$sub and similar'),
              onTap: () {
                interest.bump(sub, 5);
                ref
                    .read(keywordStoreProvider.notifier)
                    .bumpTitle(widget.post.title, 2);
                Navigator.pop(ctx);
                toast("We'll show more like this");
              },
            ),
            ListTile(
              leading: const Icon(Icons.thumb_down_alt_outlined),
              title: const Text('Less like this'),
              subtitle: Text('Show less from r/$sub'),
              onTap: () {
                interest.bump(sub, -5);
                ref
                    .read(keywordStoreProvider.notifier)
                    .bumpTitle(widget.post.title, -2);
                Navigator.pop(ctx);
                toast("We'll show less like this");
              },
            ),
            ListTile(
              leading: Icon(muted
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded),
              title: Text(muted ? 'Unmute r/$sub' : 'Mute r/$sub in For You'),
              onTap: () {
                ref.read(mutedSubsProvider.notifier).toggle(sub);
                Navigator.pop(ctx);
                toast(muted
                    ? 'r/$sub unmuted'
                    : 'r/$sub muted from For You');
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _cardShell(
    ColorScheme cs, {
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: ShapeTokens.large,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: ShapeTokens.large,
          child: child,
        ),
      ),
    );
  }

  Widget _largeCard(BuildContext context) {
    final p = widget.post;
    final cs = Theme.of(context).colorScheme;
    return _cardShell(
      cs,
      onTap: _openDetail,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(cs),
            const SizedBox(height: 10),
            Text(
              p.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
            ),
            if (p.linkFlairText != null) ...[
              const SizedBox(height: 8),
              _flair(cs, p.linkFlairText!),
            ],
            const SizedBox(height: 12),
            _media(cs),
            if (p.isSelf && p.selftext.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                p.selftext,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 4),
            _actions(),
          ],
        ),
      ),
    );
  }

  /// Full-card presentation with a shorter media banner for faster scanning.
  Widget _cardsCard(BuildContext context) {
    final p = widget.post;
    final cs = Theme.of(context).colorScheme;
    return _cardShell(
      cs,
      onTap: _openDetail,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(cs),
            const SizedBox(height: 10),
            Text(
              p.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
            ),
            if (p.linkFlairText != null) ...[
              const SizedBox(height: 8),
              _flair(cs, p.linkFlairText!),
            ],
            const SizedBox(height: 12),
            _bannerMedia(cs, 180),
            if (p.isSelf && p.selftext.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                p.selftext,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 4),
            _actions(),
          ],
        ),
      ),
    );
  }

  /// Compact presentation: metadata and actions on the left, 72dp media on
  /// the right. The display mode is already persisted by SettingsController.
  Widget _miniCard(BuildContext context) {
    final p = widget.post;
    final cs = Theme.of(context).colorScheme;
    return CompactPostCard(
      header: _header(cs),
      title: Text(
        p.title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
      ),
      flair: p.linkFlairText == null ? null : _flair(cs, p.linkFlairText!),
      thumbnail: _thumb(cs, 72),
      actions: _actions(),
      onTap: _openDetail,
    );
  }

  /// Full-width media constrained to [height] (cover-cropped). Falls back to the
  /// link preview / nothing for non-image posts.
  /// Feed preview URL, using the lower-resolution Reddit preview when the
  /// Data-saver thumbnails setting is enabled.
  String? _cardImg(Post p) {
    final midResThumbnails = ref.watch(
        settingsControllerProvider.select((s) => s.midResThumbnails));
    if (!midResThumbnails) return p.previewUrl;
    return p.previewMedUrl ?? p.thumbnailUrl ?? p.previewUrl;
  }

  Widget _bannerMedia(ColorScheme cs, double height) {
    final p = widget.post;
    if (p.type == PostType.self) return const SizedBox.shrink();
    if (p.type == PostType.link) return _linkPreview(cs);
    final blurNsfw =
        ref.watch(settingsControllerProvider.select((s) => s.blurNsfw));
    final blur = (p.over18 && blurNsfw) || p.spoiler;
    if (p.type == PostType.gallery && p.gallery.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: NsfwBlur(
          blur: blur,
          child: GalleryCarousel(
              images: p.gallery, title: p.title, height: height),
        ),
      );
    }
    final url =
        _cardImg(p) ?? (p.gallery.isNotEmpty ? p.gallery.first.url : null);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * dpr).round().clamp(1, 1080).toInt();
    final cacheHeight = (height * dpr).round().clamp(1, 1080).toInt();
    // Inline autoplay for videos (when enabled and not NSFW-blurred).
    if (p.type == PostType.video &&
        !blur &&
        ref.watch(settingsControllerProvider.select((s) => s.autoplayMedia))) {
      final vurl = p.hlsUrl ?? p.fallbackVideoUrl ?? resolveVideoUrl(p.url);
      if (vurl.isNotEmpty && !vurl.toLowerCase().endsWith('.gif')) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ClipRRect(
            borderRadius: ShapeTokens.large,
            child: InlineVideo(
              key: ValueKey('iv_${p.id}'),
              url: vurl,
              poster: url,
              height: height,
              onTap: _openMedia,
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: NsfwBlur(
        blur: blur,
        child: ClipRRect(
          borderRadius: ShapeTokens.large,
          child: GestureDetector(
            onTap: _openMedia,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url != null)
                    CachedNetworkImage(
                      imageUrl: url,
                      memCacheWidth: cacheWidth,
                      memCacheHeight: cacheHeight,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: cs.surfaceContainerHighest),
                      errorWidget: (_, __, ___) =>
                          Container(color: cs.surfaceContainerHighest),
                    )
                  else
                    Container(color: cs.surfaceContainerHighest),
                  if (p.type == PostType.video)
                    const Center(child: _PlayBadge()),
                  if (p.type == PostType.gallery)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Pill(
                          icon: Icons.collections_rounded,
                          label: '${p.gallery.length}'),
                    ),
                if (p.type == PostType.video)
                  const Positioned(
                    bottom: 8,
                    right: 8,
                    child: _Pill(icon: Icons.videocam_rounded, label: 'VIDEO'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Small square thumbnail for compact / mini layouts (null if no media).
  Widget? _thumb(ColorScheme cs, double size) {
    final p = widget.post;
    if (p.type == PostType.self) return null;
    final url =
        _cardImg(p) ?? (p.gallery.isNotEmpty ? p.gallery.first.url : p.thumbnailUrl);
    final blurNsfw =
        ref.watch(settingsControllerProvider.select((s) => s.blurNsfw));
    final blur = (p.over18 && blurNsfw) || p.spoiler;
    final cacheSize =
        (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 300).toInt();
    return ClipRRect(
      borderRadius: ShapeTokens.small,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && !blur)
              CachedNetworkImage(
                imageUrl: url,
                memCacheWidth: cacheSize,
                memCacheHeight: cacheSize,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: cs.surfaceContainerHighest),
                errorWidget: (_, __, ___) => Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.link_rounded, color: cs.onSurfaceVariant),
                ),
              )
            else
              Container(
                color: cs.surfaceContainerHighest,
                child: Icon(
                    blur
                        ? Icons.visibility_off_rounded
                        : (p.type == PostType.link
                            ? Icons.link_rounded
                            : Icons.image_rounded),
                    color: cs.onSurfaceVariant),
              ),
            if (p.type == PostType.video)
              const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 26),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    final p = widget.post;
    final subreddit = p.subredditPrefixed.isNotEmpty
        ? p.subredditPrefixed
        : 'r/${p.subreddit}';
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => context.push('/r/${p.subreddit}'),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: cs.secondaryContainer,
              child: Text(
                p.subreddit.isNotEmpty ? p.subreddit[0].toUpperCase() : '?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/r/${p.subreddit}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subreddit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'u/${p.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '·  ${timeAgo(p.created)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (p.stickied)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.push_pin_rounded, size: 16, color: cs.primary),
            ),
          if (p.over18)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          const SizedBox(width: 2),
          IconButton(
            onPressed: _showTuneSheet,
            tooltip: 'More actions',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _flair(ColorScheme cs, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: ShapeTokens.extraSmall),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      );

  Widget _media(ColorScheme cs) {
    final p = widget.post;
    final blurNsfw =
        ref.watch(settingsControllerProvider.select((s) => s.blurNsfw));
    final blur = (p.over18 && blurNsfw) || p.spoiler;
    switch (p.type) {
      case PostType.gallery:
        if (p.gallery.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: NsfwBlur(
              blur: blur,
              child: GalleryCarousel(images: p.gallery, title: p.title),
            ),
          );
        }
        return NsfwBlur(blur: blur, child: _mediaPreview(cs));
      case PostType.image:
      case PostType.gif:
      case PostType.video:
        return NsfwBlur(blur: blur, child: _mediaPreview(cs));
      case PostType.link:
        return _linkPreview(cs);
      case PostType.self:
        return const SizedBox.shrink();
    }
  }

  Widget _mediaPreview(ColorScheme cs) {
    final p = widget.post;
    final url = p.previewUrl ?? (p.gallery.isNotEmpty ? p.gallery.first.url : null);
    final renderAspect = boundedMediaAspectRatio(
      width: p.previewWidth,
      height: p.previewHeight,
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * dpr).round().clamp(1, 1080).toInt();
    final cacheHeight =
        (cacheWidth / renderAspect).ceil().clamp(1, 1080).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: ShapeTokens.large,
        child: GestureDetector(
          onTap: _openMedia,
          child: AspectRatio(
            aspectRatio: renderAspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null)
                  CachedNetworkImage(
                    imageUrl: url,
                    memCacheWidth: cacheWidth,
                    memCacheHeight: cacheHeight,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: cs.surfaceContainerHighest),
                    errorWidget: (_, __, ___) => Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.broken_image_outlined,
                          color: cs.onSurfaceVariant),
                    ),
                  )
                else
                  Container(color: cs.surfaceContainerHighest),
                if (p.type == PostType.video)
                  const Center(child: _PlayBadge()),
                if (p.type == PostType.gallery)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _Pill(
                        icon: Icons.collections_rounded,
                        label: '${p.gallery.length}'),
                  ),
                if (p.type == PostType.gif)
                  const Positioned(
                      top: 8, left: 8, child: _Pill(label: 'GIF')),
                if (p.type == PostType.video)
                  const Positioned(
                    bottom: 8,
                    right: 8,
                    child: _Pill(icon: Icons.videocam_rounded, label: 'VIDEO'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linkPreview(ColorScheme cs) {
    final p = widget.post;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: _openMedia,
        borderRadius: ShapeTokens.large,
        child: Container(
          decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: ShapeTokens.large),
          child: Row(
            children: [
              if (p.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(24)),
                  child: CachedNetworkImage(
                    imageUrl: p.thumbnailUrl!,
                    memCacheWidth: (72 * MediaQuery.devicePixelRatioOf(context))
                        .round()
                        .clamp(1, 300)
                        .toInt(),
                    memCacheHeight: (72 * MediaQuery.devicePixelRatioOf(context))
                        .round()
                        .clamp(1, 300)
                        .toInt(),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const SizedBox(width: 72, height: 72),
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  child: Icon(Icons.link_rounded, color: cs.onSurfaceVariant),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(p.domain,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.open_in_new_rounded,
                    size: 18, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    // Only the action bar subscribes to post overrides, keeping card media and
    // title layout stable when a vote or save state changes.
    final ov = ref.watch(
      postOverridesProvider.select((m) => m[widget.post.id]),
    );
    final likes = ov?.likes ?? widget.post.likes;
    final score = ov?.score ?? widget.post.score;
    final saved = ov?.saved ?? widget.post.saved;
    final numComments = ov?.numComments ?? widget.post.numComments;
    final read = ref.watch(historyContainsProvider(widget.post.id));
    return M3EPostActionBar(
      score: score,
      likes: likes,
      commentCount: numComments,
      saved: saved,
      read: read,
      onUpvote: () => _vote(1),
      onDownvote: () => _vote(-1),
      onComment: _openDetail,
      onSave: _toggleSave,
      onShare: () => shareUrl(context, widget.post.url, subject: widget.post.title),
      onRead: () {
        final history = ref.read(historyControllerProvider.notifier);
        read ? history.removeViewed(widget.post.id) : history.markViewed(widget.post);
      },
      onMore: () => showPostActionsSheet(context, ref, widget.post),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.black54, shape: BoxShape.circle),
        child: const Icon(Icons.play_arrow_rounded,
            color: Colors.white, size: 36),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({this.icon, required this.label});
  final IconData? icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: ShapeTokens.extraSmall),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
