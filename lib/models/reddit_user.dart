import 'package:freezed_annotation/freezed_annotation.dart';

part 'reddit_user.freezed.dart';

@freezed
class RedditUser with _$RedditUser {
  const RedditUser._();

  const factory RedditUser({
    required String name,
    @Default('') String displayName,
    String? iconUrl,
    String? bannerUrl,
    @Default(0) int linkKarma,
    @Default(0) int commentKarma,
    required DateTime created,
    @Default('') String description,
  }) = _RedditUser;

  factory RedditUser.fromData(Map<String, dynamic> d) {
    String? clean(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty
          ? null
          : trimmed.replaceAll('&amp;', '&');
    }

    final sub = d['subreddit'] as Map<String, dynamic>?;
    return RedditUser(
      name: d['name'] as String? ?? '',
      displayName: (sub?['title'] as String? ?? '').trim(),
      iconUrl:
          clean(d['icon_img'] as String?) ??
          clean(d['snoovatar_img'] as String?) ??
          clean(sub?['icon_img'] as String?),
      bannerUrl:
          clean(sub?['banner_background_image'] as String?) ??
          clean(sub?['banner_img'] as String?),
      linkKarma: (d['link_karma'] as num?)?.toInt() ?? 0,
      commentKarma: (d['comment_karma'] as num?)?.toInt() ?? 0,
      created: DateTime.fromMillisecondsSinceEpoch(
        ((d['created_utc'] as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      ),
      description: (sub?['public_description'] as String? ?? '').trim(),
    );
  }
}
