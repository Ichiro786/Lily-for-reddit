import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/features/feed/feed_controller.dart';
import 'package:luli_for_reddit/features/feed/paged_list.dart';
import 'package:luli_for_reddit/features/post/comments_controller.dart';
import 'package:luli_for_reddit/features/search/search_screen.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'package:luli_for_reddit/models/post.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'support/interaction_fixture.dart';

class RaceRepository extends InteractionRepository {
  Completer<Listing<Post>>? initial;
  final page = Completer<Listing<Post>>();
  final sorts = <PostSort, Completer<Listing<Post>>>{};
  final searches = <String, Completer<Listing<Post>>>{};
  final threads = <String, Completer<(Post, List<Comment>)>>{};
  @override
  Future<Listing<Post>> getPosts({
    String? subreddit,
    PostSort sort = PostSort.best,
    TopTime time = TopTime.day,
    String? after,
    int limit = 25,
  }) {
    if (after != null) return page.future;
    if (sort == PostSort.hot) {
      return initial?.future ??
          Future.value(Listing(items: [interactionPost()], after: 'cursor'));
    }
    return sorts.putIfAbsent(sort, Completer<Listing<Post>>.new).future;
  }

  @override
  Future<Listing<Post>> searchPosts(
    String query, {
    String? subreddit,
    String? after,
    String sort = 'relevance',
    String time = 'all',
  }) => searches.putIfAbsent(query, Completer<Listing<Post>>.new).future;
  @override
  Future<(Post, List<Comment>)> getComments({
    required String subreddit,
    required String postId,
    String sort = 'confidence',
    String? focusCommentId,
  }) {
    if (sort == 'confidence') {
      return Future.value((interactionPost(), [interactionComment()]));
    }
    return threads
        .putIfAbsent(sort, Completer<(Post, List<Comment>)>.new)
        .future;
  }
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'forYouFeed': false,
      'defaultSort': PostSort.hot.index,
      'trackHistory': false,
      'autoplayMedia': false,
      'swipeActions': false,
    }),
  );
  for (final fail in [false, true]) {
    test(
      'B06 late feed pagination ${fail ? 'failure' : 'success'} cannot replace new sort',
      () async {
        final repo = RaceRepository();
        final c = interactionContainer(
          prefs: await SharedPreferences.getInstance(),
          repository: repo,
        );
        addTearDown(c.dispose);
        final p = feedControllerProvider('flutter');
        await c.read(p.future);
        final controller = c.read(p.notifier);
        final old = controller.loadMore();
        final next = controller.changeSort(PostSort.newest);
        repo.sorts[PostSort.newest]!.complete(
          Listing(items: [interactionPost().copyWith(id: 'new')]),
        );
        await next;
        if (fail) {
          repo.page.completeError(StateError('offline'));
        } else {
          repo.page.complete(
            Listing(items: [interactionPost().copyWith(id: 'old')]),
          );
        }
        await old;
        expect(c.read(p).requireValue.sort, PostSort.newest);
        expect(c.read(p).requireValue.posts.map((p) => p.id), ['new']);
      },
    );
  }
  test('B06 earlier feed sort cannot overwrite later completed sort', () async {
    final repo = RaceRepository();
    final c = interactionContainer(
      prefs: await SharedPreferences.getInstance(),
      repository: repo,
    );
    addTearDown(c.dispose);
    final p = feedControllerProvider('flutter');
    await c.read(p.future);
    final ctl = c.read(p.notifier);
    final a = ctl.changeSort(PostSort.newest);
    final b = ctl.changeSort(PostSort.top);
    repo.sorts[PostSort.top]!.complete(
      Listing(items: [interactionPost().copyWith(id: 'top')]),
    );
    await b;
    repo.sorts[PostSort.newest]!.complete(
      Listing(items: [interactionPost().copyWith(id: 'new')]),
    );
    await a;
    expect(c.read(p).requireValue.sort, PostSort.top);
    expect(c.read(p).requireValue.posts.single.id, 'top');
  });
  test('B06 comment sort completion is ordered by intent', () async {
    final repo = RaceRepository();
    final c = interactionContainer(
      prefs: await SharedPreferences.getInstance(),
      repository: repo,
    );
    addTearDown(c.dispose);
    final p = commentsControllerProvider('flutter/p1');
    final sub = c.listen(p, (_, __) {});
    addTearDown(sub.close);
    await c.read(p.future);
    final ctl = c.read(p.notifier);
    final a = ctl.changeSort('top');
    final b = ctl.changeSort('new');
    repo.threads['new']!.complete((
      interactionPost(),
      [interactionComment().copyWith(body: 'new')],
    ));
    await b;
    repo.threads['top']!.complete((
      interactionPost(),
      [interactionComment().copyWith(body: 'old')],
    ));
    await a;
    expect(c.read(p).requireValue.comments.single.body, 'new');
  });
  for (final clear in [false, true]) {
    testWidgets(
      'B06 search ignores old results after ${clear ? 'clear' : 'new query'}',
      (tester) async {
        final repo = RaceRepository();
        final c = interactionContainer(
          prefs: await SharedPreferences.getInstance(),
          repository: repo,
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: const MaterialApp(
              home: SearchScreen(initialSubreddit: 'flutter'),
            ),
          ),
        );
        for (final q in ['first', 'second']) {
          await tester.enterText(find.byType(TextField), q);
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pump();
        }
        if (clear) {
          await tester.tap(find.byIcon(Icons.clear_rounded));
          await tester.pump();
        }
        repo.searches['second']!.complete(
          Listing(items: [interactionPost().copyWith(title: 'second result')]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        repo.searches['first']!.complete(
          Listing(items: [interactionPost().copyWith(title: 'stale result')]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('stale result'), findsNothing);
        expect(
          find.text('second result'),
          clear ? findsNothing : findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  }
  testWidgets('B06 list request identity rejects old account results', (
    tester,
  ) async {
    final a = Completer<Listing<String>>();
    final b = Completer<Listing<String>>();
    Widget list(String key, Completer<Listing<String>> response) => MaterialApp(
      home: Scaffold(
        body: PagedList<String>(
          requestKey: key,
          fetch: (_) => response.future,
          itemBuilder: (_, item) => Text(item),
        ),
      ),
    );
    await tester.pumpWidget(list('alice', a));
    await tester.pumpWidget(list('bob', b));
    b.complete(const Listing(items: ['bob']));
    await tester.pump();
    a.complete(const Listing(items: ['alice']));
    await tester.pump();
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('alice'), findsNothing);
  });
  test(
    'B06 late initial provider build cannot overwrite a manual sort',
    () async {
      final repo = RaceRepository()..initial = Completer<Listing<Post>>();
      final c = interactionContainer(
        prefs: await SharedPreferences.getInstance(),
        repository: repo,
      );
      addTearDown(c.dispose);
      final p = feedControllerProvider('flutter');
      final sub = c.listen(p, (_, __) {});
      addTearDown(sub.close);
      final next = c.read(p.notifier).changeSort(PostSort.newest);
      repo.sorts[PostSort.newest]!.complete(
        Listing(items: [interactionPost().copyWith(id: 'new')]),
      );
      await next;
      repo.initial!.complete(
        Listing(items: [interactionPost().copyWith(id: 'old')]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.read(p).requireValue.posts.single.id, 'new');
    },
  );
}
