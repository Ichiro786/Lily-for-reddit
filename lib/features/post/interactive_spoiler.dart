import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

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
          borderRadius: BorderRadius.circular(6),
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
