import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/motion_tokens.dart';
import '../../core/widgets/m3e_animated_size.dart';
import '../../core/theme/shape_tokens.dart';
import '../feed/inline_video.dart';
import '../media/media_viewers.dart';
import '../settings/settings_controller.dart';
import 'comment_media_helper.dart';
import 'interactive_spoiler.dart';

/// Built only for visible, expanded sliver children; attachments are never lost
/// by stripping their URLs from Markdown without a matching media renderer.
class CommentContent extends StatefulWidget {
  const CommentContent({
    super.key,
    required this.body,
    required this.styleSheet,
  });
  final String body;
  final MarkdownStyleSheet styleSheet;
  @override
  State<CommentContent> createState() => _CommentContentState();
}

class _CommentContentState extends State<CommentContent> {
  late ParsedCommentContent _content = parseCommentContent(widget.body);

  @override
  void didUpdateWidget(covariant CommentContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      _content = parseCommentContent(widget.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    final text = content.text;
    final media = content.media;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty) buildCommentMarkdownBody(text, widget.styleSheet),
        for (final item in media)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _CommentAttachment(key: ValueKey(item.url), media: item),
          ),
      ],
    );
  }
}

class _CommentAttachment extends ConsumerStatefulWidget {
  const _CommentAttachment({super.key, required this.media});
  final CommentMedia media;
  @override
  ConsumerState<_CommentAttachment> createState() => _CommentAttachmentState();
}

class _CommentAttachmentState extends ConsumerState<_CommentAttachment> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = widget.media;
    final autoplay =
        ref.watch(settingsControllerProvider.select((s) => s.autoplayMedia)) &&
        !MotionTokens.reduced(context);
    void open() => media.isVideo
        ? openVideoViewer(context, media.url, downloadUrl: media.url)
        : openImageViewer(context, media.url);
    return M3EAnimatedSize(
      alignment: Alignment.topCenter,
      child: ClipRRect(
        borderRadius: ShapeTokens.small,
        child: ColoredBox(
          color: cs.surfaceContainerLow,
          child: media.isVideo && autoplay
              ? InlineVideo(url: media.url, height: 200, onTap: open)
              : Semantics(
                  button: true,
                  label: media.isVideo
                      ? 'Play comment video'
                      : media.isGif
                      ? 'Open comment GIF'
                      : 'Open comment image',
                  child: InkWell(
                    onTap: open,
                    child: media.isVideo
                        ? SizedBox(
                            height: 160,
                            width: double.infinity,
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              size: 48,
                              color: cs.primary,
                            ),
                          )
                        : ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.sizeOf(context).height * 0.6,
                            ),
                            child: TickerMode(
                              enabled: autoplay || !media.isGif,
                              child: CachedNetworkImage(
                                key: ValueKey('${media.url}:$_attempt'),
                                imageUrl: media.url,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                memCacheWidth:
                                    (MediaQuery.sizeOf(context).width *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .round()
                                        .clamp(1, 1080),
                                placeholder: (_, __) => SizedBox(
                                  height: 160,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => SizedBox(
                                  height: 80,
                                  child: Center(
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          setState(() => _attempt++),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Retry media'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
        ),
      ),
    );
  }
}
