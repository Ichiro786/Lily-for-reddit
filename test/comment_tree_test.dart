import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/post/comment_compose_bar.dart';

Widget _harness(Widget child) => MaterialApp(
      theme: AppTheme.dark(null),
      home: Scaffold(body: child),
    );

M3ECommentCard _card({required int depth, bool collapsed = false}) {
  return M3ECommentCard(
    author: 'alice',
    timeAgo: '1h',
    body: 'Comment body',
    depth: depth,
    isOp: depth == 0,
    isCollapsed: collapsed,
    score: 42,
    replyCount: collapsed ? 2 : 0,
    onToggleCollapse: () {},
    onVote: (_) {},
    onReply: () {},
    onSave: () {},
  );
}

void main() {
  testWidgets('depth rails cycle through M3E primary, secondary, and tertiary',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        Column(
          children: [
            _card(depth: 1),
            _card(depth: 2),
            _card(depth: 3),
            _card(depth: 4),
          ],
        ),
      ),
    );

    final expected = [
      const Color(0xFFA78BFA),
      const Color(0xFF38BDF8),
      const Color(0xFFF472B6),
      const Color(0xFFFACC15),
    ];
    for (var depth = 1; depth <= 4; depth++) {
      final rail = tester.widget<Container>(
        find.byKey(ValueKey<String>('comment-depth-rail-$depth')),
      );
      final decoration = rail.decoration! as BoxDecoration;
      expect(decoration.color, expected[depth - 1]);
    }
  });

  testWidgets('tapping the comment header collapses and expands the body',
      (tester) async {
    var collapsed = false;
    await tester.pumpWidget(
      _harness(
        StatefulBuilder(
          builder: (context, setState) => M3ECommentCard(
            author: 'alice',
            timeAgo: '1h',
            body: 'Expanded comment body',
            depth: 1,
            isOp: true,
            isCollapsed: collapsed,
            score: 42,
            replyCount: 2,
            onToggleCollapse: () => setState(() => collapsed = !collapsed),
            onVote: (_) {},
            onReply: () {},
            onSave: () {},
          ),
        ),
      ),
    );

    expect(find.text('Expanded comment body'), findsOneWidget);
    await tester.tap(find.text('u/alice'));
    await tester.pumpAndSettle();
    expect(collapsed, isTrue);
    expect(find.text('Expanded comment body'), findsNothing);
    expect(find.text('+2'), findsOneWidget);

    await tester.tap(find.text('u/alice'));
    await tester.pumpAndSettle();
    expect(collapsed, isFalse);
    expect(find.text('Expanded comment body'), findsOneWidget);
  });

  testWidgets('expanded comment restores reply, save, and overflow actions',
      (tester) async {
    // Intentional update (Phase 1): M3ECommentCard is now a controlled
    // presenter — the parent owns vote/save state. This harness mirrors
    // _CommentTileState and flips [isSaved] when onSave fires, so the visual
    // sync path through a rebuild is exercised instead of internal card state.
    var replies = 0;
    var saves = 0;
    var overflows = 0;
    var saved = false;
    await tester.pumpWidget(
      _harness(
        StatefulBuilder(
          builder: (context, setState) => M3ECommentCard(
            author: 'alice',
            timeAgo: '1h',
            body: 'Comment body',
            score: 12,
            isSaved: saved,
            onReply: () => replies++,
            onSave: () => setState(() {
              saves++;
              saved = !saved;
            }),
            onOverflow: () => overflows++,
          ),
        ),
      ),
    );
    expect(find.text('Reply'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    await tester.tap(find.text('Reply'));
    await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    expect(replies, 1);
    expect(saves, 1);
    expect(overflows, 1);
  });

  testWidgets('compose dock sends text and exposes gallery action',
      (tester) async {
    String? sent;
    var selected = 0;
    var jumps = 0;
    await tester.pumpWidget(
      _harness(
        CommentComposeBar(
          onSubmit: (text) => sent = text,
          onImageSelected: (file) {
            if (file != null) selected++;
          },
          onJumpNext: () => jumps++,
        ),
      ),
    );

    expect(find.text('Add a comment...'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Hello M3E');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));

    expect(sent, 'Hello M3E');
    expect(selected, 0);
    expect(jumps, 1);
  });

  testWidgets('jump FAB is hidden while the keyboard is open', (tester) async {
    await tester.pumpWidget(
      _harness(
        MediaQuery(
          data: const MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: 320),
          ),
          child: CommentComposeBar(
            onSubmit: (_) {},
            onImageSelected: (_) {},
            onJumpNext: () {},
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
  });

  testWidgets('renders the authoritative score verbatim; taps emit direction',
      (tester) async {
    // Regression (Phase 1): the card used to add its own voteState to score,
    // double-counting the parent's optimistic delta. It must render [score]
    // exactly and only report the tapped direction.
    final votes = <int>[];
    await tester.pumpWidget(
      _harness(
        M3ECommentCard(
          author: 'alice',
          timeAgo: '1h',
          body: 'Comment body',
          score: 100,
          onVote: votes.add,
        ),
      ),
    );
    expect(find.text('100'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
    await tester.pump();

    expect(votes, [1, -1]);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('101'), findsNothing);
    expect(find.text('99'), findsNothing);
  });

  testWidgets('initial vote and saved interaction state come from props',
      (tester) async {
    // Regression (Phase 1): already-voted/already-saved comments used to
    // render as neutral because the card initialised internal state.
    await tester.pumpWidget(
      _harness(
        M3ECommentCard(
          author: 'alice',
          timeAgo: '1h',
          body: 'Comment body',
          score: 42,
          voteState: 1,
          isSaved: true,
        ),
      ),
    );

    expect(find.text('42'), findsOneWidget);
    final up =
        tester.widget<Icon>(find.byIcon(Icons.arrow_upward_rounded));
    expect(up.color, const Color(0xFFFF5722));
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
  });

  testWidgets('interaction visuals follow new state across rebuilds',
      (tester) async {
    Widget build(int voteState, bool isSaved) => _harness(
          M3ECommentCard(
            key: const ValueKey<String>('card'),
            author: 'alice',
            timeAgo: '1h',
            body: 'Comment body',
            score: 7,
            voteState: voteState,
            isSaved: isSaved,
          ),
        );

    await tester.pumpWidget(build(0, false));
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);

    await tester.pumpWidget(build(-1, true));

    final cs =
        Theme.of(tester.element(find.byType(M3ECommentCard))).colorScheme;
    expect(
      tester.widget<Icon>(find.byIcon(Icons.arrow_downward_rounded)).color,
      cs.error,
    );
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}
