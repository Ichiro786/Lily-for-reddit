import 'dart:math' as math;

import '../../models/post.dart';

/// Calculates and interleaves candidates for the local For You feed.
///
/// This ranking is intentionally local and deterministic for a given [now],
/// so standard Reddit sort tabs remain untouched and the personalized feed can
/// be tested without network or provider state.
class FeedRanker {
  const FeedRanker._();

  static const gravityExponent = 1.6;
  static const diversityWindow = 3;
  static const diversityPenalty = 0.3;
  static const maxAffinityMultiplier = 1.8;

  static double scoreFor(
    Post post, {
    required DateTime now,
    Map<String, double> affinityBySubreddit = const {},
    Set<String> viewedIds = const {},
  }) {
    if (viewedIds.contains(post.id)) return 0.0;
    final ageInHours = math.max(
      0,
      now.toUtc().difference(post.created.toUtc()).inMilliseconds /
          Duration.millisecondsPerHour,
    ).toDouble();
    final baseScore = post.score + post.numComments * 1.5;
    final decayedScore =
        baseScore / math.pow(ageInHours + 2.0, gravityExponent).toDouble();
    return decayedScore * _affinityMultiplier(
      affinityBySubreddit[post.subreddit.toLowerCase()] ?? 0,
    );
  }

  static Future<List<Post>> rank(
    Iterable<Post> posts, {
    required DateTime now,
    Map<String, double> affinityBySubreddit = const {},
    Set<String> viewedIds = const {},
    bool filterViewed = false,
  }) async {
    // Yield once so a large Reddit page does not monopolize the first frame.
    await Future<void>.delayed(Duration.zero);
    final candidates = <_ScoredPost>[
      for (final post in posts)
        if (!filterViewed || !viewedIds.contains(post.id))
          _ScoredPost(
            post,
            scoreFor(
              post,
              now: now,
              affinityBySubreddit: affinityBySubreddit,
              viewedIds: viewedIds,
            ),
          ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final result = <Post>[];
    final recentSubreddits = <String>[];
    while (candidates.isNotEmpty) {
      var bestIndex = 0;
      var bestAdjustedScore = double.negativeInfinity;
      var bestRawScore = double.negativeInfinity;
      for (var i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        final subreddit = candidate.post.subreddit.toLowerCase();
        final penalty = recentSubreddits.contains(subreddit)
            ? diversityPenalty
            : 1.0;
        final adjustedScore = (candidate.score * penalty).toDouble();
        if (adjustedScore > bestAdjustedScore ||
            (adjustedScore == bestAdjustedScore &&
                candidate.score > bestRawScore)) {
          bestIndex = i;
          bestAdjustedScore = adjustedScore;
          bestRawScore = candidate.score;
        }
      }
      final selected = candidates.removeAt(bestIndex).post;
      result.add(selected);
      final subreddit = selected.subreddit.toLowerCase();
      recentSubreddits.add(subreddit);
      if (recentSubreddits.length > diversityWindow) {
        recentSubreddits.removeAt(0);
      }
    }
    return result;
  }

  static double _affinityMultiplier(double weight) {
    if (weight >= 0) {
      return (1.0 +
              math.min(weight, 8.0) / 8.0 *
                  (maxAffinityMultiplier - 1.0))
          .toDouble();
    }
    return (1.0 - math.min(weight.abs(), 4.0) / 4.0 * 0.25).toDouble();
  }
}

class _ScoredPost {
  const _ScoredPost(this.post, this.score);

  final Post post;
  final double score;
}
