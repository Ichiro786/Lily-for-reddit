import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/feed/feed_controller.dart';
import 'package:luli_for_reddit/features/home/home_shell.dart';
import 'package:luli_for_reddit/features/inbox/inbox_controller.dart';
import 'package:luli_for_reddit/features/navigation/m3e_floating_nav_bar.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/data/reddit_repository.dart';
import 'support/interaction_fixture.dart';

class _Feed extends FeedController {
  @override
  Future<FeedState> build(String arg) async =>
      const FeedState(posts: [], sort: PostSort.hot, time: TopTime.day);
}

class _Unread extends UnreadCountController {
  @override
  int build() => 0;
}

void main() {
  testWidgets(
    'B15 HomeShell consumes label setting live while retaining destination semantics',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'checkUpdates': false,
        'notifyInboxPrompted': true,
        'navLabels': true,
      });
      final c = interactionContainer(
        prefs: await SharedPreferences.getInstance(),
        extraOverrides: [
          feedControllerProvider.overrideWith(_Feed.new),
          unreadCountProvider.overrideWith(_Unread.new),
        ],
      );
      addTearDown(c.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.dark(null),
            home: const HomeShell(),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<M3EFloatingNavBar>(find.byType(M3EFloatingNavBar))
            .isMinimized,
        false,
      );
      c.read(settingsControllerProvider.notifier).setNavLabels(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester
            .widget<M3EFloatingNavBar>(find.byType(M3EFloatingNavBar))
            .isMinimized,
        true,
      );
      final fades = find.descendant(
        of: find.byType(M3EFloatingNavBar),
        matching: find.byType(AnimatedOpacity),
      );
      expect(
        tester.widgetList<AnimatedOpacity>(fades).every((w) => w.opacity == 0),
        true,
      );
      expect(find.bySemanticsLabel(RegExp('Home')), findsWidgets);
      c.read(settingsControllerProvider.notifier).setNavLabels(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester
            .widget<M3EFloatingNavBar>(find.byType(M3EFloatingNavBar))
            .isMinimized,
        false,
      );
      semantics.dispose();
    },
  );
}
