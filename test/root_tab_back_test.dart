import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/explore/explore_screen.dart';
import 'package:luli_for_reddit/features/feed/feed_controller.dart';
import 'package:luli_for_reddit/features/feed/feed_resume_store.dart';
import 'package:luli_for_reddit/features/home/home_shell.dart';
import 'package:luli_for_reddit/features/inbox/inbox_controller.dart';
import 'package:luli_for_reddit/features/multireddit/multireddit_providers.dart';
import 'package:luli_for_reddit/features/navigation/m3e_floating_nav_bar.dart';
import 'support/interaction_fixture.dart';

class EmptyFeed extends FeedController {
  @override
  Future<FeedState> build(String arg) async =>
      const FeedState(posts: [], sort: PostSort.hot, time: TopTime.day);
}

class Unread extends UnreadCountController {
  @override
  int build() => 0;
}

class Inbox extends InboxController {
  @override
  Future<InboxState> build(String arg) async => const InboxState(items: []);
}

void main() {
  for (final index in [1, 2, 3]) {
    testWidgets(
      'system back from tab $index pops nested routes then Home, then exits',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'notifyInboxPrompted': true,
          'checkUpdates': false,
        });
        final c = interactionContainer(
          prefs: await SharedPreferences.getInstance(),
          extraOverrides: [
            feedControllerProvider.overrideWith(EmptyFeed.new),
            unreadCountProvider.overrideWith(Unread.new),
            inboxControllerProvider.overrideWith(Inbox.new),
            popularSubredditsProvider.overrideWith((ref) async => []),
            subscribedSubredditsProvider.overrideWith((ref) async => []),
            myMultiredditsProvider.overrideWith((ref) async => []),
            accountsProvider.overrideWith((ref) async => []),
            authModeProvider.overrideWith((ref) async => 'oauth'),
          ],
        );
        addTearDown(c.dispose);
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeShell()),
            GoRoute(
              path: '/nested',
              builder: (_, __) => const Scaffold(body: Text('Nested screen')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp.router(
              theme: AppTheme.dark(null),
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        M3EFloatingNavBar bar() =>
            tester.widget(find.byType(M3EFloatingNavBar));
        for (var iteration = 0; iteration < 2; iteration++) {
          bar().onTap(index);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(bar().currentIndex, index);
          router.push('/nested');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 650));
          expect(await router.routerDelegate.popRoute(), true);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 650));
          expect(bar().currentIndex, index);
          expect(router.canPop(), false);
          expect(find.text('Nested screen'), findsNothing);
          // A media-style imperative route also has precedence over tab fallback.
          final context = tester.element(find.byType(HomeShell));
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Media')),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 650));
          expect(await router.routerDelegate.popRoute(), true);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 650));
          expect(bar().currentIndex, index);
          expect(await router.routerDelegate.popRoute(), true);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(bar().currentIndex, 0);
          expect(router.canPop(), false);
          expect(await router.routerDelegate.popRoute(), false);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
  }
  for (final feed in ['flutter', 'm::alice::favorites']) {
    for (final resume in [true, false]) {
      testWidgets('restart destination $feed respects resume=$resume', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'resumeFeeds': resume,
          'notifyInboxPrompted': true,
          'checkUpdates': false,
        });
        final c = interactionContainer(
          prefs: await SharedPreferences.getInstance(),
          extraOverrides: [
            feedControllerProvider.overrideWith(EmptyFeed.new),
            unreadCountProvider.overrideWith(Unread.new),
          ],
        );
        addTearDown(c.dispose);
        await c.read(authControllerProvider.future);
        c
            .read(feedResumeStoreProvider.notifier)
            .save(
              feed,
              FeedBookmark(
                sort: PostSort.top,
                time: TopTime.week,
                offset: 0,
                ids: [],
                pages: 1,
                savedAt: DateTime.now(),
              ),
            );
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeShell()),
            GoRoute(
              path: '/r/:name',
              builder: (_, __) => const Scaffold(body: Text('Saved feed')),
            ),
            GoRoute(
              path: '/m/:username/:name',
              builder: (_, __) => const Scaffold(body: Text('Saved feed')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp.router(
              theme: AppTheme.dark(null),
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650));
        expect(find.text('Saved feed'), resume ? findsOneWidget : findsNothing);
        expect(router.canPop(), resume);
        if (resume) {
          expect(c.read(feedResumeStoreProvider).lastFeed, feed);
          expect(await router.routerDelegate.popRoute(), true);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 650));
          expect(
            tester
                .widget<M3EFloatingNavBar>(find.byType(M3EFloatingNavBar))
                .currentIndex,
            0,
          );
          expect(await router.routerDelegate.popRoute(), false);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 600));
      });
    }
  }
}
