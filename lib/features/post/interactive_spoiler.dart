import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/theme/shape_tokens.dart';
import '../../core/theme/motion_tokens.dart';
import '../../core/url_launcher_helper.dart';
import '../../core/reddit_markdown.dart';
import '../../core/root_messenger.dart';
import 'comment_content.dart';
import 'comment_media_helper.dart';

/// Parses native Reddit markers after the Markdown code/escape rules.
class SpoilerInlineSyntax extends md.InlineSyntax {
  SpoilerInlineSyntax() : super(r'>!([\s\S]*?)!<');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('spoiler', [md.Text(match[1] ?? '')]));
    return true;
  }
}

// A spoiler at the start of a line must be parsed before the blockquote rule.
class SpoilerBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^ {0,3}>!');
  @override
  bool canParse(md.BlockParser parser) {
    if (!super.canParse(parser)) return false;
    for (var i = 0; parser.peek(i) != null; i++) {
      final line = parser.peek(i)!.content;
      if (line.contains('!<')) return true;
      if (line.trim().isEmpty) break;
    }
    return false;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[];
    do {
      lines.add(parser.current.content);
      parser.advance();
    } while (!parser.isDone && !lines.last.contains('!<'));
    return md.Element('p', parser.document.parseInline(lines.join('\n')));
  }
}

/// Builds a canonical Material 3 Expressive [MarkdownStyleSheet] shared across
/// post selftext and comments.
MarkdownStyleSheet buildM3EMarkdownStyleSheet(ThemeData theme) {
  final cs = theme.colorScheme;
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(
      fontSize: 15,
      height: 1.45,
      color: cs.onSurface,
    ),
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14.5,
      height: 1.4,
      fontStyle: FontStyle.italic,
      color: cs.onSurface.withValues(alpha: 0.9),
    ),
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    blockquoteDecoration: BoxDecoration(
      color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: cs.primary, width: 3.5)),
    ),
    codeblockDecoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(10),
    code: TextStyle(
      backgroundColor: Colors.transparent,
      fontFamily: 'monospace',
      color: cs.onSurfaceVariant,
    ),
    a: TextStyle(color: cs.primary, decoration: TextDecoration.underline),
  );
}

/// The single intentional rendering path for comment Markdown.
///
/// Composes native spoiler, superscript and mention syntax with link handling
/// so every consumer — the
/// flattened-comment presentation provider and tests — renders comment bodies
/// identically instead of duplicating configuration.
///
/// Text selection is deliberately NOT enabled: flutter_markdown ignores
/// element builders while building selectable spans, which would silently
/// disable interactive spoilers. Working spoilers take priority.
MarkdownBody buildCommentMarkdownBody(
  String body,
  MarkdownStyleSheet styleSheet,
) {
  return MarkdownBody(
    data: body,
    builders: {'spoiler': RedditSpoilerBuilder()},
    blockSyntaxes: [SpoilerBlockSyntax()],
    inlineSyntaxes: [
      SpoilerInlineSyntax(),
      RedditSuperscriptSyntax(),
      RedditMentionSyntax(),
    ],
    extensionSet: md.ExtensionSet.gitHubFlavored,
    sizedImageBuilder: (image) => Text(image.alt ?? 'Image unavailable'),
    styleSheet: styleSheet,
    onTapLink: (_, href, __) async {
      if (href != null && !await launchSmartUrl(href)) {
        showRootSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    },
  );
}

class InteractiveSpoiler extends StatefulWidget {
  const InteractiveSpoiler({super.key, required this.text});

  final String text;

  @override
  State<InteractiveSpoiler> createState() => _InteractiveSpoilerState();
}

class _InteractiveSpoilerState extends State<InteractiveSpoiler> {
  bool _revealed = false;

  @override
  void didUpdateWidget(covariant InteractiveSpoiler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _revealed = !_revealed),
      child: AnimatedContainer(
        duration: MotionTokens.feedback(context),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _revealed
              ? scheme.surfaceContainer
              : scheme.surfaceContainerHighest,
          borderRadius: ShapeTokens.extraSmall,
        ),
        child:
            _revealed &&
                (extractCommentMedia(widget.text).isNotEmpty ||
                    RegExp(r'[*_\[\]\n~`^]|[ru]/').hasMatch(widget.text))
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _revealed = false),
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Hide spoiler'),
                  ),
                  CommentContent(
                    body: widget.text,
                    styleSheet: buildM3EMarkdownStyleSheet(theme),
                  ),
                ],
              )
            : Text(
                _revealed ? widget.text : 'Spoiler (Tap to reveal)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: _revealed ? FontWeight.normal : FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class RedditSpoilerBuilder extends MarkdownElementBuilder {
  RedditSpoilerBuilder();

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return InteractiveSpoiler(text: element.textContent);
  }
}

String normalizeRedditSpoilers(String markdown) {
  // Compatibility for callers of the old normalization helper. The renderer
  // parses native >! markers directly and never preprocesses Markdown code.
  final pattern = RegExp(r'>!([\s\S]*?)!<|(?<![>\w!])!([^!\n]*?)!<');
  return mapRedditMarkdownProse(
    markdown,
    (prose) => prose.replaceAllMapped(pattern, (match) {
      final text = match.group(1) ?? match.group(2) ?? '';
      final escaped = text
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      return '<spoiler>$escaped</spoiler>';
    }),
  );
}
