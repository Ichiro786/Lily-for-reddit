import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/drafts.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/compose/compose_post_screen.dart';
import 'package:luli_for_reddit/features/feed/feed_controller.dart';
import 'package:luli_for_reddit/features/history/history_store.dart';
import 'package:luli_for_reddit/features/media/attachment.dart';
import 'package:luli_for_reddit/features/media/giphy_picker.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';
import 'package:luli_for_reddit/features/post/post_actions.dart';
import 'package:luli_for_reddit/features/post/reply_submission.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/features/settings/settings_screen.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'support/interaction_fixture.dart';

class _Store extends SecureStore {
  _Store(this.key);
  String? key;
  @override
  Future<String?> get giphyKey async => key;
  @override
  Future<void> saveGiphyKey(String value) async => key = value;
}

class _Repo extends InteractionRepository {
  final hides = <Completer<void>>[];
  final replies = <String>[];
  var imageCalls = 0;
  @override
  Future<void> setHidden(String fullname, bool hidden) {
    final c = Completer<void>();
    hides.add(c);
    return c.future;
  }

  @override
  Future<Comment> reply({
    required String parentFullname,
    required String text,
    String? richtextJson,
    int depth = 0,
  }) async {
    replies.add(text);
    return interactionComment();
  }

  @override
  Future<Comment> replyWithImage({
    required String parentFullname,
    required String text,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    int depth = 0,
  }) async {
    imageCalls++;
    return interactionComment();
  }
}

