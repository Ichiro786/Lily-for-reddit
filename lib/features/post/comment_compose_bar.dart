import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/shape_tokens.dart';
import '../media/attachment.dart';

class M3ECommentComposeBar extends StatefulWidget {
  const M3ECommentComposeBar({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.replyingTo,
  });

  final FutureOr<void> Function(String text, MediaAttachment? attachment) onSend;
  final Future<MediaAttachment?> Function() onAttach;
  final String? replyingTo;

  @override
  State<M3ECommentComposeBar> createState() => _M3ECommentComposeBarState();
}

class _M3ECommentComposeBarState extends State<M3ECommentComposeBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _sending = false;
  MediaAttachment? _attachment;

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

  Future<void> _pickAttachment() async {
    if (_sending) return;
    final attachment = await widget.onAttach();
    if (!mounted || attachment == null) return;
    setState(() => _attachment = attachment);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _attachment == null) || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text, _attachment);
      if (mounted) {
        _controller.clear();
        _attachment = null;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachment != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: ShapeTokens.extraSmall,
                        child: Image.memory(
                          _attachment!.bytes,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                      Positioned(
                        top: -7,
                        right: -7,
                        child: Material(
                          color: colorScheme.error,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _sending
                                ? null
                                : () => setState(() => _attachment = null),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colorScheme.onError,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
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
                          onPressed: _sending ? null : _pickAttachment,
                          tooltip: 'Attach image from gallery',
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
          ],
        ),
      ),
    );
  }
}
