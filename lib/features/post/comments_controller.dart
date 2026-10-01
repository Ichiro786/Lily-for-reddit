import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import 'comment_media_helper.dart';
import 'interactive_spoiler.dart';

class PostThread {
  const PostThread({
    required this.post,
    required this.comments,
    this.collapsed = const {},
    this.loadingMore = const {},
  });

  final Post post;
  final List<Comment> comments;
  final Set<String> collapsed; // collapsed comment ids
  final Set<String> loadingMore; // more-node fullnames being fetched

  PostThread copyWith({
    Post? post,
    List<Comment>? comments,
    Set<String>? collapsed,
    Set<String>? loadingMore,
  }) => PostThread(
    post: post ?? this.post,
    comments: comments ?? this.comments,
    collapsed: collapsed ?? this.collapsed,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// arg = "subreddit/postId"
const commentSorts = ['confidence', 'top', 'new', 'controversial', 'old', 'qa'];
const commentSortLabels = {
  'confidence': 'Best',
  'top': 'Top',
  'new': 'New',
  'controversial': 'Controversial',
  'old': 'Old',
  'qa': 'Q&A',
};

String moreNodeKey(Comment node) =>
    jsonEncode([node.fullname, node.parentId, node.moreChildren]);

class CommentsController
    extends AutoDisposeFamilyAsyncNotifier<PostThread, String> {
  String _subreddit = '';
  String _postId = '';
  String? _focusCommentId; // set when viewing a single comment thread
  String _sort = 'confidence';
  String get sort => _sort;
  bool get isFocused => _focusCommentId != null;
  int _generation = 0;
  bool _disposed = false;
  bool _current(int generation) => !_disposed && generation == _generation;

  @override
  Future<PostThread> build(String arg) async {
    ref.watch(redditRepositoryProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    final generation = ++_generation;
    // Key: "subreddit/postId" or "subreddit/postId/focus_<commentId>".
    final parts = arg.split('/');
    _subreddit = parts[0];
    _postId = parts[1];
    _focusCommentId = (parts.length > 2 && parts[2].startsWith('focus_'))
        ? parts[2].substring(6)
        : null;
    return _load(generation);
  }

  Future<PostThread> _load(int generation) async {
    final (post, comments) = await ref
        .read(redditRepositoryProvider)
        .getComments(
          subreddit: _subreddit,
          postId: _postId,
          sort: _sort,
          focusCommentId: _focusCommentId,
        );
    if (!_current(generation)) throw StateError('Superseded comments request');
    return PostThread(post: post, comments: comments);
  }

  Future<void> _reload({bool loading = false}) async {
    final generation = ++_generation;
    if (loading) state = const AsyncLoading();
    final next = await AsyncValue.guard(() => _load(generation));
    if (_current(generation)) state = next;
  }

  Future<void> changeSort(String sort) async {
    _sort = sort;
    await _reload(loading: true);
  }

  Future<void> refresh() async {
    await _reload();
  }

  void toggleCollapse(String commentId) {
    final s = state.valueOrNull;
    if (s == null) return;
    final next = Set<String>.from(s.collapsed);
    next.contains(commentId) ? next.remove(commentId) : next.add(commentId);
    state = AsyncData(s.copyWith(collapsed: next));
  }

  /// Splices a freshly-created reply into the tree under [parentFullname]
  /// (the post's fullname → new top-level comment; else under that comment).
  void insertReply(String parentFullname, Comment reply) {
    final s = state.valueOrNull;
    if (s == null) return;
    if (parentFullname == s.post.fullname) {
      state = AsyncData(s.copyWith(comments: [reply, ...s.comments]));
      return;
    }
    List<Comment> walk(List<Comment> nodes) => [
      for (final n in nodes)
        if (n.fullname == parentFullname)
          n.copyWith(
            replies: [
              reply.copyWith(depth: n.depth + 1),
              ...n.replies,
            ],
          )
        else
          n.copyWith(replies: walk(n.replies)),
    ];
    state = AsyncData(s.copyWith(comments: walk(s.comments)));
  }

  void applyEdit(String fullname, String newBody) {
    final s = state.valueOrNull;
    if (s == null) return;
    if (fullname == s.post.fullname) {
      state = AsyncData(s.copyWith(post: s.post.copyWith(selftext: newBody)));
      return;
    }
    List<Comment> walk(List<Comment> nodes) => [
      for (final n in nodes)
        if (n.fullname == fullname)
          n.copyWith(body: newBody, replies: walk(n.replies))
        else
          n.copyWith(replies: walk(n.replies)),
    ];
    state = AsyncData(s.copyWith(comments: walk(s.comments)));
  }

  void removeComment(String fullname) {
    final s = state.valueOrNull;
    if (s == null) return;
    List<Comment> walk(List<Comment> nodes) => [
      for (final n in nodes)
        if (n.fullname != fullname) n.copyWith(replies: walk(n.replies)),
    ];
    state = AsyncData(s.copyWith(comments: walk(s.comments)));
  }

  Future<void> loadMore(Comment moreNode) async {
    final s = state.valueOrNull;
    if (s == null || moreNode.moreChildren.isEmpty) return;
    final key = moreNodeKey(moreNode);
    if (s.loadingMore.contains(key)) return;
    final generation = _generation;
    state = AsyncData(s.copyWith(loadingMore: {...s.loadingMore, key}));

    try {
      final flat = await ref
          .read(redditRepositoryProvider)
          .getMoreComments(
            linkFullname: s.post.fullname,
            childrenIds: moreNode.moreChildren,
            depth: moreNode.depth,
            sort: _sort,
          );
      if (!_current(generation)) return;

      final current = state.valueOrNull;
      if (current == null) return;
      // Existing nodes own their current body/replies. Add fetched children
      // without duplicating those nodes or reviving locally removed parents.
      final inserted = <String>{};
      void collect(List<Comment> nodes) {
        for (final n in nodes) {
          inserted.add(n.isMore ? moreNodeKey(n) : n.fullname);
          collect(n.replies);
        }
      }

      collect(current.comments);
      inserted.remove(key);
      final byParent = <String, List<Comment>>{};
      final fetched = <String>{};
      for (final c in flat) {
        if (fetched.add(c.isMore ? moreNodeKey(c) : c.fullname)) {
          byParent.putIfAbsent(c.parentId, () => []).add(c);
        }
      }
      List<Comment> children(String parent, int depth) {
        final out = <Comment>[];
        for (final c in byParent[parent] ?? const <Comment>[]) {
          if (!inserted.add(c.isMore ? moreNodeKey(c) : c.fullname)) continue;
          out.add(
            c.copyWith(depth: depth, replies: children(c.fullname, depth + 1)),
          );
        }
        return out;
      }

      List<Comment> replace(List<Comment> nodes) {
        final out = <Comment>[];
        for (final n in nodes) {
          if (n.isMore && moreNodeKey(n) == key) {
            out.addAll(children(moreNode.parentId, moreNode.depth));
          } else {
            out.add(
              n.copyWith(
                replies: [
                  ...replace(n.replies),
                  ...children(n.fullname, n.depth + 1),
                ],
              ),
            );
          }
        }
        return out;
      }

      state = AsyncData(
        current.copyWith(
          comments: replace(current.comments),
          loadingMore: {...current.loadingMore}..remove(key),
        ),
      );
    } catch (_) {
      if (!_current(generation)) return;
      final current = state.valueOrNull ?? s;
      state = AsyncData(
        current.copyWith(loadingMore: {...current.loadingMore}..remove(key)),
      );
    }
  }
}

final commentsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsController, PostThread, String>(CommentsController.new);

class FlattenedComment {
  const FlattenedComment({required this.comment, required this.markdownBody});

  final Comment comment;
  final Widget? markdownBody;
}

final flattenedCommentPresentationProvider = Provider.autoDispose
    .family<List<FlattenedComment>, (String, MarkdownStyleSheet)>((ref, args) {
      final asyncThread = ref.watch(commentsControllerProvider(args.$1));
      final thread = asyncThread.valueOrNull;
      if (thread == null) return const [];

      final out = <FlattenedComment>[];
      void walk(Comment comment) {
        final isCollapsed = thread.collapsed.contains(comment.id);
        // Collapsed nodes hide their body entirely, so no Markdown is built for
        // them; expanded nodes render through the shared spoiler-aware pipeline.
        final body = isCollapsed ? '' : commentTextWithoutMedia(comment.body);
        out.add(
          FlattenedComment(
            comment: comment,
            markdownBody: body.isEmpty
                ? null
                : buildCommentMarkdownBody(body, args.$2),
          ),
        );
        if (!comment.isMore && !isCollapsed) {
          for (final reply in comment.replies) {
            walk(reply);
          }
        }
      }

      for (final comment in thread.comments) {
        walk(comment);
      }
      return out;
    });
