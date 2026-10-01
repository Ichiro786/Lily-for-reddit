import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/history/interest_store.dart';
import 'support/interaction_fixture.dart';

void main() {
  for (final event in ['clear', 'dispose', 'epoch']) {
    testWidgets('B12 $event cancels old impression batches', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = interactionContainer(prefs: prefs);
      final store = c.read(impressionStoreProvider.notifier);
      store.record('old');
      switch (event) {
        case 'clear':
          store.clear();
        case 'dispose':
          c.dispose();
        case 'epoch':
          c.read(authSessionEpochProvider.notifier).state++;
          c.read(impressionStoreProvider);
      }
      await tester.pump(const Duration(seconds: 3));
      expect(prefs.getString('fy_impressions'), isNull);
      if (event != 'dispose') {
        expect(c.read(impressionStoreProvider), isEmpty);
        c.dispose();
      }
    });
  }
  testWidgets('B12 clear permits a fresh deduplicated batch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = interactionContainer(prefs: prefs);
    addTearDown(c.dispose);
    final store = c.read(impressionStoreProvider.notifier);
    store.record('old');
    store.clear();
    store.record('new');
    store.record('new');
    await tester.pump(const Duration(seconds: 3));
    expect(c.read(impressionStoreProvider), {'new': 1});
    expect(jsonDecode(prefs.getString('fy_impressions')!), {'new': 1});
  });
}
