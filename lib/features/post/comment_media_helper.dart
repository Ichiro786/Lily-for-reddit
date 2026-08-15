/// A media URL found in a Reddit comment body.
class CommentMedia {
  const CommentMedia({required this.url, required this.isGif});

  final String url;
  final bool isGif;
}

final _commentUrlPattern = RegExp(r'https?://[^\s<>()\[\]"]+');
final _commentMarkdownMediaPattern = RegExp(
    r'!\[[^\]]*\]\(\s*(https?://[^\s<>()\[\]"]+)\s*\)');
final _trailingPunctuation = RegExp(r'[.,!?;:]+$');

/// Returns whether [rawUrl] points to an image-like Reddit comment resource.
///
/// Reddit-hosted media URLs are accepted even when the path does not expose an
/// extension; this covers the URL shapes returned by preview endpoints.
bool isCommentMediaUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  final path = uri.path.toLowerCase();
  final host = uri.host.toLowerCase();
  return path.endsWith('.gif') ||
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

/// Converts a GIFV URL to its image equivalent where the host supports it.
String normalizedCommentMediaUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return rawUrl.trim();
  final path = uri.path.replaceFirst(
      RegExp(r'\.gifv$', caseSensitive: false), '.gif');
  return uri.replace(path: path).toString();
}

/// Extracts unique image/GIF URLs from Markdown or plain comment text.
List<CommentMedia> extractCommentMedia(String body) {
  final seen = <String>{};
  final media = <CommentMedia>[];
  for (final match in _commentUrlPattern.allMatches(body)) {
    final raw = match.group(0)!.replaceFirst(_trailingPunctuation, '');
    if (!isCommentMediaUrl(raw)) continue;
    final url = normalizedCommentMediaUrl(raw);
    if (seen.add(url)) {
      media.add(CommentMedia(url: url, isGif: isCommentGifUrl(raw)));
    }
  }
  return media;
}

/// Removes URLs that are rendered separately below the comment body.
String commentTextWithoutMedia(String body) {
  var text = body.replaceAll(_commentMarkdownMediaPattern, '');
  text = text.replaceAllMapped(_commentUrlPattern, (match) {
    final raw = match.group(0)!.replaceFirst(_trailingPunctuation, '');
    return isCommentMediaUrl(raw) ? '' : match.group(0)!;
  });
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
