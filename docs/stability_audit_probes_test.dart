// Diagnostic probes assert the observed bugs. These are NOT acceptance tests
// and intentionally live outside the passing regression suite.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:luli_for_reddit/core/interaction_actions.dart';
import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/feed/feed_controller.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/feed/post_overrides.dart';
import 'package:luli_for_reddit/features/inbox/inbox_controller.dart';
import 'package:luli_for_reddit/features/post/comments_controller.dart';
import 'package:luli_for_reddit/features/search/search_screen.dart';
import 'package:luli_for_reddit/features/settings/backup_service.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/inbox_item.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'package:luli_for_reddit/models/post.dart';
import '../test/support/interaction_fixture.dart';

class _ForbiddenClient extends RedditClient {
  _ForbiddenClient() : super(SecureStore(), AuthRepository(SecureStore()));
  @override
  Future<Response<T>> post<T>(
    String path, {
    Map<String, dynamic>? data,
  }) async =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 403);
}

class _ForbiddenRepo extends InteractionRepository {
  final delegate = RedditRepository(_ForbiddenClient());

  @override
  Future<void> vote(String fullname, int dir) => delegate.vote(fullname, dir);
}

class _Repo extends InteractionRepository {
  final more = Completer<Listing<Post>>();
  final comments = Completer<List<Comment>>();
  final search = <String, Completer<Listing<Post>>>{};
  final moreNode = Comment(
    id: 'more',
    fullname: 'more_more',
    author: '',
    body: '',
    score: 0,
    created: DateTime.utc(2026),
    depth: 0,
    parentId: 't3_p1',
    isMore: true,
    moreChildren: ['c2'],
  );
  @override
  Future<Listing<Post>> getPosts({
    String? subreddit,
    PostSort sort = PostSort.best,
    TopTime time = TopTime.day,
    String? after,
    int limit = 25,
  }) async {
    if (after != null) return more.future;
    return Listing(
      items: [interactionPost().copyWith(id: sort.name, title: sort.name)],
      after: 'cursor',
    );
  }

