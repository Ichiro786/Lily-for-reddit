import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/shape_tokens.dart';
import '../media/attachment.dart';
import '../media/attachment_bar.dart';
import '../media/composer_media_menu.dart';
import '../media/keyboard_media.dart';
import 'reply_editor.dart';

class CommentComposeBar extends StatefulWidget {
  const CommentComposeBar({
    super.key,
    this.controller,
    this.onSubmit,
    this.onImageSelected,
    this.onMediaSelected,
    this.media,
    this.onJumpNext,
    this.onPickGif,
    this.enabled = true,
    this.imagePicker = pickImageAttachment,
    this.videoPicker = pickVideoAttachment,
    this.hintText = 'Add a comment...',
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onSubmit;
  final ValueChanged<XFile?>? onImageSelected;
  final ValueChanged<MediaAttachment?>? onMediaSelected;
  final MediaAttachment? media;
  final VoidCallback? onJumpNext;
  final Future<String?> Function()? onPickGif;
  final Future<MediaAttachment?> Function() imagePicker, videoPicker;
  final bool enabled;
  final String hintText;

  @override
  State<CommentComposeBar> createState() => _CommentComposeBarState();
}

class _CommentComposeBarState extends State<CommentComposeBar> {
  late TextEditingController _controller;
  MediaAttachment? _media;
  bool _ownsController = false, _readingMedia = false;
  int _generation = 0;
  String? _mediaError;

  bool get _enabled => widget.enabled && !_readingMedia;

  @override
  void initState() {
    super.initState();
    _media = widget.media;
    _bindController();
  }

  void _bindController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant CommentComposeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_changed);
      if (_ownsController) _controller.dispose();
      _bindController();
    }
    if (widget.media != oldWidget.media) _media = widget.media;
    if (!widget.enabled && oldWidget.enabled) {
      _generation++;
      _readingMedia = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _controller.removeListener(_changed);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _acceptMedia(MediaAttachment? media) {
    setState(() {
      _media = media;
      _mediaError = null;
    });
    if (widget.onMediaSelected != null) {
      widget.onMediaSelected!(media);
    } else {
      widget.onImageSelected?.call(
        media == null
            ? null
            : XFile.fromData(
                media.bytes,
                name: media.filename,
                mimeType: media.mimeType,
              ),
      );
    }
  }

  Future<void> _readMedia(Future<MediaAttachment?> Function() read) async {
    if (!_enabled) return;
    final generation = ++_generation;
    setState(() => _readingMedia = true);
    try {
      final media = await read();
      if (mounted &&
          widget.enabled &&
          generation == _generation &&
          media != null) {
        _acceptMedia(media);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _mediaError = keyboardAttachmentError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _readingMedia = false);
      }
    }
  }

  Future<void> _keyboardContent(KeyboardInsertedContent content) =>
      _readMedia(() => readKeyboardAttachment(content));

  Future<void> _insertGif() async {
    if (!_enabled || widget.onPickGif == null) return;
    final generation = ++_generation;
    setState(() => _readingMedia = true);
    try {
      final url = await widget.onPickGif!();
      if (mounted &&
          widget.enabled &&
          generation == _generation &&
          url != null) {
        insertReplyGif(_controller, url);
        setState(() => _mediaError = null);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _mediaError = 'Could not open GIPHY. Please try again.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _readingMedia = false);
      }
    }
  }

  void _select(ComposerMediaAction action) {
    switch (action) {
      case ComposerMediaAction.photo:
        _readMedia(widget.imagePicker);
      case ComposerMediaAction.video:
        _readMedia(widget.videoPicker);
      case ComposerMediaAction.gif:
        _insertGif();
      case ComposerMediaAction.paste:
        _readMedia(pasteImageAttachment);
      case ComposerMediaAction.nextThread:
        widget.onJumpNext?.call();
    }
  }

  void _handleSend() {
    if (!_enabled || widget.onSubmit == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _media == null) return;
    HapticFeedback.selectionClick();
    widget.onSubmit!(text);
    _controller.clear();
    _acceptMedia(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasContent = _controller.text.trim().isNotEmpty || _media != null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: cs.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mediaError != null)
              Text(_mediaError!, style: TextStyle(color: cs.error)),
            if (_media != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AttachmentPreview(
                  media: _media!,
                  onRemove: _enabled ? () => _acceptMedia(null) : null,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: ShapeTokens.full,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            readOnly: !_enabled,
                            contentInsertionConfiguration:
                                ContentInsertionConfiguration(
                                  allowedMimeTypes: keyboardImageMimeTypes,
                                  onContentInserted: _keyboardContent,
                                ),
                            onSubmitted: (_) => _handleSend(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                            ),
                            decoration: InputDecoration(
                              filled: false,
                              hintText: widget.hintText,
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        if (hasContent)
                          IconButton(
                            tooltip: 'Send comment',
                            onPressed: _enabled && widget.onSubmit != null
                                ? _handleSend
                                : null,
                            icon: Icon(Icons.send_rounded, color: cs.primary),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ComposerMediaMenuButton(
                  enabled: _enabled,
                  includeNextThread: widget.onJumpNext != null,
                  onSelected: _select,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
