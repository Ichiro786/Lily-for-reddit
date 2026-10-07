import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/profile/profile_header.dart';
import 'package:luli_for_reddit/features/profile/profile_hero.dart';
import 'package:luli_for_reddit/features/profile/profile_media.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/features/user/user_screen.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'package:luli_for_reddit/models/post.dart';
import 'package:luli_for_reddit/models/reddit_user.dart';
import 'support/interaction_fixture.dart';

class ProfileAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession(username: 'alice');
  void signOut() => state = const AsyncData(null);
}

RedditUser profile(String name) => RedditUser(
  name: name,
  displayName: 'A display name',
  description: 'A real biography',
  created: DateTime.utc(2023),
  linkKarma: 12340,
  commentKarma: 8100,
);

class ProfileRepo extends InteractionRepository {
  bool aboutFails = false;
  final pages = <String?>[];
  final privateRequests = <String>[];
  @override
  Future<RedditUser> getUserAbout(String username) async {
    if (aboutFails) throw StateError('offline');
    return profile(username);
  }

  @override
  Future<Listing<Post>> getUserPosts(
    String username, {
    String where = 'submitted',
    String? after,
  }) async {
    if (where == 'upvoted') privateRequests.add(where);
    pages.add(after);
    return Listing(
      items: [
        for (var i = 0; i < 25; i++)
          interactionPost().copyWith(
            id: '${after ?? 'first'}-$i',
            fullname: 't3_${after ?? 'first'}-$i',
            title: '${after ?? 'first'} post $i',
          ),
      ],
      after: after == null ? 'next' : null,
    );
  }

  @override
  Future<Listing<Comment>> getUserComments(
    String username, {
    String? after,
  }) async => const Listing(items: [], after: null);
  @override
  Future<Listing<Object>> getUserSaved(String username, {String? after}) async {
    privateRequests.add('saved');
    return const Listing(items: [], after: null);
  }
}

Future<ProviderContainer> mount(
  WidgetTester tester,
  ProfileRepo repo, {
  String username = 'alice',
}) async {
  SharedPreferences.setMockInitialValues({});
  final c = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      redditRepositoryProvider.overrideWithValue(repo),
      authControllerProvider.overrideWith(ProfileAuth.new),
    ],
  );
  addTearDown(c.dispose);
  await c.read(authControllerProvider.future);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => UserScreen(username: username),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('Settings destination')),
      ),
      GoRoute(
        path: '/compose_message',
        builder: (_, state) =>
            Scaffold(body: Text('Message ${state.uri.queryParameters['to']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: AppTheme.dark(null, amoled: true),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUp(() {
    final controller = VisibilityDetectorController.instance;
    final old = controller.updateInterval;
    controller.updateInterval = Duration.zero;
    addTearDown(() => controller.updateInterval = old);
  });
  test(
    'profile parser keeps authenticated media queries and falls back from empty fields',
    () {
      final user = RedditUser.fromData({
        'name': 'alice',
        'icon_img': '  ',
        'created_utc': 1700000000,
        'subreddit': {
          'title': ' Alice ',
          'icon_img': 'https://img.test/avatar?s=64&amp;token=a',
          'banner_background_image': '',
          'banner_img': 'https://img.test/banner?token=b&amp;s=1',
          'public_description': ' biography ',
        },
      });
      expect(user.displayName, 'Alice');
      expect(user.iconUrl, 'https://img.test/avatar?s=64&token=a');
      expect(user.bannerUrl, 'https://img.test/banner?token=b&s=1');
      expect(user.description, 'biography');
      expect(user.copyWith(displayName: 'Changed').displayName, 'Changed');
      expect(validProfileImage('javascript:alert(1)'), false);
      expect(validProfileImage('https://img.test/photo'), true);
    },
  );

  testWidgets(
    'public profile exposes public activity and existing message action',
    (tester) async {
      final repo = ProfileRepo();
      await mount(tester, repo, username: 'bob');
      expect(find.byType(ProfileBanner), findsOneWidget);
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(find.text('A display name'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Upvoted'), findsNothing);
      expect(find.text('Manage accounts'), findsNothing);
      expect(repo.privateRequests, isEmpty);
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(find.text('Message bob'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner tabs disappear safely after signing out even from Saved', (
    tester,
  ) async {
    final repo = ProfileRepo();
    final c = await mount(tester, repo, username: 'ALICE');
    expect(find.text('Manage accounts'), findsOneWidget);
    expect(
      tester
          .widget<DefaultTabController>(find.byType(DefaultTabController))
          .length,
      5,
    );
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Upvoted'), findsOneWidget);
    await tester.ensureVisible(find.text('Saved'));
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(repo.privateRequests, contains('saved'));
    (c.read(authControllerProvider.notifier) as ProfileAuth).signOut();
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Upvoted'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested profile feed loads the next page while scrolling', (
    tester,
  ) async {
    final repo = ProfileRepo();
    await mount(tester, repo);
    for (var i = 0; i < 18 && !repo.pages.contains('next'); i++) {
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    expect(repo.pages, contains('next'));
    expect(repo.pages.where((page) => page == 'next'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile media fallbacks and long content fit 320px RTL at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(null, amoled: true),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ProfileHero(
                    user: profile('averylongusername_123456789').copyWith(
                      displayName: 'A very long display name for a profile',
                      description: 'Long biography ' * 20,
                    ),
                    isSelf: true,
                    onManageAccount: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileBanner), findsOneWidget);
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all three real profile statistics share one row at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileHero(user: profile('alice'), isSelf: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text('Post karma')).dy;
      expect(
        tester.getTopLeft(find.text('Comment karma')).dy,
        closeTo(first, 1),
      );
      expect(tester.getTopLeft(find.text('Reddit age')).dy, closeTo(first, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact settings profile keeps identity when about request fails',
    (tester) async {
      final repo = ProfileRepo()..aboutFails = true;
      SharedPreferences.setMockInitialValues({});
      var opened = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [redditRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: CurrentProfileEntry(
                username: 'alice',
                onTap: () => opened = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('u/alice'), findsOneWidget);
      await tester.tap(find.text('alice'));
      expect(opened, true);
      expect(tester.takeException(), isNull);
    },
  );
}
