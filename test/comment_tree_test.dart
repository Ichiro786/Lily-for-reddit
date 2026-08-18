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

    final colorScheme = AppTheme.dark(null).colorScheme;
    final expected = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.primary,
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
    expect(find.text('Expanded comment body'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);

    await tester.tap(find.text('u/alice'));
    await tester.pumpAndSettle();
    expect(collapsed, isFalse);
    expect(find.text('Expanded comment body'), findsOneWidget);
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
}
