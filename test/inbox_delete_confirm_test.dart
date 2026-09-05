import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/network/reddit_client.dart';
import 'package:luli_for_reddit/core/providers.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'package:luli_for_reddit/features/auth/auth_repository.dart';
import 'package:luli_for_reddit/features/inbox/inbox_screen.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/inbox_item.dart';
import 'package:luli_for_reddit/models/listing.dart';

class _InboxRepository extends RedditRepository {
  _InboxRepository()
      : super(RedditClient(SecureStore(), AuthRepository(SecureStore())));

  final deleted = <String>[];

  @override
  Future<Listing<InboxItem>> getInbox(
      {String where = 'inbox', String? after}) async {
    return Listing(
      items: [
        InboxItem(
          fullname: 't4_1',
          kind: InboxKind.message,
          author: 'alice',
          subject: 'Hello there',
          body: 'A private message body',
          created: DateTime.utc(2026, 1, 1),
        ),
      ],
      after: null,
    );
  }

  @override
  Future<void> deleteMessage(String fullname) async {
    deleted.add(fullname);
  }
}

void main() {
  testWidgets('swipe-to-delete asks for confirmation before deleting',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _InboxRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          redditRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: const InboxScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hello there'), findsOneWidget);

    // Swipe left (delete direction): a confirmation dialog must appear and the
    // message must survive cancelling it.
    await tester.drag(find.text('Hello there'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete message?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Hello there'), findsOneWidget);
    expect(repo.deleted, isEmpty);

    // Confirming the dialog deletes the message server-side.
    await tester.drag(find.text('Hello there'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['t4_1']);
    expect(find.text('Hello there'), findsNothing);
  });
}
