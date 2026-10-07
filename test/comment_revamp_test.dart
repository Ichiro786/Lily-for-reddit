import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/post/post_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/interaction_fixture.dart';

void main() {
  testWidgets(
    'avatar and username open the same profile; collapse remains separate',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = interactionContainer(prefs: prefs);
        addTearDown(container.dispose);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) =>
                  const PostDetailScreen(subreddit: 'flutter', postId: 'p1'),
            ),
            GoRoute(
              path: '/u/:name',
              builder: (_, state) => Scaffold(
                body: Text('Profile: ${state.pathParameters['name']}'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.dark(null, amoled: true),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byType(M3ECommentCard);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
          Colors.black,
        );
        await tester.ensureVisible(card);
        await tester.tap(find.bySemanticsLabel('View profile of alice'));
        await tester.pumpAndSettle();
        expect(find.text('Profile: alice'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await tester.ensureVisible(card);
        await tester.tap(find.text('u/alice'));
        await tester.pumpAndSettle();
        expect(find.text('Profile: alice'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await tester.ensureVisible(card);
        await tester.tap(find.byTooltip('Collapse comment'));
        await tester.pumpAndSettle();
        expect(tester.widget<M3ECommentCard>(card).isCollapsed, isTrue);
        expect(find.text('Profile: alice'), findsNothing);
        await tester.tap(find.byTooltip('Expand comment'));
        await tester.pumpAndSettle();
        expect(tester.widget<M3ECommentCard>(card).isCollapsed, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
