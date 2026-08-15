import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/features/post/comment_media_helper.dart';

void main() {
  group('isCommentMediaUrl', () {
    test('accepts supported image extensions', () {
      for (final extension in ['gif', 'gifv', 'png', 'jpg', 'jpeg', 'webp']) {
        expect(
          isCommentMediaUrl('https://example.com/comment.$extension?x=1'),
          isTrue,
          reason: extension,
        );
      }
    });

    test('accepts Reddit image and preview hosts without extensions', () {
      expect(isCommentMediaUrl('https://i.redd.it/abc123'), isTrue);
      expect(
        isCommentMediaUrl('https://preview.redd.it/abc123?width=640'),
        isTrue,
      );
    });

    test('rejects unsupported URLs', () {
      expect(isCommentMediaUrl('https://example.com/video.mp4'), isFalse);
      expect(isCommentMediaUrl('not a URL'), isFalse);
      expect(isCommentMediaUrl('ftp://example.com/photo.jpg'), isFalse);
    });
  });

  test('classifies GIF and normalizes GIFV URLs', () {
    expect(isCommentGifUrl('https://example.com/reaction.GIF'), isTrue);
    expect(isCommentGifUrl('https://example.com/reaction.gifv'), isTrue);
    expect(
      normalizedCommentMediaUrl('https://example.com/reaction.gifv?source=reddit'),
      'https://example.com/reaction.gif?source=reddit',
    );
  });

  test('extracts unique media URLs from Markdown and plain text', () {
    final media = extractCommentMedia('''
Look at this:
![reaction](https://i.redd.it/abc123.png)
https://i.redd.it/abc123.png
https://preview.redd.it/xyz789?width=640
''');

    expect(media.map((item) => item.url).toList(), [
      'https://i.redd.it/abc123.png',
      'https://preview.redd.it/xyz789?width=640',
    ]);
    expect(media.first.isGif, isFalse);
  });

  test('removes rendered media URLs while preserving normal text', () {
    expect(
      commentTextWithoutMedia(
        'Keep this sentence. https://i.redd.it/abc123.jpg\nAnd this link: https://example.com/article',
      ),
      'Keep this sentence. \nAnd this link: https://example.com/article',
    );
    expect(
      commentTextWithoutMedia(
        '![image](https://preview.redd.it/abc123?width=640)',
      ),
      isEmpty,
    );
  });
}
