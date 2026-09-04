import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';

enum PostType { self, image, video, gif, gallery, link }

/// A gallery item (resolved image url + dimensions).
class GalleryImage {
  const GalleryImage({required this.url, this.width, this.height});
  final String url;
  final int? width;
  final int? height;
}

@freezed
class Post with _$Post {
  const Post._();

  const factory Post({
    required String id,
    required String fullname, // t3_xxx
    required String title,
    required String subreddit,
    required String subredditPrefixed,
    required String author,
    required int score,
    required int numComments,
    required double upvoteRatio,
    required DateTime created,
    required String permalink,
    required String url,
    required String domain,
    required PostType type,
    @Default(false) bool isSelf,
    @Default('') String selftext,
    @Default(false) bool over18,
    @Default(false) bool spoiler,
    @Default(false) bool stickied,
    @Default(false) bool locked,
    @Default(false) bool saved,
    @Default(false) bool canModPost,
    String? linkFlairText,
    String? distinguished,
    String? feedReason, // "why you're seeing this" in the For You feed (transient)
    String? crosspostFrom, // subreddit a crosspost originates from
    @Default(<String>[]) List<String> pollOptions,
    // media
    String? thumbnailUrl,
    String? previewUrl,
    String? previewMedUrl, // smaller resolution for feed cards
    int? previewWidth,
    int? previewHeight,
    String? hlsUrl,
    String? fallbackVideoUrl,
    @Default(<GalleryImage>[]) List<GalleryImage> gallery,
    // vote state: true=up, false=down, null=none
    bool? likes,
  }) = _Post;

