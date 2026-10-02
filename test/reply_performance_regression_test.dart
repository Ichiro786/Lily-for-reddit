import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:luli_for_reddit/core/drafts.dart';
import 'package:luli_for_reddit/core/reddit_comment_media.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/media/attachment.dart';
import 'package:luli_for_reddit/features/media/attachment_bar.dart';
import 'package:luli_for_reddit/features/post/compose_sheet.dart';
import 'package:luli_for_reddit/features/post/interactive_spoiler.dart';
import 'package:luli_for_reddit/features/post/reply_editor.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'support/interaction_fixture.dart';

class ReplyRepository extends InteractionRepository {
  final sent = Completer<Comment>();
  int calls = 0;
  @override
  Future<Comment> reply({
    required String parentFullname,
    required String text,
    int depth = 0,
    String? richtextJson,
  }) {
    calls++;
    return sent.future;
  }
}

class ReplyHarness extends ConsumerWidget {
  const ReplyHarness({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showReplySheet(
          context,
          ref,
          parentFullname: 't1_c1',
          parentDepth: 0,
          replyingTo: 'alice',
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('formatting retains reversed selection and clears IME composition', () {
    final c = TextEditingController.fromValue(
      const TextEditingValue(
        text: 'one two three',
        selection: TextSelection(baseOffset: 7, extentOffset: 4),
        composing: TextRange(start: 4, end: 7),
      ),
    );
    addTearDown(c.dispose);
    insertReplyMarkdown(c, '**', '**');
    expect(c.text, 'one **two** three');
    expect(c.selection, const TextSelection(baseOffset: 6, extentOffset: 9));
    expect(c.value.composing, TextRange.empty);
  });
  test(
    'formatting invalid selection and GIF replacement retain surrounding text',
    () {
      final c = TextEditingController(text: '🙂 hello');
      addTearDown(c.dispose);
      insertReplyMarkdown(c, '`', '`');
      expect(c.text, '🙂 hello`text`');
      c.value = const TextEditingValue(
        text: 'before chosen after',
        selection: TextSelection(baseOffset: 7, extentOffset: 13),
      );
      insertReplyGif(c, 'https://example.com/a.gif');
      expect(c.text, 'before \nhttps://example.com/a.gif\n after');
      expect(c.selection.isCollapsed, true);
    },
  );
  test('media links preserve escaped brackets and inline-code captions', () {
    for (final label in [r'a \] caption', '`a]b`', "don't laugh"]) {
      final parsed = parseCommentContent('[$label](https://i.redd.it/a.png)');
      expect(parsed.media.single.url, 'https://i.redd.it/a.png');
      expect(parsed.text, label);
    }
  });
  test('escaped spoiler close never exposes media or search text', () {
    const body =
        r'>!private \!< still hidden https://i.redd.it/a.gif!< visible';
    expect(parseCommentContent(body).media, isEmpty);
    expect(commentSearchText(body), 'Spoiler visible');
    final nodes = md.Document(
      inlineSyntaxes: [SpoilerInlineSyntax()],
    ).parseInline(body);
    expect((nodes.first as md.Element).tag, 'spoiler');
    expect(nodes.first.textContent, contains('still hidden'));
  });

  const channel = MethodChannel('lily/media_clipboard');
  test(
    'Android clipboard preserves image MIME and handles empty clipboard',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'readImage');
        return {
          'bytes': Uint8List.fromList([1, 2]),
          'mimeType': 'image/webp',
        };
      });
      final image = await pasteImageAttachment();
      expect(image!.filename, 'pasted.webp');
      expect(image.mimeType, 'image/webp');
      expect(image.bytes, [1, 2]);
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await pasteImageAttachment(), isNull);
    },
  );
  test(
    'missing Android implementation produces an actionable message',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(pasteImageAttachment(), throwsA(isA<UnsupportedError>()));
    },
  );

  testWidgets('attachment reads are serialized and safe after disposal', (
    tester,
  ) async {
    final pending = Completer<MediaAttachment?>();
    var calls = 0, changed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentControls(
            media: null,
            onChanged: (_) => changed++,
            onError: (_) => changed++,
            imagePicker: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Attach image'));
    await tester.pump();
    await tester.tap(find.byTooltip('Attach image'));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    pending.complete(null);
    await tester.pump();
    expect(changed, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('attachment errors hide plugin internals', (tester) async {
    String? error;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentControls(
            media: null,
            onChanged: (_) {},
            onError: (e) => error = e,
            imagePaster: () async =>
                throw MissingPluginException('secret channel'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Paste image'));
    await tester.pump();
    expect(error, contains('unavailable'));
    expect(error, isNot(contains('secret')));
  });

  Future<ProviderContainer> open(
    WidgetTester tester, {
    ReplyRepository? repo,
    Future<String?> Function(BuildContext, WidgetRef)? gif,
  }) async {
    final c = interactionContainer(
      prefs: await SharedPreferences.getInstance(),
      repository: repo,
      extraOverrides: [
        if (gif != null) replyGifPickerProvider.overrideWithValue(gif),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: const ReplyHarness(),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    return c;
  }

  testWidgets('reply waits for sheet entry before keyboard focus', (
    tester,
  ) async {
    await open(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      false,
    );
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      true,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'programmatic GIF insertion persists and preview returns to editor',
    (tester) async {
      final c = await open(
        tester,
        gif: (_, __) async => 'https://example.com/a.gif',
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '**hello**');
      await tester.tap(find.text('GIF'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        c.read(draftsProvider).get('reply_t1_c1'),
        contains('https://example.com/a.gif'),
      );
      await tester.tap(find.byTooltip('Preview Markdown'));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('Write reply'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        contains('**hello**'),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed reply is serialized and retains its draft', (
    tester,
  ) async {
    final repo = ReplyRepository();
    final c = await open(tester, repo: repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'keep this');
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pump();
    expect(repo.calls, 1);
    repo.sent.completeError(StateError('network internals'));
    await tester.pump();
    expect(find.textContaining('Your text is kept'), findsOneWidget);
    expect(c.read(draftsProvider).get('reply_t1_c1'), 'keep this');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('late submission never clears a newer reply draft', (
    tester,
  ) async {
    final repo = ReplyRepository();
    final c = await open(tester, repo: repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'old reply');
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pumpAndSettle();
    await c.read(draftsProvider).save('reply_t1_c1', 'new draft');
    repo.sent.complete(interactionComment());
    await tester.pump();
    expect(c.read(draftsProvider).get('reply_t1_c1'), 'new draft');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('account change blocks posting an old open composer', (
    tester,
  ) async {
    final repo = ReplyRepository();
    final c = await open(tester, repo: repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'old account draft');
    c.read(authSessionEpochProvider.notifier).state++;
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pump();
    expect(repo.calls, 0);
    expect(find.textContaining('Your account changed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('successful reply clears the sent draft', (tester) async {
    final repo = ReplyRepository();
    final c = await open(tester, repo: repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sent draft');
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pump();
    repo.sent.complete(interactionComment());
    await tester.pumpAndSettle();
    expect(c.read(draftsProvider).get('reply_t1_c1'), isNull);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'reply fits narrow large-text keyboard viewport without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 330);
      addTearDown(tester.view.reset);
      final c = interactionContainer(
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.light(null),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const ReplyHarness(),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Reply'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
