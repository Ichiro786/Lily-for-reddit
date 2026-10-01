import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/feed/post_action_bar.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/post/post_detail_screen.dart';
import 'support/interaction_fixture.dart';

void main() {
  for (final detail in [false, true]) {
    for (final likes in <bool?>[null, true, false]) {
      testWidgets(
        'B02 actual vote taps toggle and switch; detail=$detail likes=$likes',
        (tester) async {
          SharedPreferences.setMockInitialValues({'trackHistory': false});
          VisibilityDetectorController.instance.updateInterval = Duration.zero;
          addTearDown(
            () => VisibilityDetectorController.instance.updateInterval =
                const Duration(milliseconds: 500),
          );
          final prefs = await SharedPreferences.getInstance();
          final post = interactionPost(likes: likes);
          final repository = InteractionRepository(post: post);
          final container = interactionContainer(
            prefs: prefs,
            repository: repository,
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.dark(null),
                home: detail
                    ? PostDetailScreen(
                        subreddit: post.subreddit,
                        postId: post.id,
                        initialPost: post,
                      )
                    : Scaffold(
                        body: PostCard(post: post, frontpageStyle: true),
                      ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
          final initial = likes == null ? 0 : (likes ? 1 : -1);
          var target = initial;
          for (final direction in [1, 1, -1, -1, 1, -1, -1]) {
            target = target == direction ? 0 : direction;
            final icon = find.descendant(
              of: find.byType(M3EPostActionBar),
              matching: find.byIcon(
                direction == 1
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
              ),
            );
            await tester.ensureVisible(icon);
            await tester.tap(icon);
            await tester.pump();
            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(repository.votes.last.value, target);
            final bar = tester.widget<M3EPostActionBar>(
              find.byType(M3EPostActionBar),
            );
            expect(bar.voteState, target);
            expect(bar.score, 100 + target - initial);
          }
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        },
      );
    }
  }
}
