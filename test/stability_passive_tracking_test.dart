import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:luli_for_reddit/core/storage/interaction_vault.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/history/interest_store.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'support/interaction_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trackHistory': true,
      'swipeActions': false,
      'autoplayMedia': false,
    });
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(
    () => VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    ),
  );
  for (final scenario in [
    'disabled',
    'brief',
    'sustained',
    'disable_pending',
    'dispose',
    'inactive_tab',
  ]) {
    testWidgets('B11 passive exposure $scenario honors dwell and tracking', (
      tester,
    ) async {
      final c = interactionContainer(
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      if (scenario == 'disabled') {
        c.read(settingsControllerProvider.notifier).setTrackHistory(false);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(
              body: TickerMode(
                enabled: true,
                child: PostCard(
                  post: interactionPost().copyWith(feedReason: 'Recommended'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final d = tester.widget<VisibilityDetector>(
        find.byType(VisibilityDetector),
      );
      final card = tester.widget<PostCard>(find.byType(PostCard));
      void visible(bool value) => d.onVisibilityChanged?.call(
        VisibilityInfo(
          key: d.key!,
          size: const Size(800, 600),
          visibleBounds: value
              ? const Rect.fromLTWH(0, 0, 800, 600)
              : Rect.zero,
        ),
      );
      visible(true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.read(interactionVaultProvider).isSeen('p1'), false);
      expect(c.read(impressionStoreProvider), isEmpty);
      if (scenario == 'brief') visible(false);
      if (scenario == 'disable_pending') {
        c.read(settingsControllerProvider.notifier).setTrackHistory(false);
      }
      if (scenario == 'dispose') await tester.pumpWidget(const SizedBox());
      if (scenario == 'inactive_tab') {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              home: Scaffold(body: TickerMode(enabled: false, child: card)),
            ),
          ),
        );
      }
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 2));
      expect(
        c.read(interactionVaultProvider).isSeen('p1'),
        scenario == 'sustained',
      );
      expect(
        c.read(impressionStoreProvider)['p1'],
        scenario == 'sustained' ? 1 : null,
      );
      if (scenario == 'sustained') {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              home: Scaffold(
                body: PostCard(
                  post: interactionPost().copyWith(feedReason: 'Recommended'),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 4));
        expect(c.read(impressionStoreProvider)['p1'], 1);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
