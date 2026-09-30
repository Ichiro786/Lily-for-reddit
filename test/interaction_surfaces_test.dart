import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/feed/post_action_bar.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/feed/post_overrides.dart';
import 'package:luli_for_reddit/features/feed/swipe_actions.dart';
import 'package:luli_for_reddit/features/history/interest_store.dart';
import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/post/comment_overrides.dart';
import 'package:luli_for_reddit/features/post/post_detail_screen.dart';
import 'package:luli_for_reddit/models/post.dart';

import 'support/interaction_fixture.dart';

Widget _surface(ProviderContainer container, Post post, bool detail) =>
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
                body: ListView(children: [PostCard(post: post)]),
              ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  for (final action in ['upvote', 'downvote', 'save']) {
    for (final fails in [false, true]) {
      testWidgets(
        '$action feed/detail have equivalent optimistic and settled state; failure=$fails',
        (tester) async {
          final snapshots = <Object>[];
          for (final detail in [false, true]) {
            // Fresh stores per surface; exercise the actual wired widget callbacks.
            SharedPreferences.setMockInitialValues({});
            final prefs = await SharedPreferences.getInstance();
            final repository = InteractionRepository(controlled: true);
            final events = <(String, String)>[];
            final container = interactionContainer(
              repository: repository,
              prefs: prefs,
              report: (action, outcome) => events.add((action, outcome)),
            );
            final post = interactionPost();
            await tester.pumpWidget(_surface(container, post, detail));
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump();
            final barFinder = find.byType(M3EPostActionBar);
            expect(barFinder, findsOneWidget);
            await tester.tap(find.descendant(
              of: barFinder,
              matching: find.byIcon(action == 'save'
                  ? Icons.bookmark_outline_rounded
                  : (action == 'upvote'
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)),
            ));
            await tester.pump();
            final optimistic = tester.widget<M3EPostActionBar>(barFinder);
            final dir =
                action == 'upvote' ? 1 : (action == 'downvote' ? -1 : 0);
            expect(optimistic.voteState, dir);
            expect(optimistic.score, 100 + dir);
            expect(optimistic.isSaved, action == 'save');
            expect(
              container.read(interactionVaultProvider).interactedPosts,
              isEmpty,
            );
            final request = action == 'save'
                ? repository.saves.single
                : repository.votes.single;
            expect(request.fullname, 't3_p1');
            expect(request.value, action == 'save' ? true : dir);
            if (fails) {
              request.done.completeError(StateError('network'));
            } else {
              request.done.complete();
            }
            await tester.pump();
            await tester.pump();
            final settled = tester.widget<M3EPostActionBar>(barFinder);
            expect(settled.voteState, fails ? 0 : dir);
            expect(settled.score, fails ? 100 : 100 + dir);
            expect(settled.isSaved, !fails && action == 'save');
            final record = container
                .read(interactionVaultProvider)
                .interactedPosts[post.id];
            snapshots.add([
              settled.voteState,
              settled.score,
              settled.isSaved,
              record?.upvoted,
              record?.downvoted,
              record?.saved,
              Map.of(container.read(interestStoreProvider)),
              Map.of(container.read(keywordStoreProvider)),
              List.of(events),
            ]);
            if (fails) {
              expect(record, isNull);
              expect(container.read(interestStoreProvider), isEmpty);
              expect(container.read(keywordStoreProvider), isEmpty);
            } else {
              expect(record!.upvoted, action == 'upvote');
              expect(record.downvoted, action == 'downvote');
              expect(record.saved, action == 'save');
              expect(
                container.read(interestStoreProvider)['flutter'],
                action == 'save' ? 3 : (dir == 1 ? 2 : -1.5),
              );
              expect(
                container.read(keywordStoreProvider)['architecture'],
                action == 'save' ? 1.5 : (dir == 1 ? 1 : -0.8),
              );
              await container
                  .read(interactionVaultProvider.notifier)
                  .flushPersisted();
              final restored = interactionContainer(prefs: prefs);
              expect(
                restored
                    .read(interactionVaultProvider)
                    .interactedPosts[post.id]!
                    .toJson(),
                record.toJson(),
              );
              restored.dispose();
            }
            expect(events, [
              (
                action == 'save' ? 'post_save' : 'post_vote',
                fails ? 'failed' : 'succeeded',
              ),
            ]);
            await tester.pumpWidget(const SizedBox());
            container.dispose();
            await tester.pump();
          }
          // Records contain maps/lists; compare their fields with deep matchers.
          expect(snapshots[1], snapshots[0]);
        },
      );
    }
  }

  testWidgets(
    'cleared server vote stays neutral across feed/detail navigation',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final post = interactionPost(likes: true);
      final container = interactionContainer(
        prefs: prefs,
        repository: InteractionRepository(post: post),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_surface(container, post, false));
      await tester.pump();
      tester.widget<M3EPostActionBar>(find.byType(M3EPostActionBar)).onVote!(1);
      await tester.pump();
      expect(
        tester
            .widget<M3EPostActionBar>(find.byType(M3EPostActionBar))
            .voteState,
        0,
      );
      await tester.pumpWidget(_surface(container, post, true));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
        tester
            .widget<M3EPostActionBar>(find.byType(M3EPostActionBar))
            .voteState,
        0,
      );
      expect(
        container.read(postOverridesProvider.notifier).effective(post).score,
        99,
      );
      await tester.pumpWidget(_surface(container, post, false));
      await tester.pump();
      expect(
        tester
            .widget<M3EPostActionBar>(find.byType(M3EPostActionBar))
            .voteState,
        0,
      );
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets('real comment tile uses shared optimistic action and rollback', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final repository = InteractionRepository(controlled: true);
    final events = <(String, String)>[];
    final container = interactionContainer(
      repository: repository,
      prefs: prefs,
      report: (action, outcome) => events.add((action, outcome)),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_surface(container, interactionPost(), true));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final finder = find.byType(M3ECommentCard);
    expect(finder, findsOneWidget);
    tester.widget<M3ECommentCard>(finder).onVote!(1);
    await tester.pump();
    expect(tester.widget<M3ECommentCard>(finder).voteState, 1);
    repository.votes.single.done.completeError(StateError('network'));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<M3ECommentCard>(finder).voteState, 0);
    expect(tester.widget<M3ECommentCard>(finder).score, 10);
    tester.widget<M3ECommentCard>(finder).onSave!();
    await tester.pump();
    expect(tester.widget<M3ECommentCard>(finder).isSaved, isTrue);
    repository.saves.single.done.completeError(StateError('network'));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<M3ECommentCard>(finder).isSaved, isFalse);
    expect(
      container
          .read(commentOverridesProvider.notifier)
          .effective(interactionComment())
          .saved,
      isFalse,
    );
    expect(container.read(interactionVaultProvider).interactedPosts, isEmpty);
    expect(events, [('comment_vote', 'failed'), ('comment_save', 'failed')]);
  });
  testWidgets('pending feed vote and detail vote share ordering and rollback',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final repository = InteractionRepository(controlled: true);
    final container =
        interactionContainer(repository: repository, prefs: prefs);
    addTearDown(container.dispose);
    final post = interactionPost();
    await tester.pumpWidget(_surface(container, post, false));
    await tester.pump();
    tester.widget<SwipeActions>(find.byType(SwipeActions)).onRight();
    await tester.pump();
    await tester.pumpWidget(_surface(container, post, true));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
        tester
            .widget<M3EPostActionBar>(find.byType(M3EPostActionBar))
            .voteState,
        1);
    tester.widget<M3EPostActionBar>(find.byType(M3EPostActionBar)).onVote!(-1);
    await tester.pump();
    repository.votes[0].done.completeError(StateError('feed vote failed'));
    await tester.pump();
    await tester.pump();
    expect(
        tester
            .widget<M3EPostActionBar>(find.byType(M3EPostActionBar))
            .voteState,
        -1);
    expect(repository.votes[1].value, -1);
    repository.votes[1].done.complete();
    await tester.pump();
    await tester.pump();
    expect(
        container
            .read(interactionVaultProvider)
            .interactedPosts[post.id]!
            .downvoted,
        isTrue);
    await tester.pumpWidget(_surface(container, post, false));
    await tester.pump();
    expect(
        tester
            .widget<M3EPostActionBar>(find.byType(M3EPostActionBar))
            .voteState,
        -1);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });

  testWidgets('overflow save reads shared state and uses the same action layer',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final repository = InteractionRepository();
    final container =
        interactionContainer(repository: repository, prefs: prefs);
    addTearDown(container.dispose);
    final post = interactionPost();
    await tester.pumpWidget(_surface(container, post, false));
    await tester.pump();
    final bar = tester.widget<M3EPostActionBar>(find.byType(M3EPostActionBar));
    bar.onSaveTap!();
    await tester.pump();
    await tester.pump();
    tester.widget<M3EPostActionBar>(find.byType(M3EPostActionBar)).onMoreTap!();
    await tester.pumpAndSettle();
    expect(find.text('Unsave post'), findsOneWidget);
    await tester.tap(find.text('Unsave post'));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(repository.saves.map((request) => request.value), [true, false]);
    expect(container.read(postOverridesProvider.notifier).effective(post).saved,
        isFalse);
    expect(
        container
            .read(interactionVaultProvider)
            .interactedPosts[post.id]!
            .saved,
        isFalse);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
}
