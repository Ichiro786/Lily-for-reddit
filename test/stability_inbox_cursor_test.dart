import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/features/inbox/inbox_controller.dart';
import 'package:luli_for_reddit/models/inbox_item.dart';
import 'package:luli_for_reddit/models/listing.dart';
import 'support/interaction_fixture.dart';

class CursorRepository extends InteractionRepository {
  @override
  Future<Listing<InboxItem>> getInbox({
    String where = 'inbox',
    String? after,
    int limit = 25,
  }) async => Listing(
    items: [
      InboxItem(
        fullname: 't4_msg',
        kind: InboxKind.message,
        author: 'a',
        subject: 'hello',
        body: 'message',
        created: DateTime.utc(2026),
        isNew: true,
      ),
    ],
    after: after == null ? 'next' : null,
  );
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> markUnread(String id) async {}
  @override
  Future<void> deleteMessage(String id) async {}
  @override
  Future<void> markAllRead() async {}
}

void main() {
  test('B07 omitted cursor survives copy; explicit null ends pagination', () {
    const state = InboxState(items: [], after: 'next');
    expect(state.copyWith(items: []).after, 'next');
    expect(state.copyWith(loadingMore: true).after, 'next');
    expect(state.copyWith(after: null).hasMore, isFalse);
  });
  for (final action in ['read', 'unread', 'delete', 'all']) {
    test('B07 $action retains cursor and pagination can finish', () async {
      SharedPreferences.setMockInitialValues({});
      final c = interactionContainer(
        repository: CursorRepository(),
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      final p = inboxControllerProvider('inbox');
      await c.read(p.future);
      final ctl = c.read(p.notifier);
      switch (action) {
        case 'read':
          await ctl.markRead('t4_msg');
        case 'unread':
          await ctl.markUnread('t4_msg');
        case 'delete':
          await ctl.deleteMessage('t4_msg');
        case 'all':
          await ctl.markAllRead();
      }
      expect(c.read(p).requireValue.after, 'next');
      await ctl.loadMore();
      expect(c.read(p).requireValue.hasMore, isFalse);
    });
  }
}
