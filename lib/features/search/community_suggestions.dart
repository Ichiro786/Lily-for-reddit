import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../models/subreddit.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_media.dart';

String normalizeCommunityQuery(String value) => value
    .trim()
    .replaceFirst(RegExp(r'^/?r/', caseSensitive: false), '')
    .toLowerCase();

/// Inline suggestions keep the writing destination visible above the keyboard.
class CommunitySuggestions extends ConsumerStatefulWidget {
  const CommunitySuggestions({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSelected,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<Subreddit> onSelected;
  @override
  ConsumerState<CommunitySuggestions> createState() =>
      _CommunitySuggestionsState();
}

class _CommunitySuggestionsState extends ConsumerState<CommunitySuggestions> {
  Timer? _timer;
  int _revision = 0;
  String _query = '';
  bool _loading = false;
  bool _failed = false;
  List<Subreddit> _items = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.focusNode.addListener(_changed);
  }

  void _changed() {
    final query = widget.focusNode.hasFocus
        ? normalizeCommunityQuery(widget.controller.text)
        : '';
    if (query == _query) return;
    _timer?.cancel();
    final revision = ++_revision;
    setState(() {
      _query = query;
      _items = [];
      _failed = false;
      _loading = query.isNotEmpty;
    });
    if (query.isEmpty) return;
    // App decision: debounce fast typing, without requiring Submit.
    _timer = Timer(
      const Duration(milliseconds: 250),
      () => _fetch(query, revision),
    );
  }

  Future<void> _fetch(String query, int revision) async {
    final epoch = ref.read(authSessionEpochProvider);
    try {
      final items = await ref
          .read(redditRepositoryProvider)
          .searchSubreddits(query);
      if (!mounted ||
          revision != _revision ||
          epoch != ref.read(authSessionEpochProvider)) {
        return;
      }
      final seen = <String>{};
      setState(() {
        _items = items
            .where(
              (item) =>
                  item.name.isNotEmpty && seen.add(item.name.toLowerCase()),
            )
            .take(8)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          revision != _revision ||
          epoch != ref.read(authSessionEpochProvider)) {
        return;
      }
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _revision++;
    widget.controller.removeListener(_changed);
    widget.focusNode.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionEpochProvider, (_, __) {
      _timer?.cancel();
      _revision++;
      setState(() {
        _query = '';
        _items = [];
        _loading = false;
        _failed = false;
      });
    });
    if (_query.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return TextFieldTapRegion(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          key: const ValueKey('composer-community-suggestions'),
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            // App decision: bounded list leaves room for the field and keyboard.
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .28,
            ),
            child: ListView(
              shrinkWrap: true,
              primary: false,
              padding: EdgeInsets.zero,
              children: [
                if (_loading)
                  const ListTile(title: Text('Finding communities…')),
                if (_failed)
                  ListTile(
                    title: const Text('Could not load communities'),
                    subtitle: const Text('Tap to retry'),
                    leading: const Icon(Icons.refresh_rounded),
                    onTap: () {
                      setState(() {
                        _failed = false;
                        _loading = true;
                      });
                      _fetch(_query, ++_revision);
                    },
                  ),
                if (!_loading && !_failed && _items.isEmpty)
                  const ListTile(title: Text('No matching communities')),
                for (final item in _items)
                  ListTile(
                    leading: ProfileAvatar(
                      username: item.name,
                      url: item.iconUrl,
                      size: 32,
                    ),
                    title: Text(
                      item.namePrefixed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => widget.onSelected(item),
                  ),
                Semantics(
                  liveRegion: true,
                  label: _loading
                      ? 'Finding communities'
                      : _failed
                      ? 'Could not load communities'
                      : '${_items.length} community suggestions',
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
