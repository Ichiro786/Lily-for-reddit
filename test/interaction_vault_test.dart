import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';

void main() {
  Future<ProviderContainer> containerFor(SharedPreferences prefs) async {
    return ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
  }

  test('rapid dwell bursts defer durability until flush', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final first = await containerFor(prefs);
    addTearDown(first.dispose);
    final vault = first.read(interactionVaultProvider.notifier);
    for (var i = 0; i < 30; i++) {
      vault.recordDwell('post-$i');
    }

    // Before flush: nothing durable — a fresh container sees no dwell state.
    final mid = await containerFor(prefs);
    addTearDown(mid.dispose);
    expect(mid.read(interactionVaultProvider).isSeen('post-29'), isFalse);

    // Flush makes the whole burst durable in one write.
    await vault.flushPersisted();
    final second = await containerFor(prefs);
    addTearDown(second.dispose);
    final state = second.read(interactionVaultProvider);
    expect(state.isSeen('post-0'), isTrue);
    expect(state.isSeen('post-29'), isTrue);
  });

  test('persists seen posts and interaction flags across fresh containers', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = await containerFor(prefs);
    addTearDown(first.dispose);

    final vault = first.read(interactionVaultProvider.notifier);
    vault.recordCommentOpened('post-1');
    vault.recordSave('post-1', true);
    await vault.flushPersisted();

    final second = await containerFor(prefs);
    addTearDown(second.dispose);
    final state = second.read(interactionVaultProvider);

    expect(state.isSeen('post-1'), isTrue);
    expect(state.interactedPosts['post-1']?.commentOpened, isTrue);
    expect(state.interactedPosts['post-1']?.saved, isTrue);
    expect(state.shouldSuppress('post-1'), isTrue);
  });

  test('evicts seen posts older than thirty days during initialization', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'interaction_vault_seen_posts': jsonEncode({
        'fresh': now,
        'old': now - const Duration(days: 31).inMilliseconds,
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = await containerFor(prefs);
    addTearDown(container.dispose);

    final state = container.read(interactionVaultProvider);
    expect(state.isSeen('fresh'), isTrue);
    expect(state.isSeen('old'), isFalse);
  });
}