  /// Parses a single listing child's `data` object.
  factory Post.fromData(Map<String, dynamic> d) {
    final crosspostParents = _l(d['crosspost_parent_list']);
    final parentData = crosspostParents != null && crosspostParents.isNotEmpty
        ? _m(crosspostParents.first)
        : null;

    final preview = _firstPreviewImage(d) ??
        (parentData != null ? _firstPreviewImage(parentData) : null);
    final media = _m(d['media']) ??
        (parentData != null ? _m(parentData['media']) : null);
    final redditVideo = _m(media?['reddit_video']);
    final isVideo = d['is_video'] == true ||
        parentData?['is_video'] == true ||
        redditVideo != null;
    final gallery = _parseGallery(d).isNotEmpty
        ? _parseGallery(d)
        : (parentData != null ? _parseGallery(parentData) : const <GalleryImage>[]);

    final videoWidth = (redditVideo?['width'] as num?)?.toInt();
    final videoHeight = (redditVideo?['height'] as num?)?.toInt();
    final resolvedWidth = (isVideo && videoWidth != null && videoWidth > 0)
        ? videoWidth
        : (preview?.width ?? videoWidth);
    final resolvedHeight = (isVideo && videoHeight != null && videoHeight > 0)
        ? videoHeight
        : (preview?.height ?? videoHeight);

    final rawUrl = d['url'] as String? ?? parentData?['url'] as String? ?? '';
    final rawThumb = d['thumbnail'] as String? ?? parentData?['thumbnail'] as String?;

    return Post(
      id: d['id'] as String? ?? '',
      fullname: d['name'] as String? ?? 't3_${d['id']}',
      title: (d['title'] as String? ?? '').trim(),
      subreddit: d['subreddit'] as String? ?? '',
      subredditPrefixed: d['subreddit_name_prefixed'] as String? ?? '',
      author: d['author'] as String? ?? '[deleted]',
      score: (d['score'] as num?)?.toInt() ?? 0,
      numComments: (d['num_comments'] as num?)?.toInt() ?? 0,
      upvoteRatio: (d['upvote_ratio'] as num?)?.toDouble() ?? 0,
      created: DateTime.fromMillisecondsSinceEpoch(
        ((d['created_utc'] as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      ),
      permalink: d['permalink'] as String? ?? '',
      url: _unescapeUrl(rawUrl),
      domain: d['domain'] as String? ?? parentData?['domain'] as String? ?? '',
      type: _detectType(d, isVideo, gallery.isNotEmpty, parentData),
      isSelf: d['is_self'] == true,
      selftext: d['selftext'] as String? ?? '',
      over18: d['over_18'] == true || parentData?['over_18'] == true,
      spoiler: d['spoiler'] == true || parentData?['spoiler'] == true,
      stickied: d['stickied'] == true,
      locked: d['locked'] == true,
      saved: d['saved'] == true,
      canModPost: d['can_mod_post'] == true,
      linkFlairText: (d['link_flair_text'] as String?)?.trim().isEmpty ?? true
          ? null
          : d['link_flair_text'] as String?,
      distinguished: d['distinguished'] as String?,
      crosspostFrom: _crosspostFrom(d),
      pollOptions: _pollOptions(d),
      thumbnailUrl: _validThumb(rawThumb),
      previewUrl: preview?.url,
      previewMedUrl: _medPreviewUrl(d) ??
          (parentData != null ? _medPreviewUrl(parentData) : null) ??
          preview?.url,
      previewWidth: resolvedWidth,
      previewHeight: resolvedHeight,
      hlsUrl: redditVideo?['hls_url'] as String?,
      fallbackVideoUrl: redditVideo?['fallback_url'] as String?,
      gallery: gallery,
      likes: d['likes'] as bool?,
    );
  }

  bool get hasMedia =>
      previewUrl != null || gallery.isNotEmpty || type == PostType.video;
}

/// Safe casts for Reddit's polymorphic fields (a value can be a Map, "", false,
/// or null depending on the post — never assume).
Map<String, dynamic>? _m(dynamic v) => v is Map<String, dynamic>
    ? v
    : (v is Map ? Map<String, dynamic>.from(v) : null);
List<dynamic>? _l(dynamic v) => v is List ? v : null;

String? _crosspostFrom(Map<String, dynamic> d) {
  final list = _l(d['crosspost_parent_list']);
  if (list == null || list.isEmpty) return null;
  return _m(list.first)?['subreddit'] as String?;
}

List<String> _pollOptions(Map<String, dynamic> d) {
  final opts = _l(_m(d['poll_data'])?['options']);
  if (opts == null) return const [];
  return [
    for (final o in opts) _m(o)?['text'] as String? ?? '',
  ]..removeWhere((e) => e.isEmpty);
}

PostType _detectType(
  Map<String, dynamic> d,
  bool isVideo,
  bool hasGallery, [
  Map<String, dynamic>? parent,
]) {
  if (d['is_self'] == true && parent == null) return PostType.self;
  if (hasGallery) return PostType.gallery;
  if (isVideo) return PostType.video;
  final hint = (d['post_hint'] ?? parent?['post_hint']) as String?;
  if (hint == 'image') return PostType.image;
  if (hint == 'rich:video' || hint == 'hosted:video') return PostType.video;
  final url = (d['url'] as String? ?? parent?['url'] as String? ?? '').toLowerCase();
  if (url.endsWith('.gif')) return PostType.gif;
  if (url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.png') ||
      url.endsWith('.webp')) {
    return PostType.image;
  }
  if (url.endsWith('.gifv') || url.endsWith('.mp4')) return PostType.video;
  if (d['is_self'] == true) return PostType.self;
  return PostType.link;
}

String _unescapeUrl(String url) =>
    url.contains('&amp;') ? url.replaceAll('&amp;', '&') : url;

String? _validThumb(String? thumb) {
  if (thumb == null) return null;
  if (thumb == 'self' || thumb == 'default' || thumb == 'nsfw' ||
      thumb == 'spoiler' || thumb == 'image' || thumb.isEmpty) {
    return null;
  }
  return _unescapeUrl(thumb);
}

({String url, int? width, int? height})? _firstPreviewImage(
    Map<String, dynamic> d) {
  final images = _l(_m(d['preview'])?['images']);
  if (images == null || images.isEmpty) return null;
  final source = _m(_m(images.first)?['source']);
  final src = source?['url'] as String?;
  if (src == null) return null;
  return (
    url: _unescapeUrl(src),
    width: (source?['width'] as num?)?.toInt(),
    height: (source?['height'] as num?)?.toInt(),
  );
}

/// A mid-resolution preview (~the smallest >= 640px wide, else the largest
/// available) for faster feed cards. Reddit's `resolutions` are ascending.
String? _medPreviewUrl(Map<String, dynamic> d) {
  final images = _l(_m(d['preview'])?['images']);
  if (images == null || images.isEmpty) return null;
  final res = _l(_m(images.first)?['resolutions']);
  if (res == null || res.isEmpty) return null;
  for (final r in res) {
    final m = _m(r);
    final w = (m?['width'] as num?)?.toInt() ?? 0;
    final u = m?['url'] as String?;
    if (u != null && w >= 640) return _unescapeUrl(u);
  }
  final lastUrl = _m(res.last)?['url'] as String?;
  return lastUrl != null ? _unescapeUrl(lastUrl) : null;
}

List<GalleryImage> _parseGallery(Map<String, dynamic> d) {
  final galleryData = _m(d['gallery_data']);
  final metadata = _m(d['media_metadata']);
  if (galleryData == null || metadata == null) return const [];
  final items = _l(galleryData['items']) ?? const [];
  final result = <GalleryImage>[];
  for (final item in items) {
    final mediaId = _m(item)?['media_id'] as String?;
    if (mediaId == null) continue;
    final s = _m(_m(metadata[mediaId])?['s']);
    final url = (s?['u'] ?? s?['gif']) as String?;
    if (url == null) continue;
    result.add(GalleryImage(
      url: _unescapeUrl(url),
      width: (s?['x'] as num?)?.toInt(),
      height: (s?['y'] as num?)?.toInt(),
    ));
  }
  return result;
}
