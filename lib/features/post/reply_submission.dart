import '../../core/network/catbox.dart';
import '../../data/reddit_repository.dart';
import '../../models/comment.dart';
import '../media/attachment.dart';

/// Shared dispatch keeps inline comments and reply sheets consistent.
Future<Comment> submitMediaReply({
  required RedditRepository repository,
  required String parentFullname,
  required String text,
  required int depth,
  required MediaAttachment? media,
  required void Function() requireSession,
  Future<String> Function(MediaAttachment)? uploadVideo,
}) async {
  requireSession();
  final Comment result;
  if (media == null) {
    result = await repository.reply(
      parentFullname: parentFullname,
      text: text,
      depth: depth,
    );
  } else if (media.isVideo) {
    final url =
        await (uploadVideo?.call(media) ??
            uploadToCatbox(bytes: media.bytes, filename: media.filename));
    requireSession();
    result = await repository.reply(
      parentFullname: parentFullname,
      text: text.isEmpty ? url : '$text\n\n$url',
      depth: depth,
    );
  } else {
    result = await repository.replyWithImage(
      parentFullname: parentFullname,
      text: text,
      bytes: media.bytes,
      filename: media.filename,
      mimeType: media.mimeType,
      depth: depth,
    );
  }
  requireSession();
  return result;
}
