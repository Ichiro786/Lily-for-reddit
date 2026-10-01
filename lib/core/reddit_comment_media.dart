/// A media URL found in a Reddit comment body.
class CommentMedia {
  const CommentMedia({
    required this.url,
    required this.isGif,
    this.isVideo = false,
  });

  final String url;
  final bool isGif;
  final bool isVideo;
}

final _commentUrlPattern = RegExp(r'https?://[^\s<>()\[\]"]+');
final _commentMarkdownMediaPattern = RegExp(
  r'!\[[^\]]*\]\(\s*(https?://[^\s<>()\[\]"]+)\s*\)',
);
final _inlineGifPattern = RegExp(
  r'!\[(?:gif|img)\]\((giphy|emote)\|([^)]*)\)',
  caseSensitive: false,
);
final _trailingPunctuation = RegExp(r'[.,!?;:]+$');
final _codeContent = RegExp(r'```[\s\S]*?```|~~~[\s\S]*?~~~|`[^`\n]*`');
final _protectedContent = RegExp(
  r'```[\s\S]*?```|~~~[\s\S]*?~~~|`[^`\n]*`|>![\s\S]*?!<|!([^!\n]*?)!<',
);

/// Returns whether [rawUrl] points to an image-like Reddit comment resource.
///
/// Reddit-hosted media URLs are accepted even when the path does not expose an
/// extension; this covers the URL shapes returned by preview endpoints.
bool isCommentMediaUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  final path = uri.path.toLowerCase();
  final host = uri.host.toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.webm') ||
      path.endsWith('.gif') ||
      path.endsWith('.gifv') ||
      path.endsWith('.png') ||
      path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.webp') ||
      ((host == 'i.redd.it' || host == 'preview.redd.it') && path != '/');
}

/// Returns whether [rawUrl] should be treated as an animated GIF preview.
bool isCommentGifUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return false;
  final path = uri.path.toLowerCase();
  return path.endsWith('.gif') || path.endsWith('.gifv');
}

/// Resolves Reddit's inline GIF token forms to a direct Giphy URL.
String? resolveInlineGifToken(String token) {
  final match = _inlineGifPattern.firstMatch(token.trim());
  if (match == null) return null;
  if (match.group(1)!.toLowerCase() != 'giphy') return null;
  final id = match.group(2)!.split('|').last;
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return null;
  return 'https://media.giphy.com/media/$id/giphy.gif';
}

/// Converts a GIFV URL to its image equivalent where the host supports it.
String normalizedCommentMediaUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return rawUrl.trim();
  final path = uri.path.replaceFirst(
    RegExp(r'\.gifv$', caseSensitive: false),
    '.gif',
  );
  return uri.replace(path: path).toString();
}

/// Extracts unique image/GIF URLs and inline GIF tokens from a comment.
List<CommentMedia> extractCommentMedia(String body) {
  body = body.replaceAll(_protectedContent, '');
  final seen = <String>{};
  final media = <CommentMedia>[];

  for (final match in _inlineGifPattern.allMatches(body)) {
    final url = resolveInlineGifToken(match.group(0)!);
    if (url != null && seen.add(url)) {
      media.add(CommentMedia(url: url, isGif: true));
    }
  }

  for (final match in _commentUrlPattern.allMatches(body)) {
    final raw = match.group(0)!.replaceFirst(_trailingPunctuation, '');
    if (!isCommentMediaUrl(raw)) continue;
    final url = normalizedCommentMediaUrl(raw);
    if (seen.add(url)) {
      media.add(
        CommentMedia(
          url: url,
          isGif: isCommentGifUrl(raw),
          isVideo: isCommentVideoUrl(raw),
        ),
      );
    }
  }
  return media;
}

/// Removes URLs and inline GIF tokens that are rendered separately below text.
String commentTextWithoutMedia(String body) {
  final spoilers = <String>[];
  body = body.replaceAllMapped(_protectedContent, (match) {
    spoilers.add(match.group(0)!);
    return 'LILY_SPOILER_${spoilers.length - 1}_TOKEN';
  });
  var text = body.replaceAllMapped(
    _inlineGifPattern,
    (match) => resolveInlineGifToken(match.group(0)!) != null
        ? ''
        : '[Emote unavailable]',
  );
  text = text.replaceAllMapped(
    _commentMarkdownMediaPattern,
    (match) => isCommentMediaUrl(match.group(1)!) ? '' : match.group(0)!,
  );
  text = text.replaceAllMapped(
    RegExp(r'(?<!!)\[([^\]]+)\]\(\s*(https?://[^\s<>()\[\]\"]+)\s*\)'),
    (match) =>
        isCommentMediaUrl(match.group(2)!) ? match.group(1)! : match.group(0)!,
  );
  text = text.replaceAllMapped(_commentUrlPattern, (match) {
    final raw = match.group(0)!.replaceFirst(_trailingPunctuation, '');
    return isCommentMediaUrl(raw) ? '' : match.group(0)!;
  });
  for (var i = 0; i < spoilers.length; i++) {
    text = text.replaceAll('LILY_SPOILER_${i}_TOKEN', spoilers[i]);
  }
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

bool isCommentVideoUrl(String rawUrl) {
  final path = Uri.tryParse(rawUrl)?.path.toLowerCase() ?? '';
  return path.endsWith('.mp4') || path.endsWith('.webm');
}

/// Resolve Reddit's opaque emote/image IDs using the response metadata.
/// Giphy tokens have a public fallback; emotes must never be guessed as Giphy IDs.
String resolveCommentBodyMedia(String body, Object? metadata) {
  if (metadata is! Map) return body;
  final code = <String>[];
  body = body.replaceAllMapped(_codeContent, (match) {
    code.add(match.group(0)!);
    return 'LILY_CODE_${code.length - 1}_TOKEN';
  });
  var resolved = body.replaceAllMapped(_inlineGifPattern, (match) {
    final parts = match.group(2)!.split('|');
    final id = parts.last;
    final item = metadata[id] ?? metadata[match.group(2)];
    if (item is! Map || item['s'] is! Map) return match.group(0)!;
    final source = item['s'] as Map;
    final raw = source['gif'] ?? source['u'] ?? source['mp4'];
    if (raw is! String) return match.group(0)!;
    final url = raw.replaceAll('&amp;', '&');
    return isCommentMediaUrl(url) ? '![media]($url)' : match.group(0)!;
  });
  for (var i = 0; i < code.length; i++) {
    resolved = resolved.replaceAll('LILY_CODE_${i}_TOKEN', code[i]);
  }
  return resolved;
}
