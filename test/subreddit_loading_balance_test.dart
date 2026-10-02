import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/core/widgets/m3e_loading_indicator.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/feed/post_skeleton.dart';
import 'package:luli_for_reddit/features/subreddit/subreddit_screen.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'package:luli_for_reddit/models/post.dart';
import 'package:luli_for_reddit/models/subreddit.dart';
import 'support/interaction_fixture.dart';

class LoadingRepository extends InteractionRepository {
  final about = Completer<Subreddit>();
  final posts = Completer<Listing<Post>>();
  @override
  Future<Subreddit> getSubredditAbout(String name) => about.future;
  @override
  Future<Listing<Post>> getPosts({
    String? subreddit,
    PostSort sort = PostSort.best,
    TopTime time = TopTime.day,
    String? after,
    int limit = 25,
  }) => posts.future;
}

void main() {
  for (final order in ['about first', 'posts first', 'about fails']) {
    testWidgets('one loader and static skeletons: $order', (tester) async {
      SharedPreferences.setMockInitialValues({'trackHistory': false});
      final repo = LoadingRepository();
      final c = interactionContainer(
        repository: repo,
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.dark(null),
            home: const SubredditScreen(name: 'flutter'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(M3ELoadingIndicator), findsOneWidget);
      expect(find.byType(PostSkeleton), findsWidgets);
      expect(
        tester.widget<PostSkeleton>(find.byType(PostSkeleton).first).animate,
        false,
      );
      if (order == 'posts first') {
        repo.posts.complete(const Listing(items: []));
      } else if (order == 'about fails') {
        repo.about.completeError(StateError('offline'));
      } else {
        repo.about.complete(
          const Subreddit(
            name: 'flutter',
            namePrefixed: 'r/flutter',
            title: 'Flutter',
            description: '',
            subscribers: 100,
          ),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(M3ELoadingIndicator), findsOneWidget);
      if (!repo.about.isCompleted) {
        repo.about.completeError(StateError('offline'));
      }
      if (!repo.posts.isCompleted) {
        repo.posts.complete(const Listing(items: []));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(M3ELoadingIndicator), findsNothing);
      expect(find.byType(PostSkeleton), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
