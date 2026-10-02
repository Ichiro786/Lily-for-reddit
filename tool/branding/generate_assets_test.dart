// Rebuild vector and raster platform assets from one reference geometry:
// flutter test tool/branding/generate_assets_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

const ring = 'M80.554,41.618 A29.3,29.3 0 1,1 64.021,26.467';
const letter =
    'M47,36 C43.7,36 41,38.7 41,42 L41,63 C41,68 44,71 49,71 L62,71 C66,71 68.5,68 68.5,64 C68.5,60 66,57 62,57 L54,57 L54,42 C54,38.7 51.3,36 47,36 Z';

String vector({bool monochrome = false, bool tile = false}) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt" android:width="108dp"
    android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
${tile ? '<path android:fillColor="#26252D" android:pathData="M24,12 H84 Q96,12 96,24 V84 Q96,96 84,96 H24 Q12,96 12,84 V24 Q12,12 24,12 Z" />' : ''}
    <path android:pathData="$ring" android:fillColor="@android:color/transparent"
        android:strokeWidth="4.2" android:strokeLineCap="round" ${monochrome ? 'android:strokeColor="#FFFFFFFF"' : ''}>
${monochrome ? '' : gradient('strokeColor')}
    </path>
    <path android:pathData="$letter" ${monochrome ? 'android:fillColor="#FFFFFFFF"' : ''}>
${monochrome ? '' : gradient('fillColor')}
    </path>
    <path android:pathData="M79.3,35.5 A6.8,6.8 0 1,1 65.7,35.5 A6.8,6.8 0 1,1 79.3,35.5 Z"
        ${monochrome ? 'android:fillColor="#FFFFFFFF"' : ''}>
${monochrome ? '' : gradient('fillColor')}
    </path>
</vector>
''';

String gradient(String attribute) =>
    '''        <aapt:attr name="android:$attribute">
            <gradient android:startX="30" android:startY="22" android:endX="78" android:endY="88" android:type="linear"
                android:startColor="#B2B0C4" android:endColor="#757086" />
        </aapt:attr>''';

Future<void> write(String path, String value) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(value);
}

Future<void> png(
  String path,
  int size, {
  bool backgroundOnly = false,
  bool splash = false,
  bool tinted = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (backgroundOnly) {
    canvas.drawColor(const ui.Color(0xFF000000), ui.BlendMode.src);
  } else {
    canvas.scale(size / 84);
    canvas.translate(-12, -12);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(12, 12, 84, 84),
        ui.Radius.circular(splash ? 18 : 0),
      ),
      ui.Paint()..color = const ui.Color(0xFF26252D),
    );
    final paint = ui.Paint()
      ..shader = tinted
          ? null
          : ui.Gradient.linear(
              const ui.Offset(30, 22),
              const ui.Offset(78, 88),
              [const ui.Color(0xFFB2B0C4), const ui.Color(0xFF757086)],
            )
      ..color = const ui.Color(0xFFFFFFFF);
    // The arc takes the long route around the left and bottom of the orbit.
    final arc = ui.Path()
      ..moveTo(80.554, 41.618)
      ..arcToPoint(
        const ui.Offset(64.021, 26.467),
        radius: const ui.Radius.circular(29.3),
        largeArc: true,
        clockwise: true,
      );
    canvas.drawPath(
      arc,
      paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = ui.StrokeCap.round,
    );
    paint.style = ui.PaintingStyle.fill;
    final l = ui.Path()
      ..moveTo(47, 36)
      ..cubicTo(43.7, 36, 41, 38.7, 41, 42)
      ..lineTo(41, 63)
      ..cubicTo(41, 68, 44, 71, 49, 71)
      ..lineTo(62, 71)
      ..cubicTo(66, 71, 68.5, 68, 68.5, 64)
      ..cubicTo(68.5, 60, 66, 57, 62, 57)
      ..lineTo(54, 57)
      ..lineTo(54, 42)
      ..cubicTo(54, 38.7, 51.3, 36, 47, 36)
      ..close();
    canvas.drawPath(l, paint);
    canvas.drawCircle(const ui.Offset(72.5, 35.5), 6.8, paint);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  test('export Lily reference branding', () async {
    await write(
      'assets/branding/lily.svg',
      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="12 12 84 84">
<defs><linearGradient id="ink" x1="30" y1="22" x2="78" y2="88" gradientUnits="userSpaceOnUse"><stop stop-color="#B2B0C4"/><stop offset="1" stop-color="#757086"/></linearGradient></defs>
<rect x="12" y="12" width="84" height="84" rx="18" fill="#26252D"/>
<path d="$ring" fill="none" stroke="url(#ink)" stroke-width="4.2" stroke-linecap="round"/>
<path d="$letter" fill="url(#ink)"/><circle cx="72.5" cy="35.5" r="6.8" fill="url(#ink)"/>
</svg>\n''',
    );
    await write(
      'android/app/src/main/res/drawable/lily_icon_foreground.xml',
      vector(),
    );
    await write(
      'android/app/src/main/res/drawable/lily_icon_monochrome.xml',
      vector(monochrome: true),
    );
    await write(
      'android/app/src/main/res/drawable/android12splash.xml',
      vector(tile: true),
    );
    await write(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/lily_launcher_background"/>
    <foreground android:drawable="@drawable/lily_icon_foreground"/>
    <monochrome android:drawable="@drawable/lily_icon_monochrome"/>
</adaptive-icon>\n''',
    );
    await write(
      'android/app/src/main/res/values/colors.xml',
      '''<?xml version="1.0" encoding="utf-8"?>
<resources><color name="lily_launcher_background">#26252D</color></resources>\n''',
    );
    for (final (density, scale) in [
      ('mdpi', 1.0),
      ('hdpi', 1.5),
      ('xhdpi', 2.0),
      ('xxhdpi', 3.0),
      ('xxxhdpi', 4.0),
    ]) {
      final directory = 'android/app/src/main/res/mipmap-$density';
      await png('$directory/ic_launcher.png', (48 * scale).round());
      for (final layer in ['foreground', 'background', 'monochrome']) {
        final old = File('$directory/ic_launcher_$layer.png');
        if (await old.exists()) await old.delete();
      }
    }
    for (final entity in Directory(
      'android/app/src/main/res',
    ).listSync(recursive: true).whereType<File>()) {
      if (entity.path.endsWith('/android12splash.png')) await entity.delete();
    }
    await png('assets/splash/logo.png', 1024, splash: true);
    await png('fastlane/metadata/android/en-US/images/icon.png', 512);
    for (final mode in ['light', 'dark', 'tinted']) {
      await png(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/icon_$mode.png',
        1024,
        tinted: mode == 'tinted',
      );
    }
    for (final scale in [1, 2, 3]) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      for (final name in ['LaunchImage', 'LaunchImageDark']) {
        await png(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/$name$suffix.png',
          math.min(192 * scale, 1024),
          splash: true,
        );
      }
    }
    for (final name in ['background', 'darkbackground']) {
      await png(
        'ios/Runner/Assets.xcassets/LaunchBackground.imageset/$name.png',
        1,
        backgroundOnly: true,
      );
    }
    for (final directory in ['drawable-v21', 'drawable-night-v21']) {
      await png(
        'android/app/src/main/res/$directory/background.png',
        1,
        backgroundOnly: true,
      );
    }
  });
}
