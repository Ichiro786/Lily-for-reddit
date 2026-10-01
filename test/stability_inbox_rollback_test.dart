import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/features/inbox/inbox_controller.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/models/inbox_item.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'support/interaction_fixture.dart';

class _Repo extends InteractionRepository {
  _Repo({this.initialNew = true});
  final bool initialNew;
  final requests = <Completer<void>>[];
  Future<void> _request() {
    final c = Completer<void>();
    requests.add(c);
    return c.future;
  }

  @override
  Future<void> markRead(String id) => _request();
  @override
  Future<void> markUnread(String id) => _request();
  @override
  Future<void> deleteMessage(String id) => _request();
  @override
  Future<void> markAllRead() => _request();
  @override
  Future<Listing<InboxItem>> getInbox({
    String where = 'inbox',
    String? after,
    int limit = 25,
  }) async => Listing(
    items: [
      InboxItem(
        fullname: after == null ? 't4_msg' : 't4_later',
        kind: InboxKind.message,
        author: 'a',
        subject: 'hello',
        body: 'message',
        created: DateTime.utc(2026),
        isNew: initialNew,
      ),
    ],
    after: after == null ? 'next' : null,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final action in ['read', 'unread', 'delete', 'all']) {
    test(
      'B08 rejected $action rolls back and presents failure, preserving a newer page',
      () async {
        final repo = _Repo(initialNew: action != 'unread');
        final failures = <String>[];
        final c = interactionContainer(
          repository: repo,
          prefs: await SharedPreferences.getInstance(),
          extraOverrides: [
            inboxFailureProvider.overrideWithValue(failures.add),
          ],
        );
        addTearDown(c.dispose);
        final p = inboxControllerProvider('inbox');
        await c.read(p.future);
        final ctl = c.read(p.notifier);
        final Future<void> pending = switch (action) {
          'read' => ctl.markRead('t4_msg'),
          'unread' => ctl.markUnread('t4_msg'),
          'delete' => ctl.deleteMessage('t4_msg'),
          _ => ctl.markAllRead(),
        };
        await Future<void>.delayed(Duration.zero);
        await ctl.loadMore();
        repo.requests.single.completeError(StateError('offline'));
        await pending;
        final s = c.read(p).requireValue;
        expect(s.items.map((i) => i.fullname), ['t4_msg', 't4_later']);
        expect(s.items.first.isNew, repo.initialNew);
        expect(s.hasMore, false);
        expect(failures, hasLength(1));
      },
    );
  }
  test(
    'B08 queued failures return to confirmed state and complete every future',
    () async {
      final repo = _Repo();
      final c = interactionContainer(
        repository: repo,
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      final p = inboxControllerProvider('inbox');
      await c.read(p.future);
      final ctl = c.read(p.notifier);
      final a = ctl.markRead('t4_msg');
      final b = ctl.markUnread('t4_msg');
      await Future<void>.delayed(Duration.zero);
      expect(repo.requests, hasLength(1));
      repo.requests.first.completeError(StateError('offline'));
      await a;
      await Future<void>.delayed(Duration.zero);
      expect(repo.requests, hasLength(2));
      repo.requests.last.completeError(StateError('offline'));
      await b;
      expect(c.read(p).requireValue.items.single.isNew, true);
      expect(c.read(p).requireValue.after, 'next');
    },
  );
  test(
    'B08 account transition cancels queued mutations and old rollback',
    () async {
      final repo = _Repo();
      final c = interactionContainer(
        repository: repo,
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      final p = inboxControllerProvider('inbox');
      await c.read(p.future);
      final ctl = c.read(p.notifier);
      final a = ctl.deleteMessage('t4_msg');
      final b = ctl.markRead('t4_msg');
      await Future<void>.delayed(Duration.zero);
      c.read(authSessionEpochProvider.notifier).state++;
      await c.read(p.future);
      repo.requests.single.completeError(StateError('old session'));
      await Future.wait([a, b]);
      expect(repo.requests, hasLength(1));
      expect(c.read(p).requireValue.items.single.isNew, true);
    },
  );
}
