import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/features/feed/post_card.dart';
import 'package:luli_for_reddit/features/settings/settings_controller.dart';
import 'package:luli_for_reddit/models/post.dart';

void main() {
  testWidgets('PostCard action bar does not overflow at 360px width',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final post = Post.fromData({
      'id': 'test_overflow',
      'title': 'Narrow screen overflow test post title with ample text',
      'subreddit': 'flutterdev',
      'score': 12345,
      'num_comments': 890,
      'created_utc': 1700000000,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: PostCard(post: post),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PostCard), findsOneWidget);
    // If an overflow occurs, Flutter throws a rendering exception.
    expect(tester.takeException(), isNull);
  });
}
