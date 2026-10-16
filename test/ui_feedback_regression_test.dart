import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/compose/compose_post_screen.dart';
import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/profile/profile_tabs.dart';
import 'package:luli_for_reddit/features/profile/profile_media.dart';
import 'package:luli_for_reddit/features/profile/reddit_avatar.dart';
import 'package:luli_for_reddit/models/flair.dart';
import 'package:luli_for_reddit/models/reddit_user.dart';
import 'package:luli_for_reddit/models/subreddit.dart';
import 'support/interaction_fixture.dart';

const community = Subreddit(
  name: 'manga',
  namePrefixed: 'r/manga',
  title: 'Manga',
  description: '',
  subscribers: 100,
);

class FeedbackRepo extends InteractionRepository {
  final queries = <String>[];
  final suggestions = <Completer<List<Subreddit>>>[];
  final flairs = <String>[];
  final authors = <String>[];
  final communities = <String>[];
  @override
  Future<List<Subreddit>> searchSubreddits(String query) {
    queries.add(query);
    final request = Completer<List<Subreddit>>();
    suggestions.add(request);
    return request.future;
  }

  @override
  Future<List<Flair>> getLinkFlairs(String name) async {
    flairs.add(name);
    return [];
  }

  @override
  Future<RedditUser> getUserAbout(String name) async {
    authors.add(name);
    return RedditUser(
      name: name,
      created: DateTime.utc(2023),
      iconUrl: 'https://images.test/$name.png',
    );
  }

  @override
  Future<Subreddit> getSubredditAbout(String name) async {
    communities.add(name);
    return community.copyWith(iconUrl: 'https://images.test/community.png');
  }
}

Future<ProviderContainer> composer(
  WidgetTester tester,
  FeedbackRepo repo,
) async {
  SharedPreferences.setMockInitialValues({});
  final c = interactionContainer(
    repository: repo,
    prefs: await SharedPreferences.getInstance(),
  );
  addTearDown(c.dispose);
  await c.read(authControllerProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.dark(null),
        home: const ComposePostScreen(),
      ),
    ),
  );
  return c;
}

