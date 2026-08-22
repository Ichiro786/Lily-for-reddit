import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/post/comment_media_helper.dart';
import 'package:luli_for_reddit/features/post/interactive_spoiler.dart';

Widget _harness(Widget child) => MaterialApp(
      theme: AppTheme.dark(null),
      home: Scaffold(body: child),
    );

M3ECommentCard _card({
  required String rawBody,
  bool withRichBody = true,
  bool collapsed = false,
}) {
  // Mirrors the explicit sheet construction used by the post-detail screen.
  final styleSheet = MarkdownStyleSheet(
    p: const TextStyle(fontSize: 14, height: 1.4),
  );
  return M3ECommentCard(
    author: 'alice',
    timeAgo: '1h',
    body: rawBody,
    richBody: withRichBody
        ? buildCommentMarkdownBody(
            commentTextWithoutMedia(rawBody),
            styleSheet,
          )
        : null,
    isCollapsed: collapsed,
  );
}

void main() {
  testWidgets('plain comment text renders through the markdown pipeline',
      (tester) async {
    await tester.pumpWidget(_harness(_card(rawBody: 'Plain comment body')));

    expect(find.textContaining('Plain comment body', findRichText: true),
        findsOneWidget);
  });

  testWidgets('markdown formatting is rendered instead of raw syntax',
      (tester) async {
    await tester.pumpWidget(
        _harness(_card(rawBody: 'This is **bold** and *italic* text')));

    // No raw markers survive rendering.
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('*italic*', findRichText: true), findsNothing);

    // The styled words are present.
    expect(find.textContaining('bold', findRichText: true), findsOneWidget);
    expect(find.textContaining('italic', findRichText: true), findsOneWidget);

    // Bold emphasis carries a bold span.
    final rich = tester.widgetList<RichText>(find.byType(RichText));
    final boldSpans = <String>[];
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        final weight = span.style?.fontWeight;
        if (weight != null &&
            weight.value >= FontWeight.w600.value &&
            span.text != null) {
          boldSpans.add(span.text!);
        }
        final children = span.children;
        if (children != null) {
          for (final child in children) {
            walk(child);
          }
        }
      }
    }

    for (final r in rich) {
      walk(r.text);
    }
    expect(boldSpans, contains('bold'));
  });

  testWidgets('reddit spoilers normalize into the interactive spoiler widget',
      (tester) async {
    await tester.pumpWidget(
        _harness(_card(rawBody: 'Look here >!the secret!< right away')));

    // Raw spoiler syntax must not leak through.
    expect(find.textContaining('>!', findRichText: true), findsNothing);

    // Hidden state comes from the existing InteractiveSpoiler mechanism.
    expect(find.text('Spoiler (Tap to reveal)'), findsOneWidget);
    expect(find.text('the secret'), findsNothing);

    await tester.tap(find.text('Spoiler (Tap to reveal)'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('the secret'), findsOneWidget);
    expect(find.text('Spoiler (Tap to reveal)'), findsNothing);

    // Tapping again re-hides the content.
    await tester.tap(find.text('the secret'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('the secret'), findsNothing);
    expect(find.text('Spoiler (Tap to reveal)'), findsOneWidget);
  });

  testWidgets('links render without raw markdown syntax',
      (tester) async {
    await tester.pumpWidget(_harness(
        _card(rawBody: 'See [Flutter docs](https://flutter.dev) for more')));

    expect(find.textContaining('](', findRichText: true), findsNothing);
    expect(
        find.textContaining('Flutter docs', findRichText: true),
        findsOneWidget);
  });

  testWidgets('collapsed comments hide the rendered body',
      (tester) async {
    await tester.pumpWidget(
        _harness(_card(rawBody: 'Hidden **body**', collapsed: true)));

    expect(find.textContaining('Hidden', findRichText: true), findsNothing);
    expect(find.textContaining('**', findRichText: true), findsNothing);
  });

  testWidgets('cards without rich content fall back to plain text',
      (tester) async {
    await tester.pumpWidget(
        _harness(_card(rawBody: 'Plain fallback body', withRichBody: false)));

    expect(find.text('Plain fallback body'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsNothing);
  });
}
