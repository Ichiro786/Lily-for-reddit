import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/feed/feed_controller.dart';
import 'package:luli_for_reddit/features/feed/feed_resume_store.dart';
import 'package:luli_for_reddit/features/feed/post_list_view.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/history/history_store.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'package:luli_for_reddit/models/post.dart';
import 'support/interaction_fixture.dart';

Post post(String id) => interactionPost().copyWith(id: id, fullname: 't3_$id');

class FeedRepository extends InteractionRepository {
  final pages = <String?, Listing<Post>>{};
  final requests = <(String?, PostSort, TopTime, String?)>[];
  Completer<Listing<Post>>? pending;
  Future<Listing<Post>> listing(
    String? feed,
    PostSort sort,
    TopTime time,
    String? after,
  ) {
    requests.add((feed, sort, time, after));
    return pending?.future ??
        Future.value(pages[after] ?? const Listing(items: []));
  }

  @override
  Future<Listing<Post>> getPosts({
    String? subreddit,
    PostSort sort = PostSort.best,
    TopTime time = TopTime.day,
    String? after,
    int limit = 25,
  }) => listing(subreddit, sort, time, after);
  @override
  Future<Listing<Post>> getMultiPosts({
    required String username,
    required String multiname,
    PostSort sort = PostSort.hot,
    TopTime time = TopTime.day,
    String? after,
    int limit = 25,
  }) => listing('m::$username::$multiname', sort, time, after);
  @override
  Future<Listing<Post>> getForYouFeed({
    Map<String, double> interest = const {},
    Set<String> seen = const {},
    Set<String> muted = const {},
    Map<String, int> impressions = const {},
    double Function(String)? titleScore,
    String? Function(String)? titleKeyword,
    String? cursors,
    Set<String> excludeIds = const {},
    bool fast = false,
    Listing<Post>? bestSeed,
  }) => listing('For You', PostSort.best, TopTime.day, cursors);
}

