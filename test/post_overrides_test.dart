import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/features/feed/post_overrides.dart';
import 'package:luli_for_reddit/models/post.dart';

Post _post({int score = 100, bool? likes}) => Post(
      id: 't3_score',
      fullname: 't3_score',
      title: 'Score integrity post',
      subreddit: 'flutter',
      subredditPrefixed: 'r/flutter',
      author: 'lily',
      score: score,
      numComments: 0,
      upvoteRatio: 0.95,
      created: DateTime.utc(2026, 1, 1),
      permalink: '/r/flutter/comments/score',
      url: 'https://www.reddit.com/r/flutter/comments/score',
      domain: 'reddit.com',
      type: PostType.self,
      isSelf: true,
      likes: likes,
    );

int _dir(bool? likes) => likes == true ? 1 : (likes == false ? -1 : 0);

/// Reads the effective interaction state through the same accessor the UI
/// uses, so the tests pin the exact contract PostCard / PostDetailScreen and
/// M3EPostActionBar rely on.
({int score, int dir}) _effective(ProviderContainer container, Post post) {
  final ov = container.read(postOverridesProvider.notifier).effective(post);
  return (score: ov.score, dir: _dir(ov.likes));
}

void main() {
  test('neutral post displays its base score', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final post = _post();

    expect(_effective(container, post), (score: 100, dir: 0));
  });

  test('upvote from neutral applies exactly +1', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final post = _post();

    container.read(postOverridesProvider.notifier).setVote(post, 1);

    expect(_effective(container, post), (score: 101, dir: 1));
  });

  test('downvote from neutral applies exactly -1', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final post = _post();

    container.read(postOverridesProvider.notifier).setVote(post, -1);

    expect(_effective(container, post), (score: 99, dir: -1));
  });

  test('switching upvote to downvote applies the net delta once (-2)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final post = _post();
    final notifier = container.read(postOverridesProvider.notifier);

    notifier.setVote(post, 1);
    notifier.setVote(post, -1);

    // 101 -> 99, never a double-adjusted 98.
    expect(_effective(container, post), (score: 99, dir: -1));
  });

  test('switching downvote to upvote applies the net delta once (+2)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final post = _post();
    final notifier = container.read(postOverridesProvider.notifier);

    notifier.setVote(post, -1);
    notifier.setVote(post, 1);

    // 99 -> 101.
    expect(_effective(container, post), (score: 101, dir: 1));
  });

  test('toggling a vote off restores the base score', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final post = _post();
    final notifier = container.read(postOverridesProvider.notifier);

    notifier.setVote(post, 1);
    notifier.setVote(post, 0);

    expect(_effective(container, post), (score: 100, dir: 0));
  });

  test('server-side pre-voted state is not double-counted', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Reddit's `score` already includes the user's own upvote here.
    final post = _post(score: 100, likes: true);

    expect(_effective(container, post), (score: 100, dir: 1));

    container.read(postOverridesProvider.notifier).setVote(post, -1);

    // Net single-delta result of switching directions from server state.
    expect(_effective(container, post), (score: 98, dir: -1));
  });

  test('saved and comment-count overrides remain independent of votes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final post = _post();
    final notifier = container.read(postOverridesProvider.notifier);

    notifier.setSaved(post, true);
    notifier.bumpComments(post, 3);
    notifier.setVote(post, 1);

    final ov = container.read(postOverridesProvider.notifier).effective(post);
    expect(ov.saved, isTrue);
    expect(ov.numComments, 3);
    expect(ov.score, 101);
  });

  test('controller vote reverts on API failure', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final post = _post();
    final notifier = container.read(postOverridesProvider.notifier);

    await notifier.vote(post, 1, (_) async {});
    expect(notifier.effective(post).score, 101);

    await notifier.vote(post, -1, (_) async => throw Exception('network'));
    final ov = notifier.effective(post);
    expect(ov.score, 101);
    expect(ov.likes, isTrue);
  });

  test('controller save reverts on API failure', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final post = _post();
    final notifier = container.read(postOverridesProvider.notifier);

    await notifier.toggleSave(post, (_) async => throw Exception('network'));
    expect(notifier.effective(post).saved, isFalse);

    await notifier.toggleSave(post, (_) async {});
    expect(notifier.effective(post).saved, isTrue);
  });
}
