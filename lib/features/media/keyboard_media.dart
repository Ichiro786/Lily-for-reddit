import 'package:flutter/services.dart';
import 'attachment.dart';

const keyboardImageMimeTypes = [
  'image/gif',
  'image/webp',
  'image/png',
  'image/jpeg',
];
const maxKeyboardImageBytes = 20 * 1024 * 1024;

/// Flutter copies IME content before its temporary URI grant is released.
/// Read a content URI through Android only when the keyboard supplied no bytes.
Future<MediaAttachment> readKeyboardAttachment(
  KeyboardInsertedContent content,
) async {
  var bytes = content.data;
  var mime = content.mimeType;
  if (!keyboardImageMimeTypes.contains(mime)) {
    throw UnsupportedError('This keyboard attachment format is unavailable.');
  }
  if (bytes == null || bytes.isEmpty) {
    if (Uri.tryParse(content.uri)?.scheme != 'content') {
      throw UnsupportedError(
        'Choose the GIF or sticker again, or attach an image.',
      );
    }
    final result = await const MethodChannel('lily/media_clipboard')
        .invokeMapMethod<String, dynamic>('readKeyboardImage', {
          'uri': content.uri,
          'mimeType': mime,
        });
    bytes = result?['bytes'];
    mime = result?['mimeType'] as String? ?? mime;
  }
  if (bytes == null ||
      bytes.isEmpty ||
      !keyboardImageMimeTypes.contains(mime)) {
    throw UnsupportedError(
      'Could not read that GIF or sticker. Please select it again.',
    );
  }
  if (bytes.length > maxKeyboardImageBytes) {
    throw UnsupportedError('Choose a GIF or sticker smaller than 20 MB.');
  }
  final extension = switch (mime) {
    'image/jpeg' => 'jpg',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    _ => 'png',
  };
  return MediaAttachment(
    bytes: bytes,
    filename: 'keyboard.$extension',
    mimeType: mime,
    isVideo: false,
  );
}

String keyboardAttachmentError(Object error) => switch (error) {
  UnsupportedError e => e.message ?? 'Could not attach that GIF or sticker.',
  PlatformException e when e.code == 'clipboard_too_large' =>
    'Choose a GIF or sticker smaller than 20 MB.',
  _ =>
    'Could not attach that GIF or sticker. Please select it again or attach an image.',
};
