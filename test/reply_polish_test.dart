import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:luli_for_reddit/core/reddit_comment_media.dart';
import 'package:luli_for_reddit/core/reddit_markdown.dart';
import 'package:luli_for_reddit/core/url_launcher_helper.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/post/interactive_spoiler.dart';

Widget app(Widget child) => MaterialApp(
  theme: AppTheme.dark(null),
  home: Scaffold(body: child),
);

void main() {
  test(
    'search previews hide spoilers and render readable Markdown captions',
    () {
      expect(
        commentSearchText(
          '**Visible** >!private https://i.redd.it/secret.gif!<',
        ),
        'Visible Spoiler',
      );
      expect(commentSearchText('    literal >!code!<'), contains('>!code!<'));
    },
  );

  test(
    'Markdown links resolve Reddit permalinks and reject invalid destinations',
    () async {
      expect(
        redditLinkUri('/r/flutter/comments/p1')?.toString(),
        'https://reddit.com/r/flutter/comments/p1',
      );
      expect(redditLinkUri('mailto:test@example.com')?.scheme, 'mailto');
      for (final invalid in [
        'javascript:alert(1)',
        'file:///tmp/a',
        'http:///broken',
        'https://%ZZ',
        '',
      ]) {
        expect(redditLinkUri(invalid), isNull);
        expect(await launchSmartUrl(invalid), isFalse);
      }
    },
  );

  testWidgets('tables, nested lists and long code remain usable at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final body =
        '| Name | Value |\n| --- | --- |\n| **Row** | value |\n\n- [x] done\n  - nested\n\n```\n${'long_code_' * 50}\n```';
    await tester.pumpWidget(
      app(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2),
          ),
          child: ListView(
            children: [
              buildCommentMarkdownBody(
                body,
                buildM3EMarkdownStyleSheet(AppTheme.dark(null)),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(Table), findsOneWidget);
    expect(find.textContaining('nested', findRichText: true), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  test(
    'code spans, indented code and long/unclosed fences never become media',
    () {
      for (final source in [
        '``https://i.redd.it/a.gif ` literal``',
        '    https://i.redd.it/a.gif',
        '````\nhttps://i.redd.it/a.gif\n```\n![img](emote|123)\n````',
        '~~~\nhttps://i.redd.it/a.gif',
        '> ```\n> https://i.redd.it/a.gif\n> ```',
        '- ```\n  https://i.redd.it/a.gif\n  ```',
      ]) {
        final parsed = parseCommentContent(source);
        expect(parsed.media, isEmpty, reason: source);
        expect(parsed.text, source.trimRight(), reason: source);
      }
    },
  );

  test(
    'media links handle balanced parentheses, angle destinations and titles',
    () {
      final parsed = parseCommentContent(
        '[**Photo**](https://example.com/a_(b).jpg "Title")\n![img](<https://example.com/a(b.jpg> "Title")',
      );
      expect(parsed.media.map((m) => m.url), [
        'https://example.com/a_(b).jpg',
        'https://example.com/a(b.jpg',
      ]);
      expect(parsed.text, '**Photo**');
    },
  );

  test('reference media links resolve without fetching unused definitions', () {
    final parsed = parseCommentContent(
      '![Picture][photo]\n[Caption][PHOTO]\n\n[photo]: https://i.redd.it/a.png "Caption"\n[unused]: https://i.redd.it/unused.png',
    );
    expect(parsed.media.map((m) => m.url), ['https://i.redd.it/a.png']);
    expect(parsed.text, contains('Caption'));
    expect(parsed.text, isNot(contains('![Picture]')));
  });

  test(
    'punctuation, escaped media and literal former sentinel names survive',
    () {
      expect(
        commentTextWithoutMedia('See https://i.redd.it/a.png, now!'),
        'See , now!',
      );
      const source =
          r'LILY_SPOILER_0_TOKEN `sample` LILY_CODE_0_TOKEN \![img](emote|123)';
      expect(commentTextWithoutMedia(source), source);
      expect(
        resolveCommentBodyMedia(source, {
          '123': {
            's': {'u': 'https://i.redd.it/a.png'},
          },
        }),
        source,
      );
    },
  );

  test('mixed GIF tokens and URLs retain source order and deduplicate', () {
    final parsed = parseCommentContent(
      'https://i.redd.it/a.png ![gif](giphy|abc) https://i.redd.it/a.png',
    );
    expect(parsed.media.map((m) => m.url), [
      'https://i.redd.it/a.png',
      'https://media.giphy.com/media/abc/giphy.gif',
    ]);
  });

  test(
    'Reddit superscript and mentions use normal Markdown nodes outside code',
    () {
      final doc = md.Document(
        inlineSyntaxes: [RedditSuperscriptSyntax(), RedditMentionSyntax()],
      );
      final nodes = doc.parseInline(
        '^(hello **world**) r/flutter /u/alice `r/private ^code`',
      );
      final superscript = nodes
          .whereType<md.Element>()
          .where((n) => n.tag == 'sup')
          .single;
      expect(superscript.textContent, 'hello world');
      final links = nodes.whereType<md.Element>().where((n) => n.tag == 'a');
      expect(links.map((n) => n.attributes['href']), [
        'https://reddit.com/r/flutter',
        'https://reddit.com/u/alice',
      ]);
      expect(
        nodes
            .whereType<md.Element>()
            .where((n) => n.tag == 'code')
            .single
            .textContent,
        'r/private ^code',
      );
    },
  );

  testWidgets('spoiler markers inside code and escapes remain literal', (
    tester,
  ) async {
    const body = '`>!secret!<`\n\n```\n>!example!<\n```\n\n\\>!escaped!<';
    await tester.pumpWidget(
      app(
        buildCommentMarkdownBody(
          body,
          buildM3EMarkdownStyleSheet(AppTheme.dark(null)),
        ),
      ),
    );
    expect(find.byType(InteractiveSpoiler), findsNothing);
    expect(
      find.textContaining('>!secret!<', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('>!example!<', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rich spoilers preserve formatting and hide again', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        buildCommentMarkdownBody(
          '>!**bold** & [link](https://flutter.dev)!<',
          buildM3EMarkdownStyleSheet(AppTheme.dark(null)),
        ),
      ),
    );
    expect(find.textContaining('bold', findRichText: true), findsNothing);
    await tester.tap(find.text('Spoiler (Tap to reveal)'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('bold & link', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('**bold**', findRichText: true), findsNothing);
    await tester.tap(find.text('Hide spoiler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('bold', findRichText: true), findsNothing);
  });

  testWidgets('a replaced spoiler returns to its hidden state', (tester) async {
    await tester.pumpWidget(app(const InteractiveSpoiler(text: 'first')));
    await tester.tap(find.text('Spoiler (Tap to reveal)'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    await tester.pumpWidget(app(const InteractiveSpoiler(text: 'second')));
    expect(find.text('second'), findsNothing);
    expect(find.text('Spoiler (Tap to reveal)'), findsOneWidget);
  });

  testWidgets(
    'narrow actions keep More aligned with voting and bookmarks beside Reply',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saved = 0;
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          app(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: Directionality(
                textDirection: direction,
                child: M3ECommentCard(
                  author: 'author',
                  timeAgo: '3mo',
                  body: 'reply',
                  score: 25057,
                  depth: 1,
                  onVote: (_) {},
                  onReply: () {},
                  onOverflow: () {},
                  onSave: () => saved++,
                ),
              ),
            ),
          ),
        );
        final save = find.byTooltip('Save comment');
        expect(
          tester.getRect(find.byTooltip('More comment options')).center.dy,
          tester.getRect(find.byTooltip('Upvote')).center.dy,
        );
        expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        await tester.tap(save);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(saved, 2);
    },
  );
}
