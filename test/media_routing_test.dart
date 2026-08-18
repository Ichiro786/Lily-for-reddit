import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/media_aspect_ratio.dart';
import 'package:luli_for_reddit/core/url_launcher_helper.dart';

void main() {
  group('isYouTubeUrl', () {
    test('accepts supported YouTube hosts and Shorts paths', () {
      expect(isYouTubeUrl('https://youtube.com/watch?v=abc'), isTrue);
      expect(isYouTubeUrl('https://www.youtube.com/shorts/abc'), isTrue);
      expect(isYouTubeUrl('https://m.youtube.com/watch?v=abc'), isTrue);
      expect(isYouTubeUrl('https://youtu.be/abc'), isTrue);
    });

    test('rejects lookalike and unsupported URLs', () {
      expect(isYouTubeUrl('https://notyoutube.com/watch?v=abc'), isFalse);
      expect(isYouTubeUrl('ftp://youtube.com/video'), isFalse);
      expect(isYouTubeUrl('not a URL'), isFalse);
    });
  });

  group('boundedMediaAspectRatio', () {
    test('uses metadata while clamping extreme dimensions', () {
      expect(
        boundedMediaAspectRatio(width: 1920, height: 1080),
        closeTo(1.777777, 0.000001),
      );
      expect(boundedMediaAspectRatio(width: 100, height: 1000), 0.4);
      expect(boundedMediaAspectRatio(width: 4000, height: 1000), 1.91);
      expect(boundedMediaAspectRatio(), closeTo(16 / 9, 0.000001));
    });
  });
}
