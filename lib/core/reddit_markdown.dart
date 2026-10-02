import 'package:markdown/markdown.dart' as md;

/// Transforms prose without rewriting code examples or escaped punctuation.
/// Source slices are retained directly, avoiding sentinel collisions with text.
String mapRedditMarkdownProse(
  String source,
  String Function(String) transform, {
  bool protectSpoilers = false,
  bool protectReferences = false,
}) {
  final blocks = <(int, int)>[];
  final lines = RegExp(r'[^\n]*(?:\n|$)').allMatches(source);
  String? fence;
  int? fenceStart;
  for (final line in lines) {
    final marker = RegExp(
      r'^(?: {0,3}> ?)* {0,3}(?:(?:[-+*]|\d+[.)]) +)?(`{3,}|~{3,})(.*)',
    ).firstMatch(line.group(0)!);
    if (fence != null) {
      if (marker != null &&
          marker[1]![0] == fence[0] &&
          marker[1]!.length >= fence.length &&
          marker[2]!.trim().isEmpty) {
        blocks.add((fenceStart!, line.end));
        fence = null;
      }
    } else if (marker != null) {
      fence = marker[1];
      fenceStart = line.start;
    } else if (RegExp(r'^(?: {4}|\t)').hasMatch(line.group(0)!) ||
        (protectReferences &&
            RegExp(r'^ {0,3}\[[^\]]+\]:').hasMatch(line.group(0)!))) {
      blocks.add((line.start, line.end));
    }
  }
  if (fence != null) blocks.add((fenceStart!, source.length));
  final output = StringBuffer();
  var cursor = 0;
  var proseStart = 0;
  var blockIndex = 0;
  void protect(int end) {
    output.write(transform(source.substring(proseStart, cursor)));
    output.write(source.substring(cursor, end));
    cursor = end;
    proseStart = end;
  }

  while (cursor < source.length) {
    while (blockIndex < blocks.length && blocks[blockIndex].$2 <= cursor) {
      blockIndex++;
    }
    if (blockIndex < blocks.length && cursor == blocks[blockIndex].$1) {
      protect(blocks[blockIndex++].$2);
      continue;
    }
    if (source[cursor] == '\\' && cursor + 1 < source.length) {
      protect(cursor + 2);
      continue;
    }
    if (source[cursor] == '`') {
      final start = cursor;
      var end = start;
      while (end < source.length && source[end] == '`') {
        end++;
      }
      final width = end - start;
      final nextBlock = blockIndex < blocks.length
          ? blocks[blockIndex].$1
          : source.length;
      for (final match in RegExp(r'`+').allMatches(source, end)) {
        if (match.start >= nextBlock) break;
        if (match.end - match.start == width) {
          protect(match.end);
          break;
        }
      }
      if (cursor != start) continue;
      cursor = end;
      continue;
    }
    if (protectSpoilers && source.startsWith('>!', cursor)) {
      final end = source.indexOf('!<', cursor + 2);
      if (end >= 0) {
        protect(end + 2);
        continue;
      }
    }
    cursor++;
  }
  output.write(transform(source.substring(proseStart)));
  return output.toString();
}

/// Reddit superscript, including the parenthesized multi-word form.
class RedditSuperscriptSyntax extends md.InlineSyntax {
  RedditSuperscriptSyntax() : super(r'\^(?:\(([^)\n]+)\)|([^\s^]+))');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element('sup', parser.document.parseInline(match[1] ?? match[2]!)),
    );
    return true;
  }
}

/// Mentions become normal links and cannot fire inside a Markdown code node.
class RedditMentionSyntax extends md.InlineSyntax {
  RedditMentionSyntax()
    : super(r'(?<![\w/])/?([ru])/([A-Za-z0-9_][A-Za-z0-9_-]{1,20})\b');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('a', match[0]!);
    element.attributes['href'] = 'https://reddit.com/${match[1]}/${match[2]}';
    parser.addNode(element);
    return true;
  }
}
