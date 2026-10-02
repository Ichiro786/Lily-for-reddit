import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/widgets/m3e_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drafts.dart';
import '../../core/theme/motion_tokens.dart';
import '../auth/auth_controller.dart';
import 'comment_content.dart';
import 'interactive_spoiler.dart';
import 'reply_editor.dart';
import 'reply_submission.dart';
import '../../core/providers.dart';
import '../../models/comment.dart';
import '../media/attachment.dart';
import '../media/keyboard_media.dart';
import '../media/attachment_bar.dart';
import '../media/giphy_picker.dart';

/// Opens a reply composer. Returns the created [Comment] on success.
///
/// Supports attaching an image (posted inline via Reddit's richtext where the
/// subreddit allows it) or a video (uploaded to Catbox and linked).
Future<Comment?> showReplySheet(
  BuildContext context,
  WidgetRef ref, {
  required String parentFullname,
  required int parentDepth,
  String? replyingTo,
}) {
  final repo = ref.read(redditRepositoryProvider);
  final container = ProviderScope.containerOf(context, listen: false);
  final epoch = container.read(authSessionEpochProvider);
  void requireSession() {
    if (container.read(authSessionEpochProvider) != epoch ||
        container.read(authTransitionProvider)) {
      throw StateError('Account changed');
    }
  }

  return showModalBottomSheet<Comment>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    requestFocus: false,
    sheetAnimationStyle: MotionTokens.reduced(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            curve: Cubic(0.2, 0.0, 0.0, 1.0),
            duration: Duration(milliseconds: 300),
          ),
    builder: (ctx) => _ComposeSheet(
      title: replyingTo == null ? 'Reply' : 'Reply to u/$replyingTo',
      submitLabel: 'Reply',
      allowAttachments: true,
      draftKey: 'reply_$parentFullname',
      onSubmitMedia: (text, media) => submitMediaReply(
        repository: repo,
        parentFullname: parentFullname,
        text: text,
        depth: parentDepth + 1,
        media: media,
        requireSession: requireSession,
      ),
    ),
  );
}

/// Opens an editor for your own post/comment body. Returns the new text.
Future<String?> showEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required String thingFullname,
  required String initialText,
}) {
  final repo = ref.read(redditRepositoryProvider);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    requestFocus: false,
    sheetAnimationStyle: MotionTokens.reduced(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(duration: Duration(milliseconds: 300)),
    builder: (ctx) => _ComposeSheet(
      title: 'Edit',
      submitLabel: 'Save',
      initialText: initialText,
      onSubmit: (text) async {
        await repo.editText(thingFullname: thingFullname, text: text);
        return text;
      },
    ),
  );
}

final replyGifPickerProvider =
    Provider<Future<String?> Function(BuildContext, WidgetRef)>(
      (ref) => showGiphyPicker,
    );

class _ComposeSheet<T> extends ConsumerStatefulWidget {
  const _ComposeSheet({
    required this.title,
    required this.submitLabel,
    this.onSubmit,
    this.onSubmitMedia,
    this.allowAttachments = false,
    this.initialText,
    this.draftKey,
  }) : assert(onSubmit != null || onSubmitMedia != null);
  final String title, submitLabel;
  final String? initialText, draftKey;
  final bool allowAttachments;
  final Future<T> Function(String)? onSubmit;
  final Future<T> Function(String, MediaAttachment?)? onSubmitMedia;
  @override
  ConsumerState<_ComposeSheet<T>> createState() => _ComposeSheetState<T>();
}