Future<void> _gifHarness(
  WidgetTester tester,
  _Store store,
  Dio dio, {
  bool light = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        giphyDioFactoryProvider.overrideWithValue(() => dio),
      ],
      child: MaterialApp(
        theme: light ? AppTheme.light(null) : AppTheme.dark(null),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showGiphyPicker(context, ref),
              child: const Text('Open GIF'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open GIF'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('GIPHY inserted into a new post survives reopening its draft', (
    tester,
  ) async {
    final c = interactionContainer(
      prefs: await SharedPreferences.getInstance(),
      extraOverrides: [
        postGifPickerProvider.overrideWithValue(
          (_, __) async => 'https://media.giphy.com/reaction.gif',
        ),
      ],
    );
    addTearDown(c.dispose);
    Widget app() => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: ComposePostScreen()),
    );
    await tester.pumpWidget(app());
    await tester.ensureVisible(find.text('GIF'));
    await tester.tap(find.text('GIF'));
    await tester.pumpAndSettle();
    expect(
      jsonDecode(c.read(draftsProvider).get('compose_post')!)['body'],
      'https://media.giphy.com/reaction.gif',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    expect(find.text('https://media.giphy.com/reaction.gif'), findsOneWidget);
  });
  for (final light in [true, false]) {
    testWidgets('GIPHY fits landscape keyboard at 200% text, light=$light', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              h.resolve(
                Response(
                  requestOptions: o,
                  statusCode: 200,
                  data: {'data': []},
                ),
              );
            },
          ),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(_Store('key')),
            giphyDioFactoryProvider.overrideWithValue(() => dio),
          ],
          child: MaterialApp(
            theme: light ? AppTheme.light(null) : AppTheme.dark(null),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: const EdgeInsets.only(bottom: 220),
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showGiphyPicker(context, ref),
                  child: const Text('Open GIF'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open GIF'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'GIPHY parsing uses available renditions and skips malformed entries',
    () {
      final results = parseGiphyResults({
        'data': [
          {
            'title': 'hello',
            'images': {
              'original': {'url': 'https://media.giphy.com/a.gif'},
            },
          },
          {
            'images': {
              'original': {'url': 'https://media.giphy.com/b.gif'},
              'fixed_width': {'url': 'https://media.giphy.com/b-small.gif'},
            },
          },
          {
            'images': {
              'original': {'url': 'javascript:bad'},
            },
          },
          null,
        ],
      });
      expect(results.length, 2);
      expect(results.first.preview, results.first.full);
      expect(results.last.preview, endsWith('b-small.gif'));
      expect(() => parseGiphyResults({}), throwsFormatException);
    },
  );
  for (final status in [401, 403, 429, 414]) {
    test('GIPHY $status has an actionable error without the API key', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '?api_key=secret'),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: status,
        ),
      );
      final message = giphyFailureMessage(error);
      expect(message, isNot(contains('secret')));
      expect(
        message,
        contains(
          status == 429
              ? 'limit'
              : status == 414
              ? 'shorter'
              : 'key',
        ),
      );
    });
  }
  testWidgets(
    'missing key can be configured in the picker and starts trending',
    (tester) async {
      final store = _Store(null);
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              requests.add(o);
              h.resolve(
                Response(
                  requestOptions: o,
                  data: {'data': []},
                  statusCode: 200,
                ),
              );
            },
          ),
        );
      await _gifHarness(tester, store, dio);
      expect(find.text('Connect GIPHY'), findsWidgets);
      expect(requests, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('giphy-api-key')),
        '  personal-key  ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Connect GIPHY'));
      await tester.pumpAndSettle();
      expect(store.key, 'personal-key');
      expect(requests.single.path, endsWith('/trending'));
      expect(requests.single.queryParameters['api_key'], 'personal-key');
      expect(find.text('No GIFs found. Try another search.'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'GIPHY failure has retry and a key editor instead of an empty grid',
    (tester) async {
      final store = _Store('old');
      var calls = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              calls++;
              h.resolve(
                Response(
                  requestOptions: o,
                  statusCode: 200,
                  data: {
                    'data': [],
                    'meta': {'status': calls == 1 ? 403 : 200},
                  },
                ),
              );
            },
          ),
        );
      await _gifHarness(tester, store, dio);
      expect(find.textContaining('rejected this API key'), findsOneWidget);
      expect(find.text('No GIFs found. Try another search.'), findsNothing);
      await tester.tap(find.text('Update API key'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('giphy-api-key')),
        'new',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Connect GIPHY'));
      await tester.pumpAndSettle();
      expect(store.key, 'new');
      expect(calls, 2);
      expect(find.textContaining('rejected this API key'), findsNothing);
      await tester.tap(find.byTooltip('GIPHY API key'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('giphy-api-key')),
        'discard',
      );
      await tester.tap(find.text('Keep current key'));
      await tester.pumpAndSettle();
      expect(store.key, 'new');
      expect(calls, 3);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );
  testWidgets(
    'GIPHY typing debounces and disposal cancels the pending search',
    (tester) async {
      final requests = <(RequestOptions, RequestInterceptorHandler)>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(onRequest: (o, h) => requests.add((o, h))),
        );
      await _gifHarness(tester, _Store('key'), dio);
      await tester.enterText(find.byType(TextField), 'c');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'cat');
      await tester.pump(const Duration(milliseconds: 299));
      expect(requests.length, 1);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump();
      expect(requests.length, 2);
      expect(requests.last.$1.queryParameters['q'], 'cat');
      await tester.pumpWidget(const SizedBox());
      expect(requests.last.$1.cancelToken!.isCancelled, isTrue);
      for (final r in requests) {
        r.$2.resolve(
          Response(requestOptions: r.$1, statusCode: 200, data: {'data': []}),
        );
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'inline plus menu selects video before send, and send blocks during reads',
    (tester) async {
      final read = Completer<MediaAttachment?>();
      MediaAttachment? selected;
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(null),
          home: Scaffold(
            body: CommentComposeBar(
              videoPicker: () => read.future,
              onMediaSelected: (m) => selected = m,
              onSubmit: (_) => sends++,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'clip');
      await tester.tap(find.byTooltip('Add media'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      expect(sends, 0);
      read.complete(
        MediaAttachment(
          bytes: Uint8List.fromList([1]),
          filename: 'v.mp4',
          mimeType: 'video/mp4',
          isVideo: true,
        ),
      );
      await tester.pump();
      expect(selected!.isVideo, isTrue);
      await tester.pump();
      expect(find.text('Video'), findsOneWidget);
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pump();
      expect(sends, 1);
      expect(selected, isNull);
    },
  );
  testWidgets('inline GIF menu preserves draft text and cursor selection', (
    tester,
  ) async {
    final ctrl = TextEditingController(text: 'before after');
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentComposeBar(
            controller: ctrl,
            onPickGif: () async => 'https://media.giphy.com/a.gif',
          ),
        ),
      ),
    );
    ctrl.selection = const TextSelection.collapsed(offset: 7);
    await tester.tap(find.byTooltip('Add media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GIF'));
    await tester.pumpAndSettle();
    expect(ctrl.text, 'before \nhttps://media.giphy.com/a.gif\nafter');
  });
  test(
    'video replies share link dispatch; an account change aborts after upload',
    () async {
      final repo = _Repo();
      final media = MediaAttachment(
        bytes: Uint8List.fromList([1]),
        filename: 'v.mp4',
        mimeType: 'video/mp4',
        isVideo: true,
      );
      await submitMediaReply(
        repository: repo,
        parentFullname: 't3_p1',
        text: 'caption',
        depth: 0,
        media: media,
        requireSession: () {},
        uploadVideo: (_) async => 'https://files.catbox.moe/v.mp4',
      );
      expect(repo.replies.single, 'caption\n\nhttps://files.catbox.moe/v.mp4');
      expect(repo.imageCalls, 0);
      var active = true;
      await expectLater(
        submitMediaReply(
          repository: repo,
          parentFullname: 't3_p1',
          text: '',
          depth: 0,
          media: media,
          requireSession: () {
            if (!active) throw StateError('changed');
          },
          uploadVideo: (_) async {
            active = false;
            return 'https://files.catbox.moe/v.mp4';
          },
        ),
        throwsStateError,
      );
      expect(repo.replies.length, 1);
    },
  );
  test(
    'corrupt history preserves valid rows, rejects empty IDs and deduplicates',
    () async {
      SharedPreferences.setMockInitialValues({
        'history': [
          'broken',
          jsonEncode({'id': 'good', 'sub': 'flutter'}),
          jsonEncode({'id': 'good', 'sub': 'flutter'}),
          jsonEncode({'id': 4}),
          '{}',
        ],
      });
      final c = interactionContainer(
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      expect(c.read(historyControllerProvider).map((e) => e.id), ['good']);
      expect(
        c.read(historyControllerProvider.notifier).containsId('good'),
        isTrue,
      );
    },
  );
  test(
    'invalid saved settings cannot crash enum lookup or slider constraints',
    () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': 900,
        'defaultSort': -3,
        'postDisplay': 888,
        'textScale': 9.0,
        'subsCacheMinutes': -1,
        'topBarMode': 0,
        'showApiUsage': true,
      });
      final c = interactionContainer(
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      final s = c.read(settingsControllerProvider);
      expect(s.themeMode, ThemeMode.system);
      expect(s.defaultSort, PostSort.hot);
      expect(s.postDisplay, PostDisplay.large);
      expect(s.textScale, 1.4);
      expect(s.subsCacheMinutes, 1);
    },
  );
  test(
    'feed state preserves its pagination cursor unless explicitly cleared',
    () {
      const state = FeedState(
        posts: [],
        sort: PostSort.hot,
        time: TopTime.day,
        after: 'next',
      );
      expect(state.copyWith(loadingMore: true).after, 'next');
      expect(state.copyWith(after: null).after, isNull);
    },
  );
  testWidgets('Settings has no redundant For You or top-toolbar controls', (
    tester,
  ) async {
    final c = interactionContainer(
      prefs: await SharedPreferences.getInstance(),
      extraOverrides: [authModeProvider.overrideWith((_) async => 'oauth')],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: const Scaffold(body: SettingsList())),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(find.byType(ListView).first);
    final children =
        (list.childrenDelegate as SliverChildListDelegate).children;
    final titles = children.whereType<ListTile>().map(
      (e) => (e.title as Text?)?.data,
    );
    expect(titles, isNot(contains('Top bar')));
    final switches = children.whereType<SwitchListTile>().map(
      (e) => (e.title as Text?)?.data,
    );
    expect(switches, isNot(contains('"For You" feed (Beta)')));
    expect(switches, isNot(contains('Show API usage instead of search')));
  });
  testWidgets(
    'failed hide never commits local suppression; failed Undo keeps it',
    (tester) async {
      final repo = _Repo();
      final c = interactionContainer(
        repository: repo,
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () =>
                      showPostActionsSheet(context, ref, interactionPost()),
                  child: const Text('Actions'),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> hide() async {
        await tester.tap(find.text('Actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hide'));
        await tester.pumpAndSettle();
      }

      await hide();
      repo.hides.last.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        c.read(interactionVaultProvider).interactedPosts['p1']?.dismissed ??
            false,
        isFalse,
      );
      await hide();
      repo.hides.last.complete();
      await tester.pumpAndSettle();
      expect(
        c.read(interactionVaultProvider).interactedPosts['p1']!.dismissed,
        isTrue,
      );
      await tester.tap(find.text('Undo'));
      await tester.pump();
      repo.hides.last.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        c.read(interactionVaultProvider).interactedPosts['p1']!.dismissed,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
