import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/features/compose/compose_post_screen.dart';
import 'package:luli_for_reddit/models/flair.dart';
import 'support/interaction_fixture.dart';

class _Picker extends Fake implements ImagePicker {
  final image = Completer<XFile?>();
  final gallery = Completer<List<XFile>>();
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #pickMultiImage) return gallery.future;
    if (invocation.memberName == #pickImage ||
        invocation.memberName == #pickVideo) {
      return image.future;
    }
    return super.noSuchMethod(invocation);
  }
}

class _Repo extends InteractionRepository {
  final flairs = <String, Completer<List<Flair>>>{};
  @override
  Future<List<Flair>> getLinkFlairs(String sr) =>
      flairs.putIfAbsent(sr, Completer<List<Flair>>.new).future;
}

void main() {
  for (final type in ['image', 'gallery', 'video', 'gif', 'error']) {
    testWidgets('B14 $type picker completing after route removal is harmless', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final picker = _Picker();
      final gif = Completer<String?>();
      final c = interactionContainer(
        prefs: await SharedPreferences.getInstance(),
        extraOverrides: [
          postMediaPickerProvider.overrideWithValue(picker),
          postGifPickerProvider.overrideWithValue((_, __) => gif.future),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.dark(null),
            home: const ComposePostScreen(),
          ),
        ),
      );
      if (type != 'gif') {
        final icon = switch (type) {
          'gallery' => Icons.collections_rounded,
          'video' => Icons.videocam_rounded,
          _ => Icons.image_rounded,
        };
        await tester.ensureVisible(find.byIcon(icon));
        await tester.tap(find.byIcon(icon));
        await tester.pump();
        final label = switch (type) {
          'gallery' => 'Tap to choose images',
          'video' => 'Tap to choose a video',
          _ => 'Tap to choose an image',
        };
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
      } else {
        await tester.ensureVisible(find.text('GIF'));
        await tester.tap(find.text('GIF'));
        await tester.pump();
      }
      await tester.pumpWidget(const SizedBox());
      switch (type) {
        case 'gallery':
          picker.gallery.complete([XFile('/tmp/photo.jpg')]);
        case 'gif':
          gif.complete('https://example.com/a.gif');
        case 'error':
          picker.image.completeError(StateError('picker failed'));
        default:
          picker.image.complete(XFile('/tmp/photo.jpg'));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('B14 flair response belongs to current subreddit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _Repo();
    final c = interactionContainer(
      prefs: await SharedPreferences.getInstance(),
      repository: repo,
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.dark(null),
          home: const ComposePostScreen(initialSubreddit: 'first'),
        ),
      ),
    );
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'second');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    repo.flairs['second']!.complete([
      const Flair(id: 'new', text: 'New flair'),
    ]);
    await tester.pump();
    repo.flairs['first']!.complete([const Flair(id: 'old', text: 'Old flair')]);
    await tester.pump();
    expect(find.text('New flair'), findsOneWidget);
    expect(find.text('Old flair'), findsNothing);
  });
}
