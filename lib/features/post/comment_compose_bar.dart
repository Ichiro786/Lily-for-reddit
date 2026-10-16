import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/motion_tokens.dart';
import '../../core/theme/shape_tokens.dart';
import '../media/attachment.dart';
import '../media/attachment_bar.dart';
import '../media/composer_media_menu.dart';
import '../media/composer_media_tray.dart';
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
  final _focusNode = FocusNode();
  bool _trayOpen = false;
  bool _trayRequestedFocus = false;
  MediaAttachment? _media;
  bool _ownsController = false, _readingMedia = false;
  int _generation = 0;
  String? _mediaError;

  bool get _enabled => widget.enabled && !_readingMedia;

  @override
  void initState() {
    super.initState();
    _media = widget.media;
    _focusNode.addListener(_focusChanged);
    _bindController();
  }

  void _bindController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_changed);
  }

  void _closeTray() {
    if (_trayOpen && mounted) setState(() => _trayOpen = false);
  }

  void _focusChanged() {
    if (!_focusNode.hasFocus) return;
    if (_trayRequestedFocus) {
      _trayRequestedFocus = false;
      return;
    }
    _closeTray();
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
      _trayOpen = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _controller.removeListener(_changed);
    if (_ownsController) _controller.dispose();
    _focusNode.removeListener(_focusChanged);
    _focusNode.dispose();
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
        if (widget.enabled) _focusNode.requestFocus();
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
        if (widget.enabled) _focusNode.requestFocus();
      }
    }
  }

  void _toggleTray() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    _trayRequestedFocus = !_focusNode.hasFocus;
    _focusNode.requestFocus();
    setState(() => _trayOpen = !_trayOpen);
  }

  void _select(ComposerMediaAction action) {
    if (!_enabled) return;
    setState(() => _trayOpen = false);
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
    setState(() => _trayOpen = false);
    widget.onSubmit!(text);
    _controller.clear();
    _acceptMedia(null);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _buildBar);

  Widget _buildBar(BuildContext context, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canvas = theme.brightness == Brightness.dark
        ? Colors.black
        : cs.surface;
    final hasContent = _controller.text.trim().isNotEmpty || _media != null;
    // Design decision: cap the tray and let its rows scroll in short windows.
    // The Scaffold already consumes viewInsets; adding them here would lift
    // the composer twice when the keyboard opens.
    final availableHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : math.max(
            72.0,
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                MediaQuery.viewPaddingOf(context).vertical -
                kToolbarHeight,
          );
    final inputStyle = theme.textTheme.bodyMedium!;
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(inputStyle.fontSize!) *
        (inputStyle.height ?? 1.4);
    final previewHeight = _media != null ? 80.0 : 0.0;
    final errorHeight = _mediaError != null ? lineHeight * 3 : 0.0;
    // Leave a scrollable tray viewport even with large text in landscape.
    final maxLines =
        ((availableHeight - 132 - previewHeight - errorHeight) / lineHeight)
            .floor()
            .clamp(1, 4);
    return PopScope(
      canPop: !_trayOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _trayOpen) setState(() => _trayOpen = false);
      },
      child: TextFieldTapRegion(
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(0, availableHeight),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: canvas,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_mediaError != null)
                    Text(
                      _mediaError!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.error),
                    ),
                  if (_media != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AttachmentPreview(
                        media: _media!,
                        onRemove: _enabled ? () => _acceptMedia(null) : null,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                          decoration: BoxDecoration(
                            color: canvas,
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: ShapeTokens.full,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Semantics(
                                expanded: _trayOpen,
                                child: IconButton(
                                  tooltip: _trayOpen
                                      ? 'Close media'
                                      : 'Add media',
                                  onPressed: _enabled ? _toggleTray : null,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 48,
                                    height: 48,
                                  ),
                                  icon: AnimatedRotation(
                                    turns: _trayOpen ? 0.125 : 0,
                                    duration: MotionTokens.feedback(context),
                                    curve: MotionTokens.emphasized,
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 28,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  readOnly: !_enabled,
                                  minLines: 1,
                                  maxLines: maxLines,
                                  keyboardType: TextInputType.multiline,
                                  contentInsertionConfiguration:
                                      ContentInsertionConfiguration(
                                        allowedMimeTypes:
                                            keyboardImageMimeTypes,
                                        onContentInserted: _keyboardContent,
                                      ),
                                  onTap: _closeTray,
                                  onSubmitted: (_) => _handleSend(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    filled: false,
                                    hintText: widget.hintText,
                                    hintStyle: theme.textTheme.bodyMedium
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  textInputAction: TextInputAction.send,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send comment',
                        onPressed:
                            hasContent && _enabled && widget.onSubmit != null
                            ? _handleSend
                            : null,
                        style: IconButton.styleFrom(
                          fixedSize: const Size(56, 56),
                          shape: const CircleBorder(),
                        ),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: ComposerMediaTray(
                      open: _trayOpen,
                      maxHeight: 264,
                      enabled: _enabled,
                      gifEnabled: widget.onPickGif != null,
                      includeNextThread: widget.onJumpNext != null,
                      onSelected: _select,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
