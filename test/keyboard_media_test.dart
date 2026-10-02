import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/features/media/attachment.dart';
import 'package:luli_for_reddit/features/media/attachment_bar.dart';
import 'package:luli_for_reddit/features/media/keyboard_media.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';
import 'reply_performance_regression_test.dart' show ReplyHarness;
import 'support/interaction_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('lily/media_clipboard');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final mime in keyboardImageMimeTypes) {
    test('keyboard preserves bytes and MIME: $mime', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final media = await readKeyboardAttachment(
        KeyboardInsertedContent(
          mimeType: mime,
          uri: 'content://ime/file',
          data: bytes,
        ),
      );
      expect(media.bytes, same(bytes));
      expect(media.mimeType, mime);
      expect(
        media.filename,
        endsWith(mime == 'image/jpeg' ? '.jpg' : '.${mime.split('/').last}'),
      );
    });
  }
  test('keyboard content URI fallback reads native bytes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readKeyboardImage');
      expect(call.arguments['uri'], 'content://ime/a');
      return {
        'bytes': Uint8List.fromList([1]),
        'mimeType': 'image/gif',
      };
    });
    expect(
      (await readKeyboardAttachment(
        const KeyboardInsertedContent(
          mimeType: 'image/gif',
          uri: 'content://ime/a',
        ),
      )).mimeType,
      'image/gif',
    );
  });
  test(
    'unsupported, empty and oversized keyboard content is actionable',
    () async {
      for (final item in [
        const KeyboardInsertedContent(
          mimeType: 'text/plain',
          uri: 'content://ime/a',
        ),
        const KeyboardInsertedContent(
          mimeType: 'image/gif',
          uri: 'https://invalid/a',
        ),
        KeyboardInsertedContent(
          mimeType: 'image/gif',
          uri: 'content://ime/a',
          data: Uint8List(maxKeyboardImageBytes + 1),
        ),
      ]) {
        await expectLater(
          readKeyboardAttachment(item),
          throwsA(isA<UnsupportedError>()),
        );
      }
    },
  );
  testWidgets(
    'inline keyboard sticker is selected before send and MIME survives',
    (tester) async {
      MediaAttachment? selected, sent;
      final controller = TextEditingController(text: 'hello');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentComposeBar(
              controller: controller,
              onMediaSelected: (m) => selected = m,
              onSubmit: (_) => sent = selected,
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.contentInsertionConfiguration!.allowedMimeTypes,
        containsAll(['image/gif', 'image/webp']),
      );
      field.contentInsertionConfiguration!.onContentInserted(
        KeyboardInsertedContent(
          mimeType: 'image/webp',
          uri: 'content://ime/a',
          data: Uint8List.fromList([1]),
        ),
      );
      // Submit while the asynchronous read is pending must preserve the text.
      field.onSubmitted!('hello');
      expect(controller.text, 'hello');
      await tester.pump();
      expect(selected!.mimeType, 'image/webp');
      field.onSubmitted!('hello');
      expect(sent!.filename, 'keyboard.webp');
      expect(controller.text, isEmpty);
      expect(selected, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Android commitContent reaches the focused comment editor', (
    tester,
  ) async {
    MediaAttachment? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentComposeBar(onMediaSelected: (m) => selected = m),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final calls = tester.testTextInput.log.where(
      (call) => call.method == 'TextInput.setClient',
    );
    final client = (calls.last.arguments as List)[0];
    final complete = Completer<void>();
    messenger.handlePlatformMessage(
      'flutter/textinput',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('TextInputClient.performAction', [
          client,
          'TextInputAction.commitContent',
          {
            'mimeType': 'image/gif',
            'uri': 'content://ime/a',
            'data': [71, 73, 70],
          },
        ]),
      ),
      (_) => complete.complete(),
    );
    await complete.future;
    await tester.pump();
    expect(selected!.mimeType, 'image/gif');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('keyboard read completion after closing composer is harmless', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentComposeBar(onMediaSelected: (_) => selected = true),
        ),
      ),
    );
    tester
        .widget<TextField>(find.byType(TextField))
        .contentInsertionConfiguration!
        .onContentInserted(
          const KeyboardInsertedContent(
            mimeType: 'image/png',
            uri: 'content://ime/a',
          ),
        );
    await tester.pumpWidget(const SizedBox());
    pending.complete({
      'bytes': Uint8List.fromList([1]),
      'mimeType': 'image/png',
    });
    await tester.pump();
    expect(selected, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reply sheet accepts keyboard GIF and keeps editing text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = interactionContainer(
      prefs: await SharedPreferences.getInstance(),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: ReplyHarness()),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'My reply');
    tester
        .widget<TextField>(find.byType(TextField))
        .contentInsertionConfiguration!
        .onContentInserted(
          KeyboardInsertedContent(
            mimeType: 'image/gif',
            uri: 'content://ime/a',
            data: Uint8List.fromList([71, 73, 70, 56, 57, 97]),
          ),
        );
    await tester.pump();
    expect(
      tester
          .widget<AttachmentControls>(find.byType(AttachmentControls))
          .media!
          .mimeType,
      'image/gif',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'My reply',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
