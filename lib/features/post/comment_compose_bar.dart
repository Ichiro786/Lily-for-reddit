import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/shape_tokens.dart';

class CommentComposeBar extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmit;
  final ValueChanged<XFile?>? onImageSelected;
  final VoidCallback? onJumpNext;
  final String hintText;

  const CommentComposeBar({
    super.key,
    this.controller,
    this.onSubmit,
    this.onImageSelected,
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

  @override
  void initState() {
    super.initState();
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
    HapticFeedback.selectionClick();
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (mounted && picked != null) {
        setState(() => _selectedImage = picked);
        widget.onImageSelected?.call(picked);
      }
    } catch (_) {}
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty || _selectedImage != null) {
      HapticFeedback.mediumImpact();
      widget.onSubmit?.call(text);
      _controller.clear();
      setState(() => _selectedImage = null);
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
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Attach image',
                          onPressed: _pickImage,
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
