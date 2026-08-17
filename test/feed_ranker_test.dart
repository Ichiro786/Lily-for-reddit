import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/features/feed/feed_ranker.dart';
import 'package:luli_for_reddit/models/post.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 2);

  Post post({
    required String id,
    required String subreddit,
    required int score,
    required int comments,
    DateTime? created,
  }) {
    return Post(
      id: id,
      fullname: 't3_$id',
      title: id,
      subreddit: subreddit,
      subredditPrefixed: 'r/$subreddit',
      author: 'author',
      score: score,
      numComments: comments,
      upvoteRatio: 1,
      created: created ?? DateTime.utc(2026, 1, 1),
      permalink: '/r/$subreddit/comments/$id',
      url: 'https://reddit.com/r/$subreddit/comments/$id',
      domain: 'self.$subreddit',
      type: PostType.self,
    );
  }

  test('applies engagement base score and power time decay', () {
    final candidate = post(id: 'decay', subreddit: 'news', score: 27, comments: 2);

    final score = FeedRanker.scoreFor(candidate, now: now);
    final expected = 30 / math.pow(2.0 + 2.0, 1.6);

    expect(score, closeTo(expected, 0.000001));
  });

  test('weights saves and comments above shallow upvotes', () {
    final candidate = post(
      id: 'engagement',
      subreddit: 'Flutter',
      score: 20,
      comments: 0,
      created: now,
    );
    final neutral = FeedRanker.scoreFor(candidate, now: now);
    final upvoted = FeedRanker.scoreFor(
      candidate,
      now: now,
      interaction: const InteractionRecord(upvoted: true),
    );
    final saved = FeedRanker.scoreFor(
      candidate,
      now: now,
      interaction: const InteractionRecord(saved: true),
    );
    final commented = FeedRanker.scoreFor(
      candidate,
      now: now,
      interaction: const InteractionRecord(commentOpened: true),
    );

    expect(upvoted, closeTo(neutral * FeedRanker.upvoteMultiplier, 0.000001));
    expect(saved, closeTo(neutral * FeedRanker.saveMultiplier, 0.000001));
    expect(
      commented,
      closeTo(neutral * FeedRanker.commentMultiplier, 0.000001),
    );
    expect(saved, greaterThan(commented));
    expect(commented, greaterThan(upvoted));
  });

  test('suppresses viewed posts and durable interactions on a fresh feed', () async {
    final posts = [
      post(id: 'seen', subreddit: 'alpha', score: 100, comments: 0),
      post(id: 'saved', subreddit: 'beta', score: 99, comments: 0),
      post(id: 'new', subreddit: 'gamma', score: 1, comments: 0),
    ];

    final ranked = await FeedRanker.rank(
      posts,
      now: now,
      viewedIds: {'seen'},
      interactionsByPostId: {
        'saved': const InteractionRecord(saved: true),
      },
      filterInteracted: true,
    );

    expect(ranked.map((item) => item.id), ['new', 'seen']);
  });

  test('interleaves subreddits without more than two consecutive posts', () async {
    final ranked = await FeedRanker.rank(
      [
        post(id: 'a1', subreddit: 'alpha', score: 100, comments: 0),
        post(id: 'a2', subreddit: 'alpha', score: 99, comments: 0),
        post(id: 'a3', subreddit: 'alpha', score: 98, comments: 0),
        post(id: 'a4', subreddit: 'alpha', score: 97, comments: 0),
        post(id: 'b1', subreddit: 'beta', score: 60, comments: 0),
        post(id: 'b2', subreddit: 'beta', score: 59, comments: 0),
        post(id: 'c1', subreddit: 'gamma', score: 55, comments: 0),
      ],
      now: now,
    );

    var run = 0;
    String? previous;
    for (final item in ranked) {
      if (item.subreddit == previous) {
        run++;
      } else {
        previous = item.subreddit;
        run = 1;
      }
      expect(run, lessThanOrEqualTo(2));
    }
    expect(ranked.take(3).map((item) => item.subreddit),
        ['alpha', 'alpha', 'beta']);
  });

  test('affinity boosts and negative interactions suppress posts', () {
    final candidate = post(
      id: 'affinity',
      subreddit: 'Flutter',
      score: 20,
      comments: 0,
      created: now,
    );

    final neutral = FeedRanker.scoreFor(candidate, now: now);
    final boosted = FeedRanker.scoreFor(
      candidate,
      now: now,
      affinityBySubreddit: {'flutter': 8},
    );
    final dismissed = FeedRanker.scoreFor(
      candidate,
      now: now,
      interaction: const InteractionRecord(dismissed: true),
    );

    expect(boosted, closeTo(neutral * 1.8, 0.000001));
    expect(dismissed, lessThan(0));
  });
}
