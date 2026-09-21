import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/core/widgets/error_view.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/search/search_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'package:luli_for_reddit/models/post.dart';
import 'package:luli_for_reddit/models/reddit_user.dart';
import 'package:luli_for_reddit/models/subreddit.dart';

class _FlakySearchRepository extends RedditRepository {
  _FlakySearchRepository()
      : super(RedditClient(SecureStore(), AuthRepository(SecureStore())));

  bool fail = true;

  @override
  Future<Listing<Post>> searchPosts(String query,
      {String? subreddit,
      String? after,
      String sort = 'relevance',
      String time = 'all'}) async {
    if (fail) throw Exception('failed host lookup: reddit.com');
    return const Listing<Post>(items: []);
  }

  @override
  Future<List<Subreddit>> searchSubreddits(String query) async {
    if (fail) throw Exception('failed host lookup: reddit.com');
    return const [];
  }

  @override
  Future<List<RedditUser>> searchUsers(String query) async {
    if (fail) throw Exception('failed host lookup: reddit.com');
    return const [];
  }
}

void main() {
  testWidgets('a failed search shows an error with retry, not no-results',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FlakySearchRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          redditRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: const SearchScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Failure is explicit and offers a retry — it must not masquerade as
    // "No posts found".
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No posts found'), findsNothing);

    // Retry with the network back succeeds and replaces the error view.
    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ErrorView), findsNothing);
  });
}
