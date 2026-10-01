import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/features/post/comments_controller.dart';
import 'package:luli_for_reddit/models/comment.dart';
import 'package:luli_for_reddit/models/post.dart';
import 'support/interaction_fixture.dart';

class _Repo extends InteractionRepository {
  final response = Completer<List<Comment>>();
  int calls = 0;
  String? requestedSort;
  final more = Comment(
    id: 'more',
    fullname: 'more_more',
    parentId: 't3_p1',
    author: '',
    body: '',
    score: 0,
    created: DateTime.utc(2026),
    depth: 0,
    isMore: true,
    moreChildren: ['c2'],
  );
  @override
  Future<(Post, List<Comment>)> getComments({
    required String subreddit,
    required String postId,
    String sort = 'confidence',
    String? focusCommentId,
  }) async => (interactionPost(), [interactionComment(), more]);
  @override
  Future<List<Comment>> getMoreComments({
    required String linkFullname,
    required List<String> childrenIds,
    String sort = 'confidence',
    int depth = 0,
  }) {
    calls++;
    requestedSort = sort;
    return response.future;
  }
}

void main() {
  for (final mutation in ['edit', 'reply', 'delete', 'failure', 'sort']) {
    test(
      'B09 stable placeholder survives concurrent $mutation; duplicates are ignored',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = _Repo();
        final errors = <Object>[];
        final c = interactionContainer(
          repository: repo,
          prefs: await SharedPreferences.getInstance(),
          extraOverrides: [
            moreRepliesFailureProvider.overrideWithValue(errors.add),
          ],
        );
        addTearDown(c.dispose);
        final p = commentsControllerProvider('flutter/p1');
        final sub = c.listen(p, (_, __) {});
        addTearDown(sub.close);
        await c.read(p.future);
        final ctl = c.read(p.notifier);
        await ctl.changeSort('new');
        final pending = ctl.loadMore(repo.more);
        await ctl.loadMore(repo.more.copyWith());
        expect(repo.calls, 1);
        expect(repo.requestedSort, 'new');
        switch (mutation) {
          case 'edit':
            ctl.applyEdit('t1_c1', 'edited');
          case 'reply':
            ctl.insertReply(
              't1_c1',
              interactionComment().copyWith(id: 'reply', fullname: 't1_reply'),
            );
          case 'delete':
            ctl.removeComment('t1_c1');
          case 'sort':
            await ctl.changeSort('top');
        }
        final child = interactionComment().copyWith(
          id: 'c2',
          fullname: 't1_c2',
          parentId: 't3_p1',
        );
        if (mutation == 'failure') {
          repo.response.completeError(StateError('offline'));
        } else {
          repo.response.complete([child, child]);
        }
        await pending;
        final s = c.read(p).requireValue;
        expect(errors.length, mutation == 'failure' ? 1 : 0);
        expect(s.loadingMore, isEmpty);
        if (mutation == 'failure' || mutation == 'sort') {
          expect(s.comments.where((n) => n.isMore), hasLength(1));
        } else {
          expect(s.comments.where((n) => n.isMore), isEmpty);
          expect(s.comments.where((n) => n.fullname == 't1_c2'), hasLength(1));
          if (mutation == 'edit') expect(s.comments.first.body, 'edited');
          if (mutation == 'reply') {
            expect(s.comments.first.replies.single.id, 'reply');
          }
          if (mutation == 'delete') {
            expect(s.comments.any((n) => n.id == 'c1'), false);
          }
        }
      },
    );
  }
}
