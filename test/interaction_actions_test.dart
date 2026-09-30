import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/interaction_actions.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/features/feed/post_overrides.dart';
import 'package:luli_for_reddit/features/history/interest_store.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';

import 'support/interaction_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late InteractionRepository repository;
  late ProviderContainer container;
  late List<(String, String)> events;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = InteractionRepository(controlled: true);
    events = [];
    container = interactionContainer(
      repository: repository,
      prefs: prefs,
      report: (action, outcome) => events.add((action, outcome)),
    );
  });
  tearDown(() => container.dispose());

  for (final direction in [1, -1]) {
    test(
      'vote $direction is optimistic; rejection leaves no durable signals',
      () async {
        final post = interactionPost(likes: true);
        final overrides = container.read(postOverridesProvider.notifier);
        final actions = container.read(interactionActionsProvider);
        final vault = container.read(interactionVaultProvider.notifier);
        vault.recordDismissal(post.id);
        final before =
            container.read(interactionVaultProvider).interactedPosts[post.id];
        final pending = actions.votePost(post, direction);
        final target = direction == 1 ? 0 : -1;
        expect(overrides.effective(post).voteDirection, target);
        expect(overrides.effective(post).score, 100 + target - 1);
        expect(repository.votes.single.value, target);
        repository.votes.single.done.completeError(StateError('network'));
        await pending;
        expect(overrides.effective(post).voteDirection, 1);
        expect(overrides.effective(post).score, 100);
        expect(
          container.read(interactionVaultProvider).interactedPosts[post.id],
          same(before),
        );
        expect(container.read(interestStoreProvider), isEmpty);
        expect(container.read(keywordStoreProvider), isEmpty);
        expect(events, [('post_vote', 'failed')]);
      },
    );
  }

  test(
    'successful post signals persist and keep explicit dismissal independent',
    () async {
      final post = interactionPost();
      final actions = container.read(interactionActionsProvider);
      final vault = container.read(interactionVaultProvider.notifier);
      vault.recordDismissal(post.id);
      final down = actions.votePost(post, -1);
      repository.votes.last.done.complete();
      await down;
      var record =
          container.read(interactionVaultProvider).interactedPosts[post.id]!;
      expect(record.downvoted, isTrue);
      expect(record.upvoted, isFalse);
      final clear = actions.votePost(post, -1);
      expect(repository.votes.last.value, 0);
      repository.votes.last.done.complete();
      await clear;
      record =
          container.read(interactionVaultProvider).interactedPosts[post.id]!;
      expect(record.downvoted, isFalse);
      expect(record.dismissed, isTrue);
      final save = actions.toggleSavePost(post);
      repository.saves.last.done.complete();
      await save;
      await vault.flushPersisted();
      final restored = interactionContainer(prefs: prefs);
      addTearDown(restored.dispose);
      expect(
        restored.read(interactionVaultProvider).interactedPosts[post.id]!.saved,
        isTrue,
      );
      expect(
        restored
            .read(interactionVaultProvider)
            .interactedPosts[post.id]!
            .dismissed,
        isTrue,
      );
      expect(container.read(interestStoreProvider)['flutter'], 1.5);
      expect(
        container.read(keywordStoreProvider)['architecture'],
        closeTo(0.7, 0.00001),
      );
      expect(events, [
        ('post_vote', 'succeeded'),
        ('post_vote', 'succeeded'),
        ('post_save', 'succeeded'),
      ]);
    },
  );

  for (final saved in [false, true]) {
    test(
      'failed ${saved ? 'unsave' : 'save'} restores server baseline',
      () async {
        final post = interactionPost(saved: saved);
        final pending =
            container.read(interactionActionsProvider).toggleSavePost(post);
        final overrides = container.read(postOverridesProvider.notifier);
        expect(overrides.effective(post).saved, !saved);
        repository.saves.single.done.completeError(StateError('network'));
        await pending;
        expect(overrides.effective(post).saved, saved);
        await container
            .read(interactionVaultProvider.notifier)
            .flushPersisted();
        final restored = interactionContainer(prefs: prefs);
        addTearDown(restored.dispose);
        expect(
          restored.read(interactionVaultProvider).interactedPosts,
          isEmpty,
        );
        expect(container.read(interestStoreProvider), isEmpty);
        expect(container.read(keywordStoreProvider), isEmpty);
        expect(events, [('post_save', 'failed')]);
      },
    );
  }

  for (final firstFails in [false, true]) {
    for (final secondFails in [false, true]) {
      test(
        'overlapping votes: first failure=$firstFails, second failure=$secondFails',
        () async {
          final post = interactionPost();
          final actions = container.read(interactionActionsProvider);
          final overrides = container.read(postOverridesProvider.notifier);
          final first = actions.votePost(post, 1);
          final second = actions.votePost(post, -1);
          expect(overrides.effective(post).voteDirection, -1);
          expect(repository.votes, hasLength(1));
          if (firstFails) {
            repository.votes[0].done.completeError(StateError('network'));
          } else {
            repository.votes[0].done.complete();
          }
          await first;
          expect(overrides.effective(post).voteDirection, -1);
          expect(repository.votes, hasLength(2));
          if (secondFails) {
            repository.votes[1].done.completeError(StateError('network'));
          } else {
            repository.votes[1].done.complete();
          }
          await second;
          final expected = secondFails ? (firstFails ? 0 : 1) : -1;
          expect(overrides.effective(post).voteDirection, expected);
          expect(overrides.effective(post).score, 100 + expected);
          expect(events, [
            ('post_vote', firstFails ? 'failed' : 'succeeded'),
            ('post_vote', secondFails ? 'failed' : 'succeeded'),
          ]);
        },
      );
    }
  }

  test(
    'overlapping saves recover confirmed state and do not undo a vote',
    () async {
      final post = interactionPost();
      final actions = container.read(interactionActionsProvider);
      final first = actions.toggleSavePost(post);
      final second = actions.toggleSavePost(post);
      final vote = actions.votePost(post, 1);
      final overrides = container.read(postOverridesProvider.notifier);
      overrides.bumpComments(post, 2);
      repository.votes.single.done.complete();
      await vote;
      repository.saves[0].done.completeError(StateError('first save'));
      await first;
      expect(repository.saves[1].value, isFalse);
      repository.saves[1].done.completeError(StateError('second save'));
      await second;
      expect(overrides.effective(post).saved, isFalse);
      expect(overrides.effective(post).voteDirection, 1);
      expect(overrides.effective(post).score, 101);
      expect(overrides.effective(post).numComments, 3);
    },
  );

  test('disabled learning retains the existing ranking-store policy', () async {
    container.read(settingsControllerProvider.notifier).setTrackHistory(false);
    final pending = container
        .read(interactionActionsProvider)
        .votePost(interactionPost(), 1);
    repository.votes.single.done.complete();
    await pending;
    expect(container.read(interestStoreProvider), isEmpty);
    expect(container.read(keywordStoreProvider), isEmpty);
  });

  test('telemetry failure cannot roll back an accepted action', () async {
    final isolated = interactionContainer(
      repository: repository,
      prefs: prefs,
      report: (_, __) => throw StateError('telemetry'),
    );
    addTearDown(isolated.dispose);
    final pending = isolated
        .read(interactionActionsProvider)
        .voteComment(interactionComment(), 1);
    repository.votes.single.done.complete();
    await pending;
    expect(isolated.read(interactionVaultProvider).interactedPosts, isEmpty);
  });
  test('asynchronous telemetry errors are isolated', () async {
    final isolated = interactionContainer(
        repository: repository,
        prefs: prefs,
        report: (_, __) async => throw StateError('async telemetry'));
    addTearDown(isolated.dispose);
    final pending = isolated
        .read(interactionActionsProvider)
        .votePost(interactionPost(), 1);
    repository.votes.single.done.complete();
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(
        isolated
            .read(postOverridesProvider.notifier)
            .effective(interactionPost())
            .voteDirection,
        1);
  });

  test('local signal failure does not revert a server-accepted mutation',
      () async {
    final isolated = interactionContainer(
        repository: repository,
        report: (action, outcome) => events.add((action, outcome)));
    addTearDown(isolated.dispose);
    // No preferences: signal persistence cannot initialize, but Reddit succeeds.
    final pending = isolated
        .read(interactionActionsProvider)
        .votePost(interactionPost(), 1);
    repository.votes.single.done.complete();
    await pending;
    expect(
        isolated
            .read(postOverridesProvider.notifier)
            .effective(interactionPost())
            .voteDirection,
        1);
    expect(
        events, [('post_vote', 'signal_failed'), ('post_vote', 'succeeded')]);
  });

  test('in-flight action completes safely after provider scope disposal',
      () async {
    final isolated = interactionContainer(repository: repository, prefs: prefs);
    final pending = isolated
        .read(interactionActionsProvider)
        .votePost(interactionPost(), 1);
    isolated.dispose();
    repository.votes.single.done.complete();
    await pending;
  });
}
