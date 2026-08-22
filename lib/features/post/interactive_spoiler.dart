import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/theme/shape_tokens.dart';
import '../../core/url_launcher_helper.dart';

/// Turns the `<spoiler>…</spoiler>` tags produced by [normalizeRedditSpoilers]
/// into real markdown elements, which is what lets [RedditSpoilerBuilder]
/// replace them with an [InteractiveSpoiler] widget. Without this syntax the
/// markdown package emits raw HTML text and the builder never fires.
class SpoilerInlineSyntax extends md.InlineSyntax {
  SpoilerInlineSyntax() : super(r'<spoiler>([\s\S]*?)</spoiler>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('spoiler', [md.Text(match[1] ?? '')]));
    return true;
  }
}

/// The single intentional rendering path for comment Markdown.
///
/// Composes the existing spoiler pipeline ([normalizeRedditSpoilers] +
/// [RedditSpoilerBuilder]) with link handling so every consumer — the
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
    data: normalizeRedditSpoilers(body),
    builders: {
      'spoiler': RedditSpoilerBuilder(),
    },
    inlineSyntaxes: [SpoilerInlineSyntax()],
    styleSheet: styleSheet,
    onTapLink: (_, href, __) {
      if (href != null) {
        launchSmartUrl(href);
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _revealed = !_revealed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _revealed
              ? scheme.surfaceContainer
              : scheme.surfaceContainerHighest,
          borderRadius: ShapeTokens.extraSmall,
        ),
        child: Text(
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
  final pattern = RegExp(r'>!([\s\S]*?)!<|!([^!\n]*?)!<');
  return markdown.replaceAllMapped(pattern, (match) {
    final text = match.group(1) ?? match.group(2) ?? '';
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '<spoiler>$escaped</spoiler>';
  });
}
