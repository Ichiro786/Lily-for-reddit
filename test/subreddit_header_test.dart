import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/features/subreddit/subreddit_header.dart';
import 'package:luli_for_reddit/models/subreddit.dart';

Subreddit _subreddit({String? bannerUrl}) => Subreddit(
      name: 'flutter',
      namePrefixed: 'r/flutter',
      title: 'Flutter Developers',
      description:
          'A community for discussing Flutter, Dart, and expressive interface design.',
      subscribers: 128000,
      iconUrl: null,
      bannerUrl: bannerUrl,
      userIsSubscriber: false,
    );

Widget _harness(Widget child) => MaterialApp(
      theme: AppTheme.dark(null, amoled: true),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders a full hero banner with overlapping avatar and stats',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        M3ESubredditHeader(
          subreddit: _subreddit(bannerUrl: 'https://example.com/banner.jpg'),
          joined: false,
          onJoinToggle: () {},
          onlineCount: 420,
          createdAt: DateTime.utc(2012, 3, 14),
          accessLabel: 'Public',
          categoryLabel: 'Technology',
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.text('Flutter Developers'), findsOneWidget);
    expect(find.text('128.0k members'), findsOneWidget);
    expect(find.text('420 online'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Mar 2012'), findsOneWidget);
    expect(find.text('Access'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Technology'), findsOneWidget);
  });

  testWidgets('uses a themed gradient fallback when no banner is available',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        M3ESubredditHeader(
          subreddit: _subreddit(),
          joined: false,
          onJoinToggle: () {},
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).gradient is LinearGradient,
      ),
      findsOneWidget,
    );
    expect(find.text('Community'), findsOneWidget);
  });

  testWidgets('sort selection reports the selected PostSort value',
      (tester) async {
    PostSort? selected;
    await tester.pumpWidget(
      _harness(
        M3ESubredditControlBar(
          sort: PostSort.best,
          onSortChanged: (value) => selected = value,
          display: PostDisplay.card,
          onDisplayChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Best'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hot').last);

    expect(selected, PostSort.hot);
  });

  testWidgets('join capsule invokes its callback', (tester) async {
    // Intentional update (Phase 1): the notification capsule was removed —
    // the repository exposes no Reddit API for subreddit notifications, so
    // keeping a purely cosmetic toggle was misleading.
    var joins = 0;
    await tester.pumpWidget(
      _harness(
        M3ESubredditHeader(
          subreddit: _subreddit(),
          joined: false,
          onJoinToggle: () => joins++,
        ),
      ),
    );

    await tester.tap(find.text('Join'));
    expect(find.byTooltip('Enable notifications'), findsNothing);

    expect(joins, 1);
  });
}
