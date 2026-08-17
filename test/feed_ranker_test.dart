import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

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

  test('boosts affinity and suppresses viewed posts', () {
    final candidate = post(id: 'affinity', subreddit: 'Flutter', score: 20, comments: 0);

    final neutral = FeedRanker.scoreFor(candidate, now: now);
    final boosted = FeedRanker.scoreFor(
      candidate,
      now: now,
      affinityBySubreddit: {'flutter': 8},
    );
    final viewed = FeedRanker.scoreFor(
      candidate,
      now: now,
      viewedIds: {'affinity'},
    );

    expect(boosted, closeTo(neutral * 1.8, 0.000001));
    expect(viewed, 0);
  });

  test('interleaves subreddits when a recent subreddit receives a penalty', () async {
    final ranked = await FeedRanker.rank(
      [
        post(id: 'a1', subreddit: 'alpha', score: 100, comments: 0),
        post(id: 'a2', subreddit: 'alpha', score: 99, comments: 0),
        post(id: 'b1', subreddit: 'beta', score: 60, comments: 0),
        post(id: 'c1', subreddit: 'gamma', score: 55, comments: 0),
      ],
      now: now,
    );

    expect(
      ranked.take(3).map((item) => item.subreddit),
      ['alpha', 'beta', 'gamma'],
    );
  });

  test('filters viewed posts only when requested', () async {
    final posts = [
      post(id: 'seen', subreddit: 'alpha', score: 100, comments: 0),
      post(id: 'new', subreddit: 'beta', score: 1, comments: 0),
    ];

    final ranked = await FeedRanker.rank(
      posts,
      now: now,
      viewedIds: {'seen'},
      filterViewed: true,
    );

    expect(ranked.map((item) => item.id), ['new']);
  });
}