class _ComposeSheetState<T> extends ConsumerState<_ComposeSheet<T>>
    with WidgetsBindingObserver {
  late final Drafts _drafts;
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  Animation<double>? _entrance;
  Timer? _saveTimer;
  late String _savedText;
  late final int _epoch;
  bool _focused = false,
      _busy = false,
      _preview = false,
      _pickingGif = false,
      _attaching = false,
      _readingKeyboard = false,
      _submitted = false;
  String? _error;
  MediaAttachment? _media;

  @override
  void initState() {
    super.initState();
    _epoch = ref.read(authSessionEpochProvider);
    _drafts = ref.read(draftsProvider);
    _savedText =
        widget.initialText ??
        (widget.draftKey == null ? '' : _drafts.get(widget.draftKey!) ?? '');
    _controller = TextEditingController(text: _savedText)
      ..addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (_entrance != animation) {
      _entrance?.removeStatusListener(_routeStatus);
      _entrance = animation;
      _entrance?.addStatusListener(_routeStatus);
    }
    if (animation == null || animation.status == AnimationStatus.completed) {
      _focusAfterEntry();
    }
  }

  void _routeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _focusAfterEntry();
  }

  void _focusAfterEntry() {
    if (_focused) return;
    _focused = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_preview) _focusNode.requestFocus();
    });
  }

  void _changed() {
    if (_controller.text == _savedText) return;
    _savedText = _controller.text;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), _saveNow);
    if (_preview) setState(() {});
  }

  void _saveNow() {
    _saveTimer?.cancel();
    if (!_submitted && widget.draftKey != null) {
      unawaited(_drafts.save(widget.draftKey!, _controller.text));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _saveNow();
  }

  @override
  void dispose() {
    _saveNow();
    _saveTimer?.cancel();
    _entrance?.removeStatusListener(_routeStatus);
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _insertGif() async {
    if (_busy || _pickingGif || _attaching || _readingKeyboard) return;
    setState(() => _pickingGif = true);
    try {
      final url = await ref.read(replyGifPickerProvider)(context, ref);
      if (!mounted || url == null) return;
      insertReplyGif(_controller, url);
      _error = null;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the GIF picker. Try again.');
      }
    } finally {
      if (mounted) setState(() => _pickingGif = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _pickingGif || _attaching || _readingKeyboard) return;
    final text = _controller.text.trim();
    final draftText = _controller.text;
    if (text.isEmpty && _media == null) return;
    if (ref.read(authSessionEpochProvider) != _epoch ||
        ref.read(authTransitionProvider)) {
      setState(
        () =>
            _error = 'Your account changed. Reopen this reply before sending.',
      );
      return;
    }
    _saveNow();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = widget.onSubmitMedia != null
          ? await widget.onSubmitMedia!(text, _media)
          : await widget.onSubmit!(text);
      _submitted = true;
      _saveTimer?.cancel();
      if (widget.draftKey != null &&
          _drafts.get(widget.draftKey!) == draftText) {
        await _drafts.clear(widget.draftKey!).catchError((Object _) {});
      }
      if (mounted) {
        if (ref.read(authSessionEpochProvider) != _epoch ||
            ref.read(authTransitionProvider)) {
          Navigator.pop(context);
        } else {
          Navigator.pop(context, result);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Could not send this reply. Your text is kept; please try again.';
        });
      }
    }
  }

  Future<void> _insertKeyboardContent(KeyboardInsertedContent content) async {
    if (_busy || _pickingGif || _attaching || _readingKeyboard) return;
    setState(() => _readingKeyboard = true);
    try {
      final media = await readKeyboardAttachment(content);
      if (!mounted) return;
      setState(() {
        _media = media;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = keyboardAttachmentError(error));
    } finally {
      if (mounted) setState(() => _readingKeyboard = false);
    }
  }

  void _format(String before, String after) {
    insertReplyMarkdown(_controller, before, after);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = math.max(
      0.0,
      MediaQuery.sizeOf(context).height -
          bottom -
          MediaQuery.paddingOf(context).top -
          48,
    );
    final enabled = !_busy && !_pickingGif && !_attaching && !_readingKeyboard;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: _preview ? 'Write reply' : 'Preview Markdown',
                      onPressed: enabled
                          ? () {
                              setState(() => _preview = !_preview);
                              if (_preview) {
                                _focusNode.unfocus();
                              } else {
                                _focusNode.requestFocus();
                              }
                            }
                          : null,
                      icon: Icon(
                        _preview
                            ? Icons.edit_rounded
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_preview)
                  RepaintBoundary(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _controller.text.trim().isEmpty
                          ? const Text('Nothing to preview yet.')
                          : CommentContent(
                              body: _controller.text,
                              styleSheet: buildM3EMarkdownStyleSheet(theme),
                            ),
                    ),
                  )
                else ...[
                  TextField(
                    key: const ValueKey('reply-markdown-input'),
                    controller: _controller,
                    focusNode: _focusNode,
                    readOnly: !enabled,
                    contentInsertionConfiguration: widget.allowAttachments
                        ? ContentInsertionConfiguration(
                            allowedMimeTypes: keyboardImageMimeTypes,
                            onContentInserted: _insertKeyboardContent,
                          )
                        : null,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'Markdown supported',
                    ),
                  ),
                  Wrap(
                    children: [
                      for (final item in [
                        (Icons.format_bold_rounded, 'Bold', '**', '**'),
                        (Icons.format_italic_rounded, 'Italic', '*', '*'),
                        (Icons.code_rounded, 'Inline code', '`', '`'),
                        (Icons.visibility_off_outlined, 'Spoiler', '>!', '!<'),
                      ])
                        IconButton(
                          tooltip: item.$2,
                          icon: Icon(item.$1, size: 20),
                          onPressed: enabled
                              ? () => _format(item.$3, item.$4)
                              : null,
                        ),
                    ],
                  ),
                ],
                if (widget.allowAttachments)
                  AttachmentControls(
                    media: _media,
                    compactMenu: true,
                    onGif: _insertGif,
                    enabled: !_busy && !_pickingGif && !_readingKeyboard,
                    onBusyChanged: (busy) => setState(() => _attaching = busy),
                    onChanged: (media) => setState(() {
                      _media = media;
                      _error = null;
                    }),
                    onError: (message) => setState(() => _error = message),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: enabled ? _insertGif : null,
                      icon: const Icon(Icons.gif_box_outlined),
                      label: const Text('GIF'),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: enabled ? _submit : null,
                  icon: _busy
                      ? const M3ELoadingIndicator.small()
                      : const Icon(Icons.send_rounded),
                  label: Text(_busy ? 'Sending…' : widget.submitLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
