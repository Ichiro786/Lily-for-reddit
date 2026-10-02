import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/shape_tokens.dart';
import '../media/attachment.dart';
import '../media/keyboard_media.dart';

class CommentComposeBar extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmit;
  final ValueChanged<XFile?>? onImageSelected;
  final ValueChanged<MediaAttachment?>? onMediaSelected;
  final MediaAttachment? media;
  final VoidCallback? onJumpNext;
  final String hintText;

  const CommentComposeBar({
    super.key,
    this.controller,
    this.onSubmit,
    this.onImageSelected,
    this.onMediaSelected,
    this.media,
    this.onJumpNext,
    this.hintText = 'Add a comment...',
  });

  @override
  State<CommentComposeBar> createState() => _CommentComposeBarState();
}

class _CommentComposeBarState extends State<CommentComposeBar> {
  late final TextEditingController _controller;
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isInternalController = false;
  bool _readingMedia = false;
  String? _mediaError;

  @override
  void didUpdateWidget(covariant CommentComposeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.media != oldWidget.media) {
      final media = widget.media;
      _selectedImage = media == null
          ? null
          : XFile.fromData(
              media.bytes,
              name: media.filename,
              mimeType: media.mimeType,
            );
    }
  }

  void _acceptMedia(MediaAttachment media) {
    final file = XFile.fromData(
      media.bytes,
      name: media.filename,
      mimeType: media.mimeType,
    );
    setState(() {
      _selectedImage = file;
      _mediaError = null;
    });
    if (widget.onMediaSelected != null) {
      widget.onMediaSelected!(media);
    } else {
      widget.onImageSelected?.call(file);
    }
  }

  Future<void> _keyboardContent(KeyboardInsertedContent content) async {
    if (_readingMedia) return;
    setState(() => _readingMedia = true);
    try {
      final media = await readKeyboardAttachment(content);
      if (mounted) _acceptMedia(media);
    } catch (error) {
      if (mounted) setState(() => _mediaError = keyboardAttachmentError(error));
    } finally {
      if (mounted) setState(() => _readingMedia = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final media = widget.media;
    if (media != null) {
      _selectedImage = XFile.fromData(
        media.bytes,
        name: media.filename,
        mimeType: media.mimeType,
      );
    }
    if (widget.controller == null) {
      _controller = TextEditingController();
      _isInternalController = true;
    } else {
      _controller = widget.controller!;
    }
  }

  @override
  void dispose() {
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_readingMedia) return;
    setState(() => _readingMedia = true);
    HapticFeedback.selectionClick();
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (mounted && picked != null) {
        final bytes = await picked.readAsBytes();
        if (mounted) {
          _acceptMedia(
            MediaAttachment(
              bytes: bytes,
              filename: picked.name,
              mimeType:
                  picked.mimeType ?? imageMimeTypeForFilename(picked.name),
              isVideo: false,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _mediaError = 'Could not attach that image. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _readingMedia = false);
    }
  }

  void _handleSend() {
    if (_readingMedia || widget.onSubmit == null) return;
    final text = _controller.text.trim();
    if (text.isNotEmpty || _selectedImage != null) {
      HapticFeedback.mediumImpact();
      widget.onSubmit?.call(text);
      _controller.clear();
      setState(() => _selectedImage = null);
      widget.onMediaSelected?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
        // Floating controls share the active scaffold canvas.
        decoration: BoxDecoration(color: colorScheme.surface),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mediaError != null)
              Text(_mediaError!, style: TextStyle(color: colorScheme.error)),
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.image_rounded,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedImage = null);
                              widget.onImageSelected?.call(null);
                              widget.onMediaSelected?.call(null);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: colorScheme.onError,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    // Canonical filled-input surface from the app's
                    // InputDecorationTheme family.
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: ShapeTokens.full,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            contentInsertionConfiguration:
                                ContentInsertionConfiguration(
                                  allowedMimeTypes: keyboardImageMimeTypes,
                                  onContentInserted: _keyboardContent,
                                ),
                            onSubmitted: (_) => _handleSend(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              filled: false,
                              hintText: widget.hintText,
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
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
                        IconButton(
                          tooltip: 'Attach image',
                          onPressed: _readingMedia ? null : _pickImage,
                          icon: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 22,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isKeyboardOpen && widget.onJumpNext != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 24,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        widget.onJumpNext?.call();
                      },
                      tooltip: 'Next comment thread',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