Finder get subredditField => find.byWidgetPredicate(
  (widget) =>
      widget is TextField && widget.decoration?.labelText == 'Subreddit',
);
void main() {
  testWidgets(
    'new-post typing suggests communities and selection loads flair without submitting',
    (tester) async {
      final repo = FeedbackRepo();
      await composer(tester, repo);
      await tester.enterText(subredditField, 'm');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(subredditField, 'R/Ma');
      await tester.pump(const Duration(milliseconds: 250));
      expect(repo.queries, ['ma']);
      repo.suggestions.single.complete([community, community]);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'r/manga'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('r/manga')).dy,
        greaterThan(tester.getBottomLeft(subredditField).dy),
      );
      await tester.tap(find.text('r/manga'));
      await tester.pump();
      expect(
        tester.widget<TextField>(subredditField).controller!.text,
        'manga',
      );
      expect(repo.flairs, contains('manga'));
      expect(
        find.byKey(const ValueKey('composer-community-suggestions')),
        findsNothing,
      );
      final title = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Title',
        ),
      );
      expect(title.focusNode!.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'composer ignores stale and cleared requests, retries errors, and clears on account switch',
    (tester) async {
      final repo = FeedbackRepo();
      final c = await composer(tester, repo);
      await tester.enterText(subredditField, 'a');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.enterText(subredditField, 'm');
      await tester.pump(const Duration(milliseconds: 250));
      repo.suggestions[1].complete([community]);
      await tester.pump();
      repo.suggestions[0].complete([]);
      await tester.pump();
      expect(find.text('r/manga'), findsOneWidget);
      await tester.enterText(subredditField, 'ma');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.enterText(subredditField, '');
      repo.suggestions[2].complete([community]);
      await tester.pump();
      expect(find.text('r/manga'), findsNothing);
      await tester.enterText(subredditField, 'm');
      await tester.pump(const Duration(milliseconds: 250));
      repo.suggestions[3].completeError(StateError('offline'));
      await tester.pump();
      await tester.tap(find.text('Could not load communities'));
      await tester.pump();
      c.read(authSessionEpochProvider.notifier).state++;
      await tester.pump();
      repo.suggestions[4].complete([community]);
      await tester.pump();
      expect(find.text('r/manga'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.4, 2.0]) {
      testWidgets(
        'all profile destinations fit $width at $scale text in RTL and LTR',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final direction in TextDirection.values) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Directionality(
                      textDirection: direction,
                      child: DefaultTabController(
                        length: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ProfileTabs(
                            tabs: [
                              for (final label in [
                                'Posts',
                                'Comments',
                                'Saved',
                                'Upvoted',
                                'About',
                              ])
                                Tab(text: label),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final bounds = tester.getRect(find.byType(ProfileTabs));
            for (final label in [
              'Posts',
              'Comments',
              'Saved',
              'Upvoted',
              'About',
            ]) {
              final rect = tester.getRect(find.text(label));
              expect(rect.left, greaterThanOrEqualTo(bounds.left));
              expect(rect.right, lessThanOrEqualTo(bounds.right));
              await tester.tap(find.text(label));
              await tester.pumpAndSettle();
              expect(
                DefaultTabController.of(
                  tester.element(find.byType(ProfileTabs)),
                ).index,
                [
                  'Posts',
                  'Comments',
                  'Saved',
                  'Upvoted',
                  'About',
                ].indexOf(label),
              );
            }
            expect(tester.takeException(), isNull);
          }
        },
      );
      testWidgets('deep thread More stays on voting row at $width and $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var more = 0;
        var replies = 0;
        var saved = 0;
        final votes = <int>[];
        for (final direction in TextDirection.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark(null),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Directionality(
                    textDirection: direction,
                    child: SingleChildScrollView(
                      child: M3ECommentCard(
                        author: 'long_author_name',
                        timeAgo: '12h',
                        body: 'A long reply. ' * 8,
                        depth: 12,
                        score: 13859,
                        onVote: votes.add,
                        onReply: () => replies++,
                        onSave: () => saved++,
                        onOverflow: () => more++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final menu = find.byTooltip('More comment options');
          expect(
            tester.getCenter(menu).dy,
            tester.getCenter(find.byTooltip('Upvote')).dy,
          );
          for (final target in [
            menu,
            find.byTooltip('Upvote'),
            find.byTooltip('Downvote'),
            find.byTooltip('Save comment'),
          ]) {
            expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
            await tester.ensureVisible(target);
            await tester.tap(target);
          }
          await tester.ensureVisible(find.text('Reply'));
          await tester.tap(find.text('Reply'));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(more, 2);
        expect(saved, 2);
        expect(replies, 2);
        expect(votes, [1, -1, 1, -1]);
      });
    }
  }
  test(
    'media parsers preserve signed URLs and use nonempty avatar fallbacks',
    () {
      expect(
        Subreddit.fromData({
          'display_name': 'manga',
          'community_icon': ' ',
          'icon_img': ' https://images.test/sub.png?s=32&amp;token=x ',
        }).iconUrl,
        'https://images.test/sub.png?s=32&token=x',
      );
      expect(
        RedditUser.fromData({
          'name': 'alice',
          'icon_img': '',
          'snoovatar_img': 'https://images.test/snoo.png',
        }).iconUrl,
        'https://images.test/snoo.png',
      );
    },
  );
  testWidgets(
    'user and community widgets render repository avatar URLs and skip deleted users',
    (tester) async {
      final repo = FeedbackRepo();
      final c = ProviderContainer(
        overrides: [redditRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  RedditAvatar(name: 'ALICE'),
                  RedditAvatar(name: 'alice'),
                  RedditAvatar(name: 'manga', community: true),
                  RedditAvatar(name: '[deleted]'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final images = tester
          .widgetList<ProfileAvatar>(find.byType(ProfileAvatar))
          .toList();
      expect(images.map((image) => image.url), [
        'https://images.test/alice.png',
        'https://images.test/alice.png',
        'https://images.test/community.png',
        null,
      ]);
      expect(repo.authors, ['alice']);
      expect(repo.communities, ['manga']);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'avatar lookups reuse author/community metadata and reset after account switch',
    () async {
      final repo = FeedbackRepo();
      final c = ProviderContainer(
        overrides: [redditRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final author = redditAvatarUrlProvider((name: 'alice', community: false));
      final subreddit = redditAvatarUrlProvider((
        name: 'manga',
        community: true,
      ));
      expect(await c.read(author.future), 'https://images.test/alice.png');
      expect(await c.read(author.future), 'https://images.test/alice.png');
      expect(
        await c.read(subreddit.future),
        'https://images.test/community.png',
      );
      expect(
        await c.read(subreddit.future),
        'https://images.test/community.png',
      );
      expect(repo.authors, ['alice']);
      expect(repo.communities, ['manga']);
      c.read(authSessionEpochProvider.notifier).state++;
      await c.read(author.future);
      expect(repo.authors, ['alice', 'alice']);
    },
  );
  test(
    'avatar queue limits parallel requests and skips disposed rows',
    () async {
      final queue = AvatarRequestQueue();
      final pending = <Completer<int>>[];
      var cancelled = false;
      Future<int> request() {
        final c = Completer<int>();
        pending.add(c);
        return c.future;
      }

      final futures = [
        for (var i = 0; i < 5; i++)
          queue.run(request, () => i != 3 || !cancelled),
      ];
      expect(pending.length, 3);
      cancelled = true;
      pending[0].complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(pending.length, 4);
      for (var i = 1; i < pending.length; i++) {
        pending[i].complete(i);
      }
      expect(await futures[3], isNull);
      await Future.wait(futures);
    },
  );
}
