import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/widgets/m3e_refresh_indicator.dart';

import '../../core/widgets/m3e_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets/error_view.dart';
import '../settings/settings_controller.dart';
import '../auth/auth_controller.dart';
import '../../models/post.dart';
import '../../models/reddit_user.dart';
import '../../models/subreddit.dart';
import '../feed/post_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialSubreddit, this.initialQuery});
  final String? initialSubreddit;
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _suggestionTimer;
  int _suggestionRevision = 0;
  bool _suggestionsOpen = false, _suggestionsLoading = false;
  Object? _suggestionError;
  List<Subreddit> _suggestions = [];
  bool _loading = false;
  String _query = '';
  Object? _error;
  String _sort = 'relevance';
  String _time = 'all';
  List<Post> _posts = [];
  List<Subreddit> _subs = [];
  List<RedditUser> _users = [];
  List<String> _recent = [];
  int _revision = 0;

  static const _sorts = {
    'relevance': 'Relevance',
    'hot': 'Hot',
    'top': 'Top',
    'new': 'New',
    'comments': 'Comments',
  };
  static const _times = {
    'hour': 'Hour',
    'day': 'Day',
    'week': 'Week',
    'month': 'Month',
    'year': 'Year',
    'all': 'All time',
  };
  static const _recentKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusChanged);
    _recent = ref.read(sharedPrefsProvider).getStringList(_recentKey) ?? [];
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _controller.text = q;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(q));
    }
  }

  void _saveRecent(String q) {
    final list = [q, ..._recent.where((e) => e != q)].take(12).toList();
    ref.read(sharedPrefsProvider).setStringList(_recentKey, list);
    setState(() => _recent = list);
  }

  @override
  void dispose() {
    _revision++;
    _cancelSuggestions();
    _focusNode.removeListener(_focusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _revision++;
    _cancelSuggestions();
    _controller.clear();
    setState(() {
      _query = '';
      _loading = false;
      _error = null;
      _posts = [];
      _subs = [];
      _users = [];
    });
  }

  Future<void> _search(String q, {bool saveRecent = true}) async {
    if (!mounted) return;
    q = q.trim();
    if (q.isEmpty) return;
    _cancelSuggestions();
    final revision = ++_revision;
    final epoch = ref.read(authSessionEpochProvider);
    if (_controller.text != q) _controller.text = q;
    FocusScope.of(context).unfocus();
    if (saveRecent) _saveRecent(q);
    setState(() {
      _loading = true;
      _query = q;
      _error = null;
    });
    final repo = ref.read(redditRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.searchPosts(
          q,
          subreddit: widget.initialSubreddit,
          sort: _sort,
          time: _time,
        ),
        if (widget.initialSubreddit == null)
          repo.searchSubreddits(q)
        else
          Future.value(<Subreddit>[]),
        if (widget.initialSubreddit == null)
          repo.searchUsers(q)
        else
          Future.value(<RedditUser>[]),
      ]);
      if (!mounted ||
          revision != _revision ||
          epoch != ref.read(authSessionEpochProvider)) {
        return;
      }
      setState(() {
        _posts = (results[0] as dynamic).items as List<Post>;
        _subs = results[1] as List<Subreddit>;
        _users = results[2] as List<RedditUser>;
        _loading = false;
      });
    } catch (e) {
      if (mounted &&
          revision == _revision &&
          epoch == ref.read(authSessionEpochProvider)) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  void _cancelSuggestions() {
    _suggestionTimer?.cancel();
    _suggestionRevision++;
    _suggestionsOpen = false;
    _suggestionsLoading = false;
    _suggestionError = null;
    _suggestions = [];
  }

  void _focusChanged() {
    if (!mounted) return;
    if (_focusNode.hasFocus) {
      _onQueryChanged(_controller.text);
    } else {
      setState(_cancelSuggestions);
    }
  }

  void _onQueryChanged(String text) {
    _revision++;
    _cancelSuggestions();
    final query = text
        .trim()
        .replaceFirst(RegExp(r'^/?r/', caseSensitive: false), '')
        .toLowerCase();
    setState(() {
      _loading = false;
      _suggestionsOpen =
          widget.initialSubreddit == null &&
          _focusNode.hasFocus &&
          query.isNotEmpty;
      _suggestionsLoading = _suggestionsOpen;
    });
    if (!_suggestionsOpen) return;
    final revision = _suggestionRevision;
    final epoch = ref.read(authSessionEpochProvider);
    // Network debounce is an app decision, independent of motion tokens.
    _suggestionTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await ref
            .read(redditRepositoryProvider)
            .searchSubreddits(query);
        if (!mounted ||
            revision != _suggestionRevision ||
            epoch != ref.read(authSessionEpochProvider)) {
          return;
        }
        final names = <String>{};
        setState(() {
          _suggestions = results
              .where(
                (s) => s.name.isNotEmpty && names.add(s.name.toLowerCase()),
              )
              .take(8)
              .toList();
          _suggestionsLoading = false;
        });
      } catch (error) {
        if (!mounted ||
            revision != _suggestionRevision ||
            epoch != ref.read(authSessionEpochProvider)) {
          return;
        }
        setState(() {
          _suggestionsLoading = false;
          _suggestionError = error;
        });
      }
    });
  }

  Widget _communitySuggestions(ColorScheme cs) => Material(
    key: const ValueKey('community-suggestions'),
    color: cs.surfaceContainerLow,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _suggestionsLoading
                  ? 'Finding communities…'
                  : '${_suggestions.length} community suggestions',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
        if (_suggestionsLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: M3ELoadingIndicator()),
          )
        else if (_suggestionError != null)
          ListTile(
            leading: Icon(Icons.wifi_off_rounded, color: cs.onSurfaceVariant),
            title: const Text('Could not load communities'),
            subtitle: const Text('Tap to retry, or submit your search.'),
            onTap: () => _onQueryChanged(_controller.text),
          )
        else if (_suggestions.isEmpty)
          const ListTile(
            leading: Icon(Icons.search_off_rounded),
            title: Text('No matching communities'),
            subtitle: Text('Submit your search to find posts and users.'),
          )
        else
          for (final s in _suggestions)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.secondaryContainer,
                foregroundColor: cs.onSecondaryContainer,
                child: Text(s.name[0].toUpperCase()),
              ),
              title: Text(s.namePrefixed),
              subtitle: Text('${compactNumber(s.subscribers)} members'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                setState(_cancelSuggestions);
                _focusNode.unfocus();
                context.push('/r/${Uri.encodeComponent(s.name)}');
              },
            ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionEpochProvider, (_, __) => _clear());
    final cs = Theme.of(context).colorScheme;
    final restricted = widget.initialSubreddit != null;
    return DefaultTabController(
      length: restricted ? 1 : 3,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          title: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: (widget.initialQuery?.trim().isEmpty ?? true),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: restricted
                  ? 'Search in r/${widget.initialSubreddit}'
                  : 'Search Reddit',
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: _clear,
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          bottom: restricted || _suggestionsOpen
              ? null
              : const TabBar(
                  tabs: [
                    Tab(text: 'Posts'),
                    Tab(text: 'Subreddits'),
                    Tab(text: 'Users'),
                  ],
                ),
        ),
        body: _suggestionsOpen
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: _communitySuggestions(cs),
              )
            : _loading
            ? const Center(child: M3ELoadingIndicator())
            : _query.isEmpty
            ? _empty(cs)
            : _error != null
            ? ErrorView(
                message: _error,
                onRetry: () => _search(_query, saveRecent: false),
              )
            : TabBarView(
                children: [
                  _postsTab(),
                  if (!restricted) _subsTab(),
                  if (!restricted) _usersTab(),
                ],
              ),
      ),
    );
  }

  Widget _empty(ColorScheme cs) {
    if (_recent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Search posts, subreddits and users',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 130),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Text(
                'Recent',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(sharedPrefsProvider).remove(_recentKey);
                  setState(() => _recent = []);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        for (final q in _recent)
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(q),
            trailing: IconButton(
              icon: const Icon(Icons.north_west_rounded, size: 18),
              onPressed: () {
                _controller.text = q;
                _search(q, saveRecent: false);
              },
            ),
            onTap: () => _search(q),
          ),
      ],
    );
  }

  Widget _filterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
      child: Row(
        children: [
          for (final e in _sorts.entries) ...[
            ChoiceChip(
              label: Text(e.value),
              selected: _sort == e.key,
              onSelected: (_) {
                setState(() => _sort = e.key);
                _search(_query, saveRecent: false);
              },
            ),
            const SizedBox(width: 6),
          ],
          if (_sort == 'top') ...[
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              initialValue: _time,
              onSelected: (v) {
                setState(() => _time = v);
                _search(_query, saveRecent: false);
              },
              itemBuilder: (_) => [
                for (final t in _times.entries)
                  PopupMenuItem(value: t.key, child: Text(t.value)),
              ],
              child: Chip(
                avatar: const Icon(Icons.schedule_rounded, size: 16),
                label: Text(_times[_time] ?? 'All time'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _postsTab() => Column(
    children: [
      _filterBar(),
      Expanded(
        child: M3ERefreshIndicator(
          onRefresh: () => _search(_query, saveRecent: false),
          child: _posts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No posts found')),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 130),
                  itemCount: _posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => PostCard(post: _posts[i]),
                ),
        ),
      ),
    ],
  );

  Widget _subsTab() {
    final cs = Theme.of(context).colorScheme;
    return M3ERefreshIndicator(
      onRefresh: () => _search(_query, saveRecent: false),
      child: _subs.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No subreddits found')),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 130),
              itemCount: _subs.length,
              itemBuilder: (_, i) {
                final s = _subs[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.secondaryContainer,
                    foregroundColor: cs.onSecondaryContainer,
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(s.namePrefixed),
                  subtitle: Text('${compactNumber(s.subscribers)} members'),
                  onTap: () => context.push('/r/${s.name}'),
                );
              },
            ),
    );
  }

  Widget _usersTab() {
    final cs = Theme.of(context).colorScheme;
    return M3ERefreshIndicator(
      onRefresh: () => _search(_query, saveRecent: false),
      child: _users.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No users found')),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 130),
              itemCount: _users.length,
              itemBuilder: (_, i) {
                final u = _users[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.secondaryContainer,
                    foregroundColor: cs.onSecondaryContainer,
                    child: Text(
                      u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text('u/${u.name}'),
                  subtitle: Text(
                    '${compactNumber(u.linkKarma + u.commentKarma)} karma',
                  ),
                  onTap: () => context.push('/u/${u.name}'),
                );
              },
            ),
    );
  }
}
