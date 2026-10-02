import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/m3e_loading_indicator.dart';

import 'attachment.dart';
import 'composer_media_menu.dart';

/// Reusable composer attachment UI: a pending-attachment preview plus a row of
/// pick-image / pick-video / paste buttons. The parent owns the
/// current [media] and is notified via [onChanged] / [onError].
class AttachmentControls extends StatefulWidget {
  const AttachmentControls({
    super.key,
    required this.media,
    required this.onChanged,
    required this.onError,
    this.leading = const [],
    this.catboxForImages = false,
    this.enabled = true,
    this.onBusyChanged,
    this.imagePicker = pickImageAttachment,
    this.videoPicker = pickVideoAttachment,
    this.imagePaster = pasteImageAttachment,
    this.onGif,
    this.compactMenu = false,
  });

  final MediaAttachment? media;
  final ValueChanged<MediaAttachment?> onChanged;
  final ValueChanged<String> onError;

  /// Extra buttons shown before the attach buttons (e.g. a GIF button).
  final List<Widget> leading;

  /// When true, even images are hosted on Catbox (used in messages, which can't
  /// carry Reddit-hosted media). When false, images go inline via Reddit.
  final bool catboxForImages;

  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;
  final Future<MediaAttachment?> Function() imagePicker;
  final Future<MediaAttachment?> Function() videoPicker;
  final Future<MediaAttachment?> Function() imagePaster;
  final VoidCallback? onGif;
  final bool compactMenu;
  @override
  State<AttachmentControls> createState() => _AttachmentControlsState();
}

class _AttachmentControlsState extends State<AttachmentControls> {
  String? _pending;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant AttachmentControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _generation++;
      _pending = null;
    }
  }

  Future<void> _pick(
    String action,
    Future<MediaAttachment?> Function() read, {
    String? emptyMsg,
  }) async {
    if (!widget.enabled || _pending != null) return;
    final generation = ++_generation;
    setState(() => _pending = action);
    widget.onBusyChanged?.call(true);
    try {
      final media = await read();
      if (!mounted || generation != _generation || !widget.enabled) return;
      if (media == null) {
        if (emptyMsg != null) widget.onError(emptyMsg);
      } else {
        widget.onChanged(media);
      }
    } catch (error) {
      if (!mounted || generation != _generation || !widget.enabled) return;
      final message = switch (error) {
        UnsupportedError e =>
          e.message?.toString() ?? 'This attachment is unavailable.',
        MissingPluginException() =>
          'This attachment option is unavailable. Try choosing a file.',
        PlatformException e when e.code == 'clipboard_too_large' =>
          'Choose an image smaller than 20 MB.',
        PlatformException e when e.code == 'clipboard_denied' =>
          'Copy the image again or use Attach image.',
        _ => 'Could not attach that file. Please try again.',
      };
      widget.onError(message);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _pending = null);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  Widget _button(
    String label,
    IconData icon,
    Future<MediaAttachment?> Function() read, {
    String? emptyMsg,
  }) => IconButton(
    tooltip: label,
    onPressed: widget.enabled && _pending == null
        ? () => _pick(label, read, emptyMsg: emptyMsg)
        : null,
    icon: _pending == label ? const M3ELoadingIndicator.small() : Icon(icon),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.media != null) ...[
          AttachmentPreview(
            media: widget.media!,
            onRemove: widget.enabled ? () => widget.onChanged(null) : null,
          ),
          const SizedBox(height: 4),
        ],
        if (widget.compactMenu)
          Align(
            alignment: Alignment.centerLeft,
            child: ComposerMediaMenuButton(
              enabled: widget.enabled && _pending == null,
              includePaste: true,
              onSelected: (action) {
                switch (action) {
                  case ComposerMediaAction.photo:
                    _pick('Attach image', widget.imagePicker);
                  case ComposerMediaAction.video:
                    _pick('Attach video', widget.videoPicker);
                  case ComposerMediaAction.gif:
                    widget.onGif?.call();
                  case ComposerMediaAction.paste:
                    _pick(
                      'Paste image',
                      widget.imagePaster,
                      emptyMsg: 'No image on the clipboard.',
                    );
                  case ComposerMediaAction.nextThread:
                    break;
                }
              },
            ),
          )
        else
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...widget.leading,
              _button('Attach image', Icons.image_outlined, widget.imagePicker),
              _button(
                'Attach video',
                Icons.videocam_outlined,
                widget.videoPicker,
              ),
              _button(
                'Paste image',
                Icons.content_paste_rounded,
                widget.imagePaster,
                emptyMsg: 'No image on the clipboard.',
              ),
            ],
          ),
        if (widget.media != null)
          Text(
            _noteFor(widget.media!),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
      ],
    );
  }

  String _noteFor(MediaAttachment media) =>
      media.isVideo || widget.catboxForImages
      ? 'Will be uploaded to catbox.moe and linked (public).'
      : 'Image posts inline (hosted by Reddit; some subs disallow it — falls back to a catbox.moe link).';
}

/// Small inline preview of a pending attachment with a remove button.
class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    super.key,
    required this.media,
    required this.onRemove,
  });
  final MediaAttachment media;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: media.isVideo
                ? Container(
                    width: 48,
                    height: 48,
                    color: cs.surfaceContainerHigh,
                    child: Icon(
                      Icons.movie_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : Image.memory(
                    media.bytes,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    cacheWidth: 144,
                    cacheHeight: 144,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.isVideo ? 'Video' : 'Image',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  media.sizeLabel,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
