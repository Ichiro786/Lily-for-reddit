import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/widgets/m3e_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/drafts.dart';
import '../../core/providers.dart';
import '../../models/flair.dart';
import '../media/giphy_picker.dart';
import '../media/attachment.dart';

enum _Kind { text, link, image, gallery, video }

final postMediaPickerProvider = Provider<ImagePicker>((ref) => ImagePicker());
final postGifPickerProvider =
    Provider<Future<String?> Function(BuildContext, WidgetRef)>(
      (ref) => showGiphyPicker,
    );

class ComposePostScreen extends ConsumerStatefulWidget {
  const ComposePostScreen({super.key, this.initialSubreddit});
  final String? initialSubreddit;

  @override
  ConsumerState<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends ConsumerState<ComposePostScreen> {
  late final _subreddit = TextEditingController(
    text: widget.initialSubreddit ?? '',
  );
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _url = TextEditingController();

  _Kind _kind = _Kind.text;
  XFile? _image;
  List<XFile> _gallery = [];
  XFile? _video;
  bool _nsfw = false;
  bool _spoiler = false;
  bool _sendReplies = true;
  bool _busy = false;
  String? _error;

  List<Flair> _flairs = [];
  Flair? _flair;
  String _flairsFor = '';
  int _flairRevision = 0;
  int _pickerRevision = 0;

  static const _draftKey = 'compose_post';

  @override
  void initState() {
    super.initState();
    final raw = ref.read(draftsProvider).get(_draftKey);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map;
        if ((widget.initialSubreddit ?? '').isEmpty) {
          _subreddit.text = m['sr'] ?? '';
        }
        _title.text = m['title'] ?? '';
        _body.text = m['body'] ?? '';
        _url.text = m['url'] ?? '';
        final ki = (m['kind'] as num?)?.toInt();
        if (ki != null && ki >= 0 && ki < _Kind.values.length) {
          _kind = _Kind.values[ki];
        }
        _hasDraft =
            _title.text.trim().isNotEmpty ||
            _body.text.trim().isNotEmpty ||
            _url.text.trim().isNotEmpty ||
            _subreddit.text.trim().isNotEmpty;
      } catch (_) {
        /* ignore malformed draft */
      }
    }
    if (_subreddit.text.trim().isNotEmpty) _loadFlairs();
  }

  bool _hasDraft = false;

  bool get _hasMedia => _image != null || _gallery.isNotEmpty || _video != null;

  void _saveDraft() {
    ref
        .read(draftsProvider)
        .save(
          _draftKey,
          jsonEncode({
            'sr': _subreddit.text,
            'title': _title.text,
            'body': _body.text,
            'url': _url.text,
            'kind': _kind.index,
          }),
        );
    final has =
        _subreddit.text.trim().isNotEmpty ||
        _title.text.trim().isNotEmpty ||
        _body.text.trim().isNotEmpty ||
        _url.text.trim().isNotEmpty;
    if (has != _hasDraft) setState(() => _hasDraft = has);
  }

  @override
  void dispose() {
    _flairRevision++;
    _pickerRevision++;
    _subreddit.dispose();
    _title.dispose();
    _body.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _loadFlairs() async {
    final sr = _subreddit.text.trim();
    if (sr == _flairsFor) return;
    final revision = ++_flairRevision;
    _flairsFor = sr;
    _flairs = [];
    _flair = null;
    if (sr.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final flairs = await ref.read(redditRepositoryProvider).getLinkFlairs(sr);
      if (!mounted ||
          revision != _flairRevision ||
          sr != _subreddit.text.trim()) {
        return;
      }
      setState(() {
        _flairs = flairs;
        _flair = null;
      });
    } catch (_) {
      if (mounted && revision == _flairRevision) {
        setState(() {
          _flairsFor = '';
          _error = 'Could not load subreddit flairs. Please try again.';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    if (_busy) return;
    final revision = ++_pickerRevision;
    try {
      final picked = await ref
          .read(postMediaPickerProvider)
          .pickImage(source: ImageSource.gallery);
      if (mounted &&
          revision == _pickerRevision &&
          _kind == _Kind.image &&
          picked != null) {
        setState(() => _image = picked);
      }
    } catch (_) {
      _pickerError(revision);
    }
  }

  Future<void> _pickGallery() async {
    if (_busy) return;
    final revision = ++_pickerRevision;
    try {
      final picked = await ref.read(postMediaPickerProvider).pickMultiImage();
      if (mounted &&
          revision == _pickerRevision &&
          _kind == _Kind.gallery &&
          picked.isNotEmpty) {
        setState(() => _gallery = picked);
      }
    } catch (_) {
      _pickerError(revision);
    }
  }

  Future<void> _pickVideo() async {
    if (_busy) return;
    final revision = ++_pickerRevision;
    try {
      final picked = await ref
          .read(postMediaPickerProvider)
          .pickVideo(source: ImageSource.gallery);
      if (mounted &&
          revision == _pickerRevision &&
          _kind == _Kind.video &&
          picked != null) {
        setState(() => _video = picked);
      }
    } catch (_) {
      _pickerError(revision);
    }
  }

  Future<void> _insertGif() async {
    if (_busy) return;
    final revision = ++_pickerRevision;
    try {
      final url = await ref.read(postGifPickerProvider)(context, ref);
      if (!mounted ||
          revision != _pickerRevision ||
          _kind != _Kind.text ||
          url == null) {
        return;
      }
      final sep = _body.text.isEmpty ? '' : '\n';
      setState(() => _body.text = '${_body.text}$sep$url');
      _saveDraft();
    } catch (_) {
      _pickerError(revision);
    }
  }

  void _pickerError(int revision) {
    if (mounted && revision == _pickerRevision) {
      setState(
        () => _error = 'Could not open the media picker. Please try again.',
      );
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final sr = _subreddit.text.trim();
    final title = _title.text.trim();
    if (sr.isEmpty || title.isEmpty) {
      setState(() => _error = 'Subreddit and title are required.');
      return;
    }
    if (_kind == _Kind.link && _url.text.trim().isEmpty) {
      setState(() => _error = 'Enter a URL for a link post.');
      return;
    }
    if (_kind == _Kind.image && _image == null) {
      setState(() => _error = 'Pick an image to upload.');
      return;
    }
    if (_kind == _Kind.gallery && _gallery.isEmpty) {
      setState(() => _error = 'Pick at least one image.');
      return;
    }
    if (_kind == _Kind.video && _video == null) {
      setState(() => _error = 'Pick a video to upload.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(redditRepositoryProvider);
    try {
      switch (_kind) {
        case _Kind.text:
          final id = await repo.submitPost(
            subreddit: sr,
            title: title,
            kind: 'self',
            text: _body.text.trim(),
            nsfw: _nsfw,
            spoiler: _spoiler,
            sendReplies: _sendReplies,
            flair: _flair,
          );
          _goToPost(sr, id);
        case _Kind.link:
          final id = await repo.submitPost(
            subreddit: sr,
            title: title,
            kind: 'link',
            url: _url.text.trim(),
            nsfw: _nsfw,
            spoiler: _spoiler,
            sendReplies: _sendReplies,
            flair: _flair,
          );
          _goToPost(sr, id);
        case _Kind.image:
          final url = await repo.uploadImage(
            bytes: await _image!.readAsBytes(),
            filename: _image!.name,
            mimeType:
                _image!.mimeType ?? imageMimeTypeForFilename(_image!.name),
          );
          final id = await repo.submitPost(
            subreddit: sr,
            title: title,
            kind: 'image',
            url: url,
            nsfw: _nsfw,
            spoiler: _spoiler,
            sendReplies: _sendReplies,
            flair: _flair,
          );
          _goToPost(sr, id);
        case _Kind.gallery:
          final mediaIds = <String>[];
          for (final img in _gallery) {
            final asset = await repo.uploadMediaAsset(
              bytes: await img.readAsBytes(),
              filename: img.name,
              mimeType: img.mimeType ?? imageMimeTypeForFilename(img.name),
            );
            mediaIds.add(asset.assetId);
          }
          await repo.submitGalleryPost(
            subreddit: sr,
            title: title,
            mediaIds: mediaIds,
            nsfw: _nsfw,
            spoiler: _spoiler,
            sendReplies: _sendReplies,
            flair: _flair,
          );
          _done('Gallery posted');
        case _Kind.video:
          final videoBytes = await _video!.readAsBytes();
          final posterBytes = await VideoThumbnail.thumbnailData(
            video: _video!.path,
            imageFormat: ImageFormat.JPEG,
            quality: 75,
          );
          final video = await repo.uploadMediaAsset(
            bytes: videoBytes,
            filename: _video!.name,
            mimeType: 'video/mp4',
          );
          final poster = await repo.uploadMediaAsset(
            bytes: posterBytes ?? videoBytes,
            filename: 'poster.jpg',
            mimeType: 'image/jpeg',
          );
          final id = await repo.submitVideoPost(
            subreddit: sr,
            title: title,
            videoUrl: video.url,
            posterUrl: poster.url,
            nsfw: _nsfw,
            spoiler: _spoiler,
            sendReplies: _sendReplies,
            flair: _flair,
          );
          if (id.isNotEmpty) {
            _goToPost(sr, id);
          } else {
            _done('Video posted');
          }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e'.replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _goToPost(String sr, String id) {
    if (!mounted) return;
    ref.read(draftsProvider).clear(_draftKey);
    if (id.isEmpty) {
      _done('Posted');
    } else {
      context.pushReplacement('/comments/$sr/$id');
    }
  }

  void _done(String msg) {
    if (!mounted) return;
    ref.read(draftsProvider).clear(_draftKey);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_hasMedia,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard attachment?'),
            content: const Text(
              'Your text is saved as a draft, but the attached image/video '
              'is not. Leave anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New post'),
          actions: [
            if (_hasDraft && !_busy)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Draft saved',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: M3ELoadingIndicator.small(),
                      )
                    : const Text('Post'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _subreddit,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _saveDraft(),
              onEditingComplete: _loadFlairs,
              onTapOutside: (_) => _loadFlairs(),
              decoration: const InputDecoration(
                labelText: 'Subreddit',
                prefixText: 'r/',
                prefixIcon: Icon(Icons.forum_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              onChanged: (_) => _saveDraft(),
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              maxLines: 2,
              minLines: 1,
            ),
            if (_flairs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in _flairs)
                    ChoiceChip(
                      label: Text(f.text),
                      selected: _flair?.id == f.id,
                      onSelected: (s) => setState(() => _flair = s ? f : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<_Kind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _Kind.text,
                  icon: Icon(Icons.notes_rounded),
                ),
                ButtonSegment(
                  value: _Kind.link,
                  icon: Icon(Icons.link_rounded),
                ),
                ButtonSegment(
                  value: _Kind.image,
                  icon: Icon(Icons.image_rounded),
                ),
                ButtonSegment(
                  value: _Kind.gallery,
                  icon: Icon(Icons.collections_rounded),
                ),
                ButtonSegment(
                  value: _Kind.video,
                  icon: Icon(Icons.videocam_rounded),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) {
                if (_busy) return;
                setState(() => _kind = s.first);
                _saveDraft();
              },
            ),
            const SizedBox(height: 16),
            ..._kindBody(cs),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _nsfw,
              onChanged: (v) => setState(() => _nsfw = v),
              title: const Text('NSFW'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _spoiler,
              onChanged: (v) => setState(() => _spoiler = v),
              title: const Text('Spoiler'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _sendReplies,
              onChanged: (v) => setState(() => _sendReplies = v),
              title: const Text('Send me reply notifications'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _kindBody(ColorScheme cs) {
    switch (_kind) {
      case _Kind.text:
        return [
          TextField(
            controller: _body,
            minLines: 5,
            maxLines: 12,
            onChanged: (_) => _saveDraft(),
            decoration: const InputDecoration(
              labelText: 'Body (Markdown, optional)',
              alignLabelWithHint: true,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _insertGif,
              icon: const Icon(Icons.gif_box_outlined),
              label: const Text('GIF'),
            ),
          ),
        ];
      case _Kind.link:
        return [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => _saveDraft(),
            decoration: const InputDecoration(
              labelText: 'URL',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
        ];
      case _Kind.image:
        return [
          _pickerBox(
            cs,
            label: _image == null ? 'Tap to choose an image' : _image!.name,
            icon: Icons.add_photo_alternate_rounded,
            onTap: _pickImage,
          ),
        ];
      case _Kind.gallery:
        return [
          _pickerBox(
            cs,
            label: _gallery.isEmpty
                ? 'Tap to choose images'
                : '${_gallery.length} image(s) selected',
            icon: Icons.collections_rounded,
            onTap: _pickGallery,
          ),
        ];
      case _Kind.video:
        return [
          _pickerBox(
            cs,
            label: _video == null ? 'Tap to choose a video' : _video!.name,
            icon: Icons.video_call_rounded,
            onTap: _pickVideo,
          ),
        ];
    }
  }

  Widget _pickerBox(
    ColorScheme cs, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: cs.onSurfaceVariant),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(label, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
