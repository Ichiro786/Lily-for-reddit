import 'package:freezed_annotation/freezed_annotation.dart';
import '../core/reddit_comment_media.dart';

part 'comment.freezed.dart';

/// A node in the comment tree. `kind: t1` is a comment; `kind: more` is a
/// "load more comments" placeholder.
@freezed
class Comment with _$Comment {
  const Comment._();

  const factory Comment({
    required String id,
    required String fullname, // t1_xxx
    @Default('') String parentId, // t1_xxx or t3_xxx
    required String author,
    required String body,
    required int score,
    required DateTime created,
    required int depth,
    String? distinguished,
    @Default(false) bool stickied,
    @Default(false) bool scoreHidden,
    @Default(false) bool saved,
    bool? likes,
    // Present on user/saved comment listings — link back to the parent post.
    @Default('') String linkTitle,
    @Default('') String permalink,
    @Default('') String subreddit,
    @Default(<Comment>[]) List<Comment> replies,
    // "more" placeholder fields
    @Default(false) bool isMore,
    @Default(0) int moreCount,
    @Default(<String>[]) List<String> moreChildren,
    @Default(false) bool collapsed,
  }) = _Comment;

  factory Comment.fromChild(Map<String, dynamic> child, int depth) {
    final kind = child['kind'] as String?;
    final d = child['data'] as Map<String, dynamic>? ?? {};

    if (kind == 'more') {
      final children = (d['children'] as List?)?.cast<String>() ?? const [];
      return Comment(
        id: d['id'] as String? ?? 'more',
        fullname: d['name'] as String? ?? 'more_${d['id']}',
        parentId: d['parent_id'] as String? ?? '',
        author: '',
        body: '',
        score: 0,
        created: DateTime.fromMillisecondsSinceEpoch(0),
        depth: depth,
        isMore: true,
        moreCount: (d['count'] as num?)?.toInt() ?? children.length,
        moreChildren: children,
      );
    }

    final repliesRaw = d['replies'];
    final replies = <Comment>[];
    if (repliesRaw is Map) {
      final data = repliesRaw['data'];
      final children = (data is Map ? data['children'] : null);
      if (children is List) {
        for (final c in children) {
          if (c is Map) {
            replies.add(
                Comment.fromChild(c.cast<String, dynamic>(), depth + 1));
          }
        }
      }
    }

    return Comment(
      id: d['id'] as String? ?? '',
      fullname: d['name'] as String? ?? 't1_${d['id']}',
      parentId: d['parent_id'] as String? ?? '',
      author: d['author'] as String? ?? '[deleted]',
      body: resolveCommentBodyMedia(d['body'] as String? ?? '', d['media_metadata']),
      score: (d['score'] as num?)?.toInt() ?? 0,
      created: DateTime.fromMillisecondsSinceEpoch(
        ((d['created_utc'] as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      ),
      depth: depth,
      distinguished: d['distinguished'] as String?,
      stickied: d['stickied'] == true,
      scoreHidden: d['score_hidden'] == true,
      saved: d['saved'] == true,
      likes: d['likes'] as bool?,
      linkTitle: (d['link_title'] as String?)?.trim() ?? '',
      permalink: d['permalink'] as String? ?? '',
      subreddit: d['subreddit'] as String? ?? '',
      replies: replies,
    );
  }
}
