import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/deep_links.dart';
import 'core/route_observer.dart';
import 'core/startup_metrics.dart';
import 'features/auth/auth_controller.dart';
import 'features/settings/settings_controller.dart' show sharedPrefsProvider;
import 'features/auth/login_screen.dart';
import 'features/compose/compose_post_screen.dart';
import 'features/history/history_screen.dart';
import 'features/legal/policy_screen.dart';
import 'features/home/home_shell.dart';
import 'features/inbox/compose_message_screen.dart';
import 'features/inbox/message_thread_screen.dart';
import 'features/multireddit/manage_multireddit_screen.dart';
import 'features/multireddit/multireddit_feed_screen.dart';
import 'features/post/post_detail_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/manage_for_you_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/subreddit/subreddit_screen.dart';
import 'features/user/user_screen.dart';
import 'models/inbox_item.dart';
import 'models/post.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  final startup = StartupMetrics.instance;
  var authMarked = false;
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    observers: [appRouteObserver],
    redirect: (context, state) {
      // Map Reddit URLs delivered by the OS to an in-app route. This keeps
      // cold-start deep links inside go_router instead of triggering a route
      // exception or a second navigation from app_links.
      final host = state.uri.host.toLowerCase();
      if (host == 'redd.it' ||
          host == 'reddit.com' ||
          host.endsWith('.reddit.com')) {
        return routeForRedditUrl(state.uri) ?? '/';
      }

      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return null;
      if (!authMarked) {
        authMarked = true;
        startup.markAuthResolved();
      }
      final loggedIn = auth.valueOrNull != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) {
        // A transient secure-storage read should not bounce a known account to
        // login. Explicit logout clears this marker in AuthController.
        final hasAccount =
            ref.read(sharedPrefsProvider).getBool(kHasAccountPref) ?? false;
        if (hasAccount) return atLogin ? '/' : null;
        return atLogin ? null : '/login';
      }
      if (atLogin) return '/';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Page not found', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Home'),
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeShell()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: '/manage_for_you',
          builder: (_, __) => const ManageForYouScreen()),
      GoRoute(path: '/policy', builder: (_, __) => const PolicyScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(
        path: '/search',
        builder: (_, state) => SearchScreen(
          initialSubreddit: state.uri.queryParameters['sr'],
          initialQuery: state.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        path: '/submit',
        builder: (_, state) => ComposePostScreen(
            initialSubreddit: state.uri.queryParameters['sr']),
      ),
      GoRoute(
        path: '/message',
        builder: (_, state) =>
            MessageThreadScreen(root: state.extra as InboxItem),
      ),
      GoRoute(
        path: '/compose_message',
        builder: (_, state) =>
            ComposeMessageScreen(initialTo: state.uri.queryParameters['to']),
      ),
      GoRoute(
        path: '/r/:name',
        builder: (_, state) =>
            SubredditScreen(name: state.pathParameters['name']!),
      ),
      GoRoute(
        path: '/u/:username',
        builder: (_, state) =>
            UserScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/m/:username/:name',
        builder: (_, state) => MultiredditFeedScreen(
          username: state.pathParameters['username']!,
          name: state.pathParameters['name']!,
        ),
      ),
      GoRoute(
        path: '/m/:username/:name/manage',
        builder: (_, state) =>
            ManageMultiredditScreen(name: state.pathParameters['name']!),
      ),
      GoRoute(
        path: '/comments/:subreddit/:id',
        builder: (_, state) => PostDetailScreen(
          subreddit: state.pathParameters['subreddit']!,
          postId: state.pathParameters['id']!,
          initialPost: state.extra as Post?,
          focusCommentId: state.uri.queryParameters['comment'],
        ),
      ),
    ],
  );
});
