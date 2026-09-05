import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/feed/post_action_bar.dart';

Widget _harness(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.dark(null),
    home: Scaffold(body: child),
  );
}

void main() {
  group('M3EPostActionBar', () {
    testWidgets('renders all primary and secondary actions without overflow on standard phone width (360dp)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const SizedBox(
            width: 360,
            child: M3EPostActionBar(
              score: 2450,
              commentCount: 182,
              voteState: 0,
              isSaved: false,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('2.5k'), findsOneWidget);
      expect(find.text('182'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shortcut_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
    });

    testWidgets('renders upvoted state with active vote colors', (tester) async {
      await tester.pumpWidget(
        _harness(
          const M3EPostActionBar(
            score: 500,
            commentCount: 20,
            voteState: 1,
            isSaved: true,
          ),
        ),
      );

      expect(find.text('500'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });

    testWidgets('triggers callbacks with correct parameters on user taps', (tester) async {
      var vote = 0;
      var commentTapped = false;
      var shareTapped = false;
      var saveTapped = false;
      var moreTapped = false;

      await tester.pumpWidget(
        _harness(
          M3EPostActionBar(
            score: 42,
            commentCount: 7,
            voteState: 0,
            isSaved: false,
            onVote: (v) => vote = v,
            onCommentTap: () => commentTapped = true,
            onShareTap: () => shareTapped = true,
            onSaveTap: () => saveTapped = true,
            onMoreTap: () => moreTapped = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(vote, 1);

      await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
      expect(vote, -1);

      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      expect(commentTapped, isTrue);

      await tester.tap(find.byIcon(Icons.shortcut_rounded));
      expect(shareTapped, isTrue);

      await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
      expect(saveTapped, isTrue);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      expect(moreTapped, isTrue);
    });

    testWidgets('adapts smoothly across narrow widths (240dp to 420dp)', (tester) async {
      for (final width in [240.0, 320.0, 360.0, 400.0, 420.0]) {
        await tester.pumpWidget(
          _harness(
            SizedBox(
              width: width,
              child: const M3EPostActionBar(
                score: 999999,
                commentCount: 88888,
                voteState: 1,
                isSaved: true,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'Failed at width $width');
      }
    });

    testWidgets('controls use 36dp height and 17dp icons for compact density',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const SizedBox(
            width: 400,
            child: M3EPostActionBar(
              score: 50,
              commentCount: 12,
              voteState: 0,
            ),
          ),
        ),
      );

      final voteGroupFinder = find.byType(AnimatedContainer).first;
      expect(tester.getSize(voteGroupFinder).height, 36);

      final commentContainerFinder = find.descendant(
        of: find.bySemanticsLabel('12 comments'),
        matching: find.byType(Container),
      ).first;
      expect(tester.getSize(commentContainerFinder).height, 36);
    });
  });
}