Future<ProviderContainer> container(
  FeedRepository repo,
  SharedPreferences prefs,
) async {
  final c = interactionContainer(repository: repo, prefs: prefs);
  await c.read(authControllerProvider.future);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'defaultSort': PostSort.hot.index,
      'hideReadPosts': true,
      'trackHistory': true,
      'resumeFeeds': true,
    }),
  );

  for (final feed in ['', 'flutter', 'm::alice::favorites']) {
    for (final sort in [
      PostSort.hot,
      PostSort.newest,
      PostSort.rising,
      PostSort.top,
      PostSort.best,
    ]) {
      test(
        'read filtering preserves $sort order in $feed on initial, refresh and pagination',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('defaultSort', sort.index);
          final repo = FeedRepository()
            ..pages[null] = Listing(
              items: [post('read'), post('b'), post('a')],
              after: 'p2',
            );
          repo.pages['p2'] = Listing(items: [post('read')], after: 'p3');
          repo.pages['p3'] = Listing(items: [post('a'), post('c')]);
          final c = await container(repo, prefs);
          addTearDown(c.dispose);
          c.read(historyControllerProvider.notifier).markViewed(post('read'));
          final p = feedControllerProvider(feed);
          expect((await c.read(p.future)).posts.map((p) => p.id), ['b', 'a']);
          await c.read(p.notifier).refresh();
          await c.read(p.notifier).loadMore();
          final state = c.read(p).requireValue;
          expect(state.posts.map((p) => p.id), ['b', 'a', 'c']);
          expect(state.hasMore, false);
          expect(repo.requests.every((r) => r.$2 == sort), true);
          expect(c.read(historyControllerProvider).single.id, 'read');
        },
      );
    }
  }

  test(
    'For You and ordinary feeds share persisted seen filtering after restart',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('forYouFeed', true);
      final repo = FeedRepository()
        ..pages[null] = Listing(items: [post('seen'), post('fresh')]);
      final first = await container(repo, prefs);
      first.read(interactionVaultProvider.notifier).markSeen('seen');
      await first.read(interactionVaultProvider.notifier).flushPersisted();
      first.dispose();
      final c = await container(repo, prefs);
      addTearDown(c.dispose);
      expect(
        (await c.read(
          feedControllerProvider('').future,
        )).posts.map((p) => p.id),
        ['fresh'],
      );
      expect(
        (await c.read(
          feedControllerProvider('flutter').future,
        )).posts.map((p) => p.id),
        ['fresh'],
      );
    },
  );

  test(
    'hiding disabled keeps read posts through refresh independently of resume',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hideReadPosts', false);
      final repo = FeedRepository()
        ..pages[null] = Listing(items: [post('read'), post('fresh')]);
      final c = await container(repo, prefs);
      addTearDown(c.dispose);
      c.read(historyControllerProvider.notifier).markViewed(post('read'));
      final p = feedControllerProvider('flutter');
      await c.read(p.future);
      await c.read(p.notifier).refresh();
      expect(c.read(p).requireValue.posts.map((p) => p.id), ['read', 'fresh']);
      expect(c.read(settingsControllerProvider).resumeFeeds, true);
    },
  );

  test(
    'unchanged/reordered/read-only snapshots do not claim new posts; confirmed posts replace page',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FeedRepository()
        ..pages[null] = Listing(items: [post('a'), post('b')]);
      final c = await container(repo, prefs);
      addTearDown(c.dispose);
      final p = feedControllerProvider('flutter');
      await c.read(p.future);
      final ctl = c.read(p.notifier);
      await ctl.refreshIfStale(Duration.zero);
      expect(c.read(p).requireValue.hasPending, false);
      repo.pages[null] = Listing(items: [post('b'), post('a')]);
      await ctl.refreshIfStale(Duration.zero);
      expect(c.read(p).requireValue.hasPending, false);
      c.read(interactionVaultProvider.notifier).markSeen('old');
      repo.pages[null] = Listing(items: [post('old'), post('b'), post('a')]);
      await ctl.refreshIfStale(Duration.zero);
      expect(c.read(p).requireValue.hasPending, false);
      repo.pages[null] = Listing(
        items: [post('new'), post('a')],
        after: 'fresh-cursor',
      );
      await ctl.refreshIfStale(Duration.zero);
      expect(c.read(p).requireValue.posts.map((p) => p.id), ['a', 'b']);
      expect(c.read(p).requireValue.hasPending, true);
      expect(ctl.applyPending(), true);
      expect(c.read(p).requireValue.posts.map((p) => p.id), ['new', 'a']);
      expect(c.read(p).requireValue.after, 'fresh-cursor');
    },
  );

  test(
    'pending items read elsewhere are revalidated without a phantom scroll',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FeedRepository()..pages[null] = Listing(items: [post('a')]);
      final c = await container(repo, prefs);
      addTearDown(c.dispose);
      final p = feedControllerProvider('flutter');
      await c.read(p.future);
      repo.pages[null] = Listing(items: [post('new'), post('a')]);
      final ctl = c.read(p.notifier);
      await ctl.refreshIfStale(Duration.zero);
      c.read(interactionVaultProvider.notifier).markSeen('new');
      expect(ctl.applyPending(), false);
      expect(c.read(p).requireValue.hasPending, false);
      expect(c.read(p).requireValue.positionRevision, 0);
    },
  );

  test(
    'filtered pages terminate at repeated cursor and bound empty scans',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FeedRepository()
        ..pages[null] = Listing(items: [post('seen')], after: 'repeat');
      repo.pages['repeat'] = Listing(items: [post('seen')], after: 'repeat');
      final c = await container(repo, prefs);
      addTearDown(c.dispose);
      c.read(interactionVaultProvider.notifier).markSeen('seen');
      final state = await c.read(feedControllerProvider('flutter').future);
      expect(state.posts, isEmpty);
      expect(state.hasMore, false);
      expect(repo.requests.length, 2);
    },
  );

  for (final policy in ['recent', 'old', 'changed', 'disabled']) {
    test('restart resume policy: $policy', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hideReadPosts', false);
      final repo = FeedRepository()
        ..pages[null] = Listing(items: [post('a')], after: 'p2');
      repo.pages['p2'] = Listing(items: [post('b')]);
      final first = await container(repo, prefs);
      final p = feedControllerProvider('flutter');
      await first.read(p.future);
      await first.read(p.notifier).changeSort(PostSort.top, time: TopTime.week);
      await first.read(p.notifier).loadMore();
      first.read(p.notifier).savePosition(900);
      final store = first.read(feedResumeStoreProvider.notifier);
      if (policy == 'old') {
        final saved = first.read(feedResumeStoreProvider).feeds['flutter']!;
        store.save(
          'flutter',
          FeedBookmark(
            sort: saved.sort,
            time: saved.time,
            offset: 900,
            ids: saved.ids,
            pages: saved.pages,
            savedAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        );
      }
      await store.flush();
      first.dispose();
      if (policy == 'changed') {
        repo.pages[null] = Listing(
          items: [post('new'), post('a')],
          after: 'p2',
        );
      }
      if (policy == 'disabled') await prefs.setBool('resumeFeeds', false);
      final c = await container(repo, prefs);
      addTearDown(c.dispose);
      final restored = await c.read(p.future);
      expect(restored.initialScrollOffset, policy == 'recent' ? 900 : 0);
      expect(restored.sort, policy == 'disabled' ? PostSort.hot : PostSort.top);
      if (policy == 'recent') {
        expect(restored.time, TopTime.week);
        expect(restored.posts.map((p) => p.id), ['a', 'b']);
      }
      await c.read(p.notifier).refresh();
      expect(c.read(p).requireValue.initialScrollOffset, 0);
    });
  }

  test(
    'legacy For You toggle migrates and both settings remain independent',
    () async {
      SharedPreferences.setMockInitialValues({'autoHideReadForYou': true});
      final c = await container(
        FeedRepository(),
        await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      expect(c.read(settingsControllerProvider).hideReadPosts, true);
      c.read(settingsControllerProvider.notifier).setResumeFeeds(false);
      expect(c.read(settingsControllerProvider).hideReadPosts, true);
      c.read(settingsControllerProvider.notifier).setHideReadPosts(false);
      c.read(settingsControllerProvider.notifier).setResumeFeeds(true);
      expect(c.read(settingsControllerProvider).hideReadPosts, false);
    },
  );
  testWidgets('rendered feed restores its offset and resets on sort/refresh', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideReadPosts', false);
    await prefs.setBool('trackHistory', false);
    await prefs.setBool('autoplayMedia', false);
    final posts = List.generate(20, (i) => post('p$i'));
    final repo = FeedRepository()..pages[null] = Listing(items: posts);
    final c = await container(repo, prefs);
    addTearDown(c.dispose);
    c
        .read(feedResumeStoreProvider.notifier)
        .save(
          'flutter',
          FeedBookmark(
            sort: PostSort.top,
            time: TopTime.week,
            offset: 850,
            ids: posts.map((post) => post.id).toList(),
            pages: 1,
            savedAt: DateTime.now(),
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: const Scaffold(
            body: PostListView(feedKey: 'flutter', showSortBar: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    ScrollController scroll() =>
        tester.widget<ListView>(find.byType(ListView)).controller!;
    expect(scroll().offset, 850);
    final ctl = c.read(feedControllerProvider('flutter').notifier);
    await ctl.changeSort(PostSort.newest);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll().offset, 0);
    scroll().jumpTo(700);
    await tester.pump();
    await ctl.refresh();
    await tester.pump();
    await tester.pump();
    expect(scroll().offset, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(prefs.getString('feed_resume'), isNotNull);
    expect(c.read(feedResumeStoreProvider).feeds['flutter']!.offset, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
