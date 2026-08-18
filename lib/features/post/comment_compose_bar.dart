import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/shape_tokens.dart';

class M3ECommentComposeBar extends StatefulWidget {
  const M3ECommentComposeBar({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.replyingTo,
  });

  final FutureOr<void> Function(String text) onSend;
  final VoidCallback onAttach;
  final String? replyingTo;

  @override
  State<M3ECommentComposeBar> createState() => _M3ECommentComposeBarState();
}

class _M3ECommentComposeBarState extends State<M3ECommentComposeBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      if (mounted) {
        _controller.clear();
        _focusNode.unfocus();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send comment: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final hint = widget.replyingTo == null
        ? 'Add a comment...'
        : 'Reply to u/${widget.replyingTo}...';

    return Material(
      color: colorScheme.surfaceContainerHigh,
      elevation: 8,
      borderOnForeground: true,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Material(
                color: colorScheme.surfaceContainerLowest,
                shape: const RoundedRectangleBorder(
                  borderRadius: ShapeTokens.full,
                ),
                clipBehavior: Clip.antiAlias,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      onPressed: _sending ? null : widget.onAttach,
                      tooltip: 'Attach image or GIF',
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: colorScheme.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                onPressed: _sending ? null : _send,
                tooltip: 'Send comment',
                color: colorScheme.onPrimary,
                icon: _sending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
