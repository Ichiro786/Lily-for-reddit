import 'dart:math' as math;

import '../../core/storage/interaction_vault.dart';
import '../../models/post.dart';

/// Calculates and interleaves candidates for the local For You feed.
///
/// This ranking is intentionally local and deterministic for a given [now],
/// so standard Reddit sort tabs remain untouched and the personalized feed can
/// be tested without network or provider state.
class FeedRanker {
  const FeedRanker._();

  static const gravityExponent = 1.6;
  static const diversityWindow = 6;
  static const diversityPenalty = 0.3;
  static const maxConsecutiveSubredditPosts = 2;
  static const maxAffinityMultiplier = 1.8;
  static const saveMultiplier = 3.5;
  static const commentMultiplier = 2.5;
  static const upvoteMultiplier = 1.2;
  static const negativeInteractionPenalty = -10.0;

  static double scoreFor(
    Post post, {
    required DateTime now,
    Map<String, double> affinityBySubreddit = const {},
    Set<String> viewedIds = const {},
    InteractionRecord? interaction,
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

    if (interaction?.downvoted == true || interaction?.dismissed == true) {
      return decayedScore * negativeInteractionPenalty;
    }

    var engagementMultiplier = 1.0;
    if (interaction?.saved == true) engagementMultiplier *= saveMultiplier;
    if (interaction?.commentOpened == true) {
      engagementMultiplier *= commentMultiplier;
    }
    if (interaction?.upvoted == true) engagementMultiplier *= upvoteMultiplier;

    return decayedScore *
        engagementMultiplier *
        _affinityMultiplier(
          affinityBySubreddit[post.subreddit.toLowerCase()] ?? 0,
        );
  }

  static Future<List<Post>> rank(
    Iterable<Post> posts, {
    required DateTime now,
    Map<String, double> affinityBySubreddit = const {},
    Set<String> viewedIds = const {},
    Map<String, InteractionRecord> interactionsByPostId = const {},
    bool filterViewed = false,
    bool filterInteracted = false,
  }) async {
    // Yield once so a large Reddit page does not monopolize the first frame.
    await Future<void>.delayed(Duration.zero);
    final candidates = <_ScoredPost>[
      for (final post in posts)
        if ((!filterViewed || !viewedIds.contains(post.id)) &&
            (!_shouldFilterInteraction(post.id, interactionsByPostId,
                filterInteracted)))
          _ScoredPost(
            post,
            scoreFor(
              post,
              now: now,
              affinityBySubreddit: affinityBySubreddit,
              viewedIds: viewedIds,
              interaction: interactionsByPostId[post.id],
            ),
          ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final result = <Post>[];
    final recentSubreddits = <String>[];
    while (candidates.isNotEmpty) {
      var bestIndex = -1;
      var bestAdjustedScore = double.negativeInfinity;
      var bestRawScore = double.negativeInfinity;

      for (var i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        final subreddit = candidate.post.subreddit.toLowerCase();
        final consecutiveCount = _trailingCount(recentSubreddits, subreddit);
        final hasAlternative = candidates.any(
          (other) => other.post.subreddit.toLowerCase() != subreddit,
        );
        if (consecutiveCount >= maxConsecutiveSubredditPosts && hasAlternative) {
          continue;
        }

        final windowStart = (recentSubreddits.length - diversityWindow)
            .clamp(0, recentSubreddits.length)
            .toInt();
        final windowCount = recentSubreddits
            .skip(windowStart)
            .where((item) => item == subreddit)
            .length;
        final penalty = windowCount >= maxConsecutiveSubredditPosts
            ? diversityPenalty
            : 1.0;
        final adjustedScore = (candidate.score * penalty).toDouble();
        if (bestIndex == -1 ||
            adjustedScore > bestAdjustedScore ||
            (adjustedScore == bestAdjustedScore &&
                candidate.score > bestRawScore)) {
          bestIndex = i;
          bestAdjustedScore = adjustedScore;
          bestRawScore = candidate.score;
        }
      }

      // If every remaining candidate belongs to the capped subreddit, allow
      // it rather than dropping valid Reddit results from the page.
      if (bestIndex == -1) bestIndex = 0;
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

  static bool _shouldFilterInteraction(
    String postId,
    Map<String, InteractionRecord> interactions,
    bool filterInteracted,
  ) {
    if (!filterInteracted) return false;
    final interaction = interactions[postId];
    return interaction?.upvoted == true ||
        interaction?.saved == true ||
        interaction?.downvoted == true ||
        interaction?.dismissed == true;
  }

  static int _trailingCount(List<String> subreddits, String subreddit) {
    var count = 0;
    for (var i = subreddits.length - 1; i >= 0; i--) {
      if (subreddits[i] != subreddit) break;
      count++;
    }
    return count;
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
