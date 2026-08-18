import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
        });
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
      setState(() {
        _selectedImage = null;
      });
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          alignment: Alignment.center,
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
                              setState(() {
                                _selectedImage = null;
                              });
                              widget.onImageSelected?.call(null);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: Colors.white,
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
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.hintText,
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _handleSend(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          iconSize: 20,
                          color: colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          onPressed: _pickImage,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                // Hide Jump FAB completely when keyboard is open to prevent collision
                if (!isKeyboardOpen && widget.onJumpNext != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton.filledTonal(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        widget.onJumpNext?.call();
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurface,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                      ),
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
