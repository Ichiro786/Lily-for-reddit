// Reproducible visual review artifacts using sample repository fixtures.
// Run explicitly; screenshots are generated under build/, not shipped in the app.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/features/settings/settings_screen.dart';
import 'package:luli_for_reddit/features/user/user_screen.dart';
import '../test/profile_revamp_test.dart' show ProfileRepo, ProfileAuth;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? '.tools/flutter';
    final fonts = '$root/bin/cache/artifacts/material_fonts';
    for (final family in ['Roboto', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final name
          in family == 'Roboto'
              ? ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']
              : ['MaterialIcons-Regular.otf']) {
        final bytes = await File('$fonts/$name').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });
  for (final mode in ['dark', 'light', 'narrow']) {
    testWidgets('visual review $mode', (tester) async {
      final narrow = mode == 'narrow';
      tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final oldInterval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () =>
            VisibilityDetectorController.instance.updateInterval = oldInterval,
      );
      // This file is an explicitly invoked widget test outside test/.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          redditRepositoryProvider.overrideWithValue(ProfileRepo()),
          authControllerProvider.overrideWith(ProfileAuth.new),
          authModeProvider.overrideWith((ref) async => 'oauth'),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final base = mode == 'light'
          ? AppTheme.light(null)
          : AppTheme.dark(
              narrow
                  ? ColorScheme.fromSeed(
                      seedColor: Colors.teal,
                      brightness: Brightness.dark,
                    )
                  : null,
              amoled: true,
            );
      final theme = base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
        appBarTheme: base.appBarTheme.copyWith(
          titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
            fontFamily: 'Roboto',
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: base.filledButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(
              base.filledButtonTheme.style?.textStyle
                  ?.resolve({})
                  ?.copyWith(fontFamily: 'Roboto'),
            ),
          ),
        ),
      );
      final boundary = GlobalKey();
      final draft = TextEditingController();
      addTearDown(draft.dispose);
      Future<void> capture(String name) async {
        final rendered =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await rendered.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final directory = Directory('build/ui-revamp-previews')
            ..createSync(recursive: true);
          File(
            '${directory.path}/$name-$mode.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        });
      }

      Future<void> show(Widget child) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
                  child: child!,
                ),
                home: child,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(const SettingsScreen());
      await capture('settings');
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await capture('appearance');
      for (final name in ['alice', 'bob']) {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => UserScreen(username: name),
            ),
          ],
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: theme,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
                  child: child!,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(name == 'alice' ? 'my-profile' : 'public-profile');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        router.dispose();
      }
      await show(
        Scaffold(
          appBar: AppBar(title: const Text('r/flutter')),
          body: ListView(
            children: [
              for (var depth = 0; depth < 3; depth++)
                M3ECommentCard(
                  author: ['alice', 'bob', 'charlie'][depth],
                  timeAgo: '${depth + 1}h',
                  depth: depth,
                  score: 184 - depth * 60,
                  body: [
                    'A quiet night in the city. Really love the atmosphere.',
                    'The lighting is beautiful. Thanks for sharing!',
                    'This is going straight into my saved posts.',
                  ][depth],
                  onViewProfile: () {},
                  onVote: (_) {},
                  onReply: () {},
                  onOverflow: () {},
                  onToggleCollapse: () {},
                  onSave: () {},
                ),
            ],
          ),
          bottomNavigationBar: CommentComposeBar(
            controller: draft,
            onSubmit: (_) {},
          ),
        ),
      );
      await capture('comments');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
