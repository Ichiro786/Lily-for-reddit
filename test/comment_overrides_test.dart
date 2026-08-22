import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/features/post/comment_card.dart';
import 'package:luli_for_reddit/features/post/comment_overrides.dart';
import 'package:luli_for_reddit/models/comment.dart';

Comment _comment({
  String id = 'c1',
  int score = 100,
  bool? likes,
  bool saved = false,
}) =>
    Comment(
      id: id,
      fullname: 't1_$id',
      author: 'alice',
      body: 'body',
      score: score,
      created: DateTime.utc(2026, 1, 1),
      depth: 0,
      likes: likes,
      saved: saved,
    );

({int dir, int score, bool saved}) _effective(
  ProviderContainer container,
  Comment c,
) {
  final ov = container.read(commentOverridesProvider.notifier).effective(c);
  return (dir: ov.voteDirection, score: ov.score, saved: ov.saved);
}

Future<void> _vote(
  ProviderContainer container,
  Comment c,
  int dir, {
  bool fail = false,
}) {
  return container.read(commentOverridesProvider.notifier).vote(
        c,
        dir,
        (_) async {
          if (fail) throw Exception('network');
        },
      );
}

Future<void> _toggleSave(
  ProviderContainer container,
  Comment c, {
  bool fail = false,
}) {
  return container.read(commentOverridesProvider.notifier).toggleSave(
        c,
        (_) async {
          if (fail) throw Exception('network');
        },
      );
}

void main() {
  test('neutral -> upvote applies exactly +1', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _vote(container, c, 1);
    expect(_effective(container, c), (dir: 1, score: 101, saved: false));
  });

  test('neutral -> downvote applies exactly -1', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _vote(container, c, -1);
    expect(_effective(container, c), (dir: -1, score: 99, saved: false));
  });

  test('upvote -> neutral restores base score', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(commentOverridesProvider.notifier);

    await _vote(container, c, 1);
    await _vote(container, c, 1); // toggle off
    expect(_effective(container, c), (dir: 0, score: 100, saved: false));
    notifier.setVote(c, 0); // idempotent no-op guard
    expect(_effective(container, c), (dir: 0, score: 100, saved: false));
  });

  test('downvote -> neutral restores base score', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _vote(container, c, -1);
    await _vote(container, c, -1);
    expect(_effective(container, c), (dir: 0, score: 100, saved: false));
  });

  test('upvote -> downvote applies the net delta once', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _vote(container, c, 1);
    await _vote(container, c, -1);
    expect(_effective(container, c), (dir: -1, score: 99, saved: false));
  });

  test('downvote -> upvote applies the net delta once', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _vote(container, c, -1);
    await _vote(container, c, 1);
    expect(_effective(container, c), (dir: 1, score: 101, saved: false));
  });

  test('save/unsave transitions both ways', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _toggleSave(container, c);
    expect(_effective(container, c).saved, isTrue);
    await _toggleSave(container, c);
    expect(_effective(container, c).saved, isFalse);
  });

  test('server-pre-voted baseline is preserved until changed', () async {
    final c = _comment(score: 100, likes: true);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(_effective(container, c), (dir: 1, score: 100, saved: false));
    await _vote(container, c, -1);
    // Net single-delta switch from server state.
    expect(_effective(container, c), (dir: -1, score: 98, saved: false));
  });

  test('server-saved baseline survives unrelated votes', () async {
    final c = _comment(saved: true);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _vote(container, c, 1);
    expect(_effective(container, c).saved, isTrue);
    await _toggleSave(container, c); // unsaves
    expect(_effective(container, c).saved, isFalse);
  });

  test('failed vote reverts to previous authoritative state', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _vote(container, c, 1); // succeeds -> 101/up
    await _vote(container, c, -1, fail: true); // fails
    expect(_effective(container, c), (dir: 1, score: 101, saved: false));
  });

  test('first failed vote leaves neutral untouched', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _vote(container, c, -1, fail: true);
    expect(_effective(container, c), (dir: 0, score: 100, saved: false));
  });

  test('failed save reverts to previous saved state', () async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _toggleSave(container, c, fail: true);
    expect(_effective(container, c).saved, isFalse);

    await _toggleSave(container, c); // succeeds
    await _toggleSave(container, c, fail: true); // unsave fails
    expect(_effective(container, c).saved, isTrue);
  });

  test('independent comments do not affect each other', () async {
    final a = _comment(id: 'aaa');
    final b = _comment(id: 'bbb');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _vote(container, a, 1);
    await _vote(container, b, -1);
    await _toggleSave(container, b);

    expect(_effective(container, a), (dir: 1, score: 101, saved: false));
    expect(_effective(container, b), (dir: -1, score: 99, saved: true));
  });

  testWidgets(
      'comment interaction state survives rebuilds and collapse/expand',
      (tester) async {
    final c = _comment();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var collapsed = false;
    void Function() refresh = () {};
    Widget buildHarness() => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  refresh = () {
                    setState(() {});
                  };
                  return M3ECommentCard(
                    author: c.author,
                    timeAgo: '1h',
                    body: c.body,
                    score: container
                        .read(commentOverridesProvider.notifier)
                        .effective(c)
                        .score,
                    voteState: container
                        .read(commentOverridesProvider.notifier)
                        .effective(c)
                        .voteDirection,
                    isSaved: container
                        .read(commentOverridesProvider.notifier)
                        .effective(c)
                        .saved,
                    replyCount: 2,
                    isCollapsed: collapsed,
                    onToggleCollapse: () =>
                        setState(() => collapsed = !collapsed),
                  );
                },
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildHarness());

    // Interact through the authoritative store, then refresh the parent so it
    // re-reads effective state (mirrors the real tile's ref.watch rebuild).
    await _vote(container, c, 1);
    refresh();
    await tester.pump();
    expect(find.text('101'), findsOneWidget);

    // Collapse hides the score row...
    await tester.tap(find.text('u/alice'));
    await tester.pumpAndSettle();
    expect(find.text('101'), findsNothing);

    // ...but the authoritative state is unchanged.
    expect(_effective(container, c), (dir: 1, score: 101, saved: false));

    // Expand again: the same optimistic state renders (no reset).
    await tester.tap(find.text('u/alice'));
    await tester.pumpAndSettle();
    expect(find.text('101'), findsOneWidget);
    expect(find.text('102'), findsNothing);

    // Full widget rebuild (new tree, same scope) keeps state.
    await tester.pumpWidget(buildHarness());
    expect(find.text('101'), findsOneWidget);
  });
}
