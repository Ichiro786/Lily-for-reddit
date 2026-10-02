import 'package:markdown/markdown.dart' as md;
import 'reddit_markdown.dart';

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

class ParsedCommentContent {
  const ParsedCommentContent(this.text, this.media);
  final String text;
  final List<CommentMedia> media;
}

final _inlineGifPattern = RegExp(
  r'!\[(?:gif|img)\]\((giphy|emote)\|([^)]*)\)',
  caseSensitive: false,
);
final _trailingPunctuation = RegExp(r'[.,!?;:]+$');
final _urlBoundary = RegExp(r'[\s<>\[\]"]');

bool isCommentMediaUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  final path = uri.path.toLowerCase();
  final host = uri.host.toLowerCase();
  if (RegExp(r'[\s/%\\]').hasMatch(host)) return false;
  return [
        '.mp4',
        '.webm',
        '.gif',
        '.gifv',
        '.png',
        '.jpg',
        '.jpeg',
        '.webp',
      ].any(path.endsWith) ||
      ((host == 'i.redd.it' || host == 'preview.redd.it') &&
          path.isNotEmpty &&
          path != '/');
}

bool isCommentGifUrl(String rawUrl) {
  final path = Uri.tryParse(rawUrl.trim())?.path.toLowerCase() ?? '';
  return path.endsWith('.gif') || path.endsWith('.gifv');
}

bool isCommentVideoUrl(String rawUrl) {
  final path = Uri.tryParse(rawUrl.trim())?.path.toLowerCase() ?? '';
  return path.endsWith('.mp4') || path.endsWith('.webm');
}

String? resolveInlineGifToken(String token) {
  final match = _inlineGifPattern.firstMatch(token.trim());
  if (match == null ||
      match[0] != token.trim() ||
      match[1]!.toLowerCase() != 'giphy') {
    return null;
  }
  final id = match[2]!.split('|').last;
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return null;
  return 'https://media.giphy.com/media/$id/giphy.gif';
}

String normalizedCommentMediaUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return rawUrl.trim();
  return uri
      .replace(
        path: uri.path.replaceFirst(
          RegExp(r'\.gifv$', caseSensitive: false),
          '.gif',
        ),
      )
      .toString();
}

/// Scan a delimited Markdown region, retaining escaped delimiters and titles.
int? _balancedEnd(String text, int start, String open, String close) {
  var depth = 0;
  String? quote;
  var angle = false;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (char == '\\') {
      i++;
      continue;
    }
    if (open == '[' && char == '`') {
      final end = markdownCodeEnd(text, i);
      if (end != null) {
        i = end - 1;
        continue;
      }
    }
    if (open == '(' && quote == null && char == '<') {
      angle = true;
      continue;
    }
    if (angle) {
      if (char == '>') angle = false;
      continue;
    }
    if (open == '(' &&
        (char == '"' || char == "'") &&
        (quote != null || (i > start && RegExp(r'\s').hasMatch(text[i - 1])))) {
      quote = quote == null
          ? char
          : quote == char
          ? null
          : quote;
      continue;
    }
    if (quote != null) continue;
    if (char == open) depth++;
    if (char == close && --depth == 0) return i + 1;
  }
  return null;
}

