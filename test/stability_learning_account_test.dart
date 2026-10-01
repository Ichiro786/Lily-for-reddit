import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/history/interest_store.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';

class _Auth extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession(username: 'Alice');
  void select(String user) => state = AsyncData(AuthSession(username: user));
}

void main() {
  testWidgets(
    'Final audit: pending learning writes remain scoped when switching accounts',
    (tester) async {
      SharedPreferences.setMockInitialValues({'trackHistory': true});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(_Auth.new),
        ],
      );
      addTearDown(c.dispose);
      await c.read(authControllerProvider.future);
      c.read(interactionVaultProvider.notifier).recordDwell('alice-post');
      c.read(interestStoreProvider.notifier).bump('flutter', 2);
      c.read(impressionStoreProvider.notifier).record('alice-post');
      (c.read(authControllerProvider.notifier) as _Auth).select('Bob');
      expect(c.read(interactionVaultProvider).isSeen('alice-post'), false);
      expect(c.read(interestStoreProvider), isEmpty);
      expect(c.read(impressionStoreProvider), isEmpty);
      c.read(interactionVaultProvider.notifier).recordDwell('bob-post');
      c.read(impressionStoreProvider.notifier).record('bob-post');
      await tester.pump(const Duration(seconds: 3));
      expect(
        prefs.getString('interaction_vault_seen_posts_alice'),
        contains('alice-post'),
      );
      expect(
        prefs.getString('interaction_vault_seen_posts_bob'),
        contains('bob-post'),
      );
      expect(prefs.getString('fy_impressions_bob'), contains('bob-post'));
      expect(
        prefs.getString('fy_impressions_bob'),
        isNot(contains('alice-post')),
      );
      (c.read(authControllerProvider.notifier) as _Auth).select('Alice');
      expect(c.read(interactionVaultProvider).isSeen('alice-post'), true);
      expect(c.read(interactionVaultProvider).isSeen('bob-post'), false);
      expect(c.read(interestStoreProvider)['flutter'], closeTo(2, 0.01));
      await tester.pump(const Duration(milliseconds: 1));
      c.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