  @override
  Future<Listing<InboxItem>> getInbox({
    String where = 'inbox',
    String? after,
    int limit = 25,
  }) async => Listing(
    items: [
      InboxItem(
        fullname: 't4_msg',
        kind: InboxKind.message,
        author: 'alice',
        subject: 'hello',
        body: 'message',
        created: DateTime.utc(2026),
        isNew: true,
      ),
    ],
    after: 'next-inbox',
  );
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> markUnread(String id) async {}
  @override
  Future<void> deleteMessage(String id) async => throw StateError('offline');
  @override
  Future<(Post, List<Comment>)> getComments({
    required String subreddit,
    required String postId,
    String sort = 'confidence',
    String? focusCommentId,
  }) async => (interactionPost(), [moreNode]);
  @override
  Future<List<Comment>> getMoreComments({
    required String linkFullname,
    required List<String> childrenIds,
    String sort = 'confidence',
    int depth = 0,
  }) => comments.future;
  @override
  Future<Listing<Post>> searchPosts(
    String query, {
    String? subreddit,
    String? after,
    String sort = 'relevance',
    String time = 'all',
  }) => search.putIfAbsent(query, Completer<Listing<Post>>.new).future;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trackHistory': false,
      'swipeActions': false,
      'autoplayMedia': false,
      'forYouFeed': false,
      'defaultSort': PostSort.hot.index,
    });
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  test('P1: HTTP 403 vote is reported as successful and persisted', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = interactionContainer(
      prefs: prefs,
      repository: _ForbiddenRepo(),
    );
    addTearDown(container.dispose);
    await container
        .read(interactionActionsProvider)
        .votePost(interactionPost(), 1);
    expect(
      container
          .read(postOverridesProvider.notifier)
          .effective(interactionPost())
          .voteDirection,
      1,
    );
    expect(
      container.read(interactionVaultProvider).interactedPosts['p1']?.upvoted,
      isTrue,
    );
  });

  test(
    'P1: stale load-more response replaces the newly selected feed sort',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _Repo();
      final container = interactionContainer(prefs: prefs, repository: repo);
      addTearDown(container.dispose);
      final provider = feedControllerProvider('');
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final pending = controller.loadMore();
      await controller.changeSort(PostSort.newest);
      expect(container.read(provider).requireValue.sort, PostSort.newest);
      repo.more.complete(
        Listing(items: [interactionPost().copyWith(id: 'old-page')]),
      );
      await pending;
      expect(container.read(provider).requireValue.sort, PostSort.hot);
      expect(container.read(provider).requireValue.posts.last.id, 'old-page');
    },
  );

  test('P2: marking inbox read destroys its pagination cursor', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = interactionContainer(prefs: prefs, repository: _Repo());
    addTearDown(container.dispose);
    final provider = inboxControllerProvider('inbox');
    await container.read(provider.future);
    expect(container.read(provider).requireValue.after, 'next-inbox');
    await container.read(provider.notifier).markRead('t4_msg');
    expect(container.read(provider).requireValue.after, isNull);
  });

  test('P2: failed inbox delete loses the message without rollback', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = interactionContainer(prefs: prefs, repository: _Repo());
    addTearDown(container.dispose);
    final provider = inboxControllerProvider('inbox');
    await container.read(provider.future);
    await container.read(provider.notifier).deleteMessage('t4_msg');
    expect(container.read(provider).requireValue.items, isEmpty);
  });

  test(
    'P2: edit during more-comments fetch prevents the placeholder from being replaced',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _Repo();
      final container = interactionContainer(prefs: prefs, repository: repo);
      addTearDown(container.dispose);
      final provider = commentsControllerProvider('flutter/p1');
      final keepAlive = container.listen(provider, (_, __) {});
      addTearDown(keepAlive.close);
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final pending = controller.loadMore(repo.moreNode);
      controller.applyEdit('t1_unrelated', 'edited body');
      repo.comments.complete([
        interactionComment().copyWith(id: 'c2', parentId: 't3_p1'),
      ]);
      await pending;
      expect(
        container.read(provider).requireValue.comments.single.isMore,
        isTrue,
      );
    },
  );

  test(
    'P1: rejected backup restore already overwrites current credentials',
    () async {
      final prefs = await SharedPreferences.getInstance();
      FlutterSecureStorage.setMockInitialValues({
        'client_id': 'original-client',
      });
      final store = SecureStore();
      final service = BackupService(preferences: prefs, secureStore: store);
      final result = await service.importBackup(
        jsonEncode({
          'schema_version': 1,
          'api_keys': {'client_id': 'imported-client'},
          'auth_data': {'token_expiry': 'invalid-date'},
          'preferences': {},
        }),
      );
      expect(result.success, isFalse);
      expect(await store.clientId, 'imported-client');
    },
  );

  testWidgets(
    'P1: second upvote tap from a feed card sends unsupported direction zero',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = interactionContainer(prefs: prefs);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(null),
            home: Scaffold(
              body: PostCard(
                post: interactionPost(likes: true),
                frontpageStyle: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      expect(tester.takeException(), isA<AssertionError>());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('P2: history disabled still records dwell for unread cards', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final container = interactionContainer(prefs: prefs);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: Scaffold(
            body: PostCard(post: interactionPost(), frontpageStyle: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(interactionVaultProvider).isSeen('p1'), isTrue);
  });

  testWidgets('P2: an old search response replaces the latest query results', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repo();
    final container = interactionContainer(prefs: prefs, repository: repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: const SearchScreen(initialSubreddit: 'flutter'),
        ),
      ),
    );
    for (final query in ['first', 'second']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
    }
    repo.search['second']!.complete(
      Listing(items: [interactionPost().copyWith(title: 'second result')]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('second result'), findsOneWidget);
    repo.search['first']!.complete(
      Listing(items: [interactionPost().copyWith(title: 'stale first result')]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('stale first result'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'second',
    );
    await tester.pump(const Duration(milliseconds: 500));
  });
}