ParsedCommentContent parseCommentContent(String body) {
  final document = md.Document(encodeHtml: false);
  // Let CommonMark resolve case-insensitive reference definitions; code examples
  // are never treated as definitions. Avoid the block parse for ordinary prose.
  if (RegExp(r'^ {0,3}\[[^\]]+\]:', multiLine: true).hasMatch(body)) {
    document.parse(body);
  }
  final media = <CommentMedia>[];
  final seen = <String>{};
  void add(String raw) {
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

  final text = mapRedditMarkdownProse(
    body,
    (prose) {
      final output = StringBuffer();
      var cursor = 0;
      while (cursor < prose.length) {
        if (prose[cursor] == '\\' && cursor + 1 < prose.length) {
          output.write(prose.substring(cursor, cursor + 2));
          cursor += 2;
          continue;
        }
        final spoilerEnd = prose.startsWith('>!', cursor)
            ? redditSpoilerEnd(prose, cursor + 2)
            : null;
        final protectedEnd = prose[cursor] == '`'
            ? markdownCodeEnd(prose, cursor)
            : prose.startsWith('>!', cursor)
            ? (spoilerEnd == null ? null : spoilerEnd + 2)
            : null;
        if (protectedEnd != null) {
          output.write(prose.substring(cursor, protectedEnd));
          cursor = protectedEnd;
          continue;
        }
        final token = _inlineGifPattern.matchAsPrefix(prose, cursor);
        if (token != null) {
          final url = resolveInlineGifToken(token[0]!);
          if (url != null) {
            add(url);
          } else {
            output.write('[Emote unavailable]');
          }
          cursor = token.end;
          continue;
        }
        final image = prose.startsWith('![', cursor);
        final labelStart = image ? cursor + 1 : cursor;
        if (labelStart < prose.length && prose[labelStart] == '[') {
          final labelEnd = _balancedEnd(prose, labelStart, '[', ']');
          if (labelEnd != null) {
            var end = labelEnd;
            if (end < prose.length && prose[end] == '(') {
              end = _balancedEnd(prose, end, '(', ')') ?? end;
            } else if (end < prose.length && prose[end] == '[') {
              end = _balancedEnd(prose, end, '[', ']') ?? end;
            }
            final candidate = prose.substring(cursor, end);
            final nodes = document.parseInline(candidate);
            final element = nodes.length == 1 && nodes.first is md.Element
                ? nodes.first as md.Element
                : null;
            final url = element?.attributes[image ? 'src' : 'href'];
            if (url != null && isCommentMediaUrl(url)) {
              add(url);
              if (!image) {
                output.write(prose.substring(labelStart + 1, labelEnd - 1));
              }
              cursor = end;
              continue;
            }
            // An ordinary link must remain intact, including its destination.
            if (element?.tag == 'a' || element?.tag == 'img') {
              output.write(candidate);
              cursor = end;
              continue;
            }
          }
        }
        final angle = prose.startsWith('<http', cursor);
        final urlStart = angle ? cursor + 1 : cursor;
        if (prose.startsWith('https://', urlStart) ||
            prose.startsWith('http://', urlStart)) {
          var end = urlStart;
          var parens = 0;
          while (end < prose.length && !_urlBoundary.hasMatch(prose[end])) {
            if (prose[end] == '(') parens++;
            if (prose[end] == ')') {
              if (parens == 0) break;
              parens--;
            }
            end++;
          }
          final raw = prose
              .substring(urlStart, end)
              .replaceFirst(_trailingPunctuation, '');
          if (isCommentMediaUrl(raw)) {
            add(raw);
            cursor = urlStart + raw.length;
            if (angle && cursor < prose.length && prose[cursor] == '>') {
              cursor++;
            }
            continue;
          }
        }
        output.write(prose[cursor++]);
      }
      return output.toString();
    },
    protectInlineCode: false,
    protectEscapes: false,
    protectReferences: true,
  );
  final clean = text.trim().isEmpty
      ? ''
      : text.replaceFirst(RegExp(r'^(?:[ \t]*\r?\n)+'), '').trimRight();
  return ParsedCommentContent(clean, List.unmodifiable(media));
}

List<CommentMedia> extractCommentMedia(String body) =>
    parseCommentContent(body).media;
String commentTextWithoutMedia(String body) => parseCommentContent(body).text;

/// Search snippets never reveal hidden spoilers or load their attachments.
String commentSearchText(String body) {
  final redacted = mapRedditMarkdownProse(
    body,
    (prose) => prose,
    transformSpoiler: (_) => 'Spoiler',
  );
  final document = md.Document(encodeHtml: false);
  return document
      .parse(commentTextWithoutMedia(redacted))
      .map((node) => node.textContent)
      .join('\n');
}

/// Resolves opaque emote/image IDs from metadata without changing code examples.
String resolveCommentBodyMedia(String body, Object? metadata) {
  if (metadata is! Map) return body;
  return mapRedditMarkdownProse(
    body,
    (prose) => prose.replaceAllMapped(_inlineGifPattern, (match) {
      final id = match[2]!.split('|').last;
      final item = metadata[id] ?? metadata[match[2]];
      if (item is! Map || item['s'] is! Map) return match[0]!;
      final source = item['s'] as Map;
      final raw = source['gif'] ?? source['u'] ?? source['mp4'];
      if (raw is! String) return match[0]!;
      final url = raw.replaceAll('&amp;', '&');
      return isCommentMediaUrl(url) ? '![media]($url)' : match[0]!;
    }),
  );
}
