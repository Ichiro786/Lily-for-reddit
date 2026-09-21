import 'package:freezed_annotation/freezed_annotation.dart';

part 'subreddit.freezed.dart';

@freezed
class Subreddit with _$Subreddit {
  const Subreddit._();

  const factory Subreddit({
    required String name, // display_name
    required String namePrefixed, // r/name
    required String title,
    required String description,
    required int subscribers,
    int? accountsActive,
    String? iconUrl,
    String? bannerUrl,
    @Default(false) bool over18,
    @Default(false) bool userHasFavorited,
    bool? userIsSubscriber,
  }) = _Subreddit;

  Map<String, dynamic> toJson() => {
        'display_name': name,
        'display_name_prefixed': namePrefixed,
        'title': title,
        'public_description': description,
        'subscribers': subscribers,
        if (accountsActive != null) 'accounts_active': accountsActive,
        if (iconUrl != null) 'community_icon': iconUrl,
        if (bannerUrl != null) 'banner_background_image': bannerUrl,
        'over18': over18,
        'user_has_favorited': userHasFavorited,
        if (userIsSubscriber != null) 'user_is_subscriber': userIsSubscriber,
      };

  factory Subreddit.fromData(Map<String, dynamic> d) {
    String? clean(String? s) =>
        (s == null || s.isEmpty) ? null : s.replaceAll('&amp;', '&');
    final icon = clean(d['community_icon'] as String?) ??
        clean(d['icon_img'] as String?);
    final banner = clean(d['banner_background_image'] as String?) ??
        clean(d['banner_img'] as String?);
    final accountsActive = (d['accounts_active'] as num?)?.toInt() ??
        (d['active_user_count'] as num?)?.toInt();
    return Subreddit(
      name: d['display_name'] as String? ?? d['name'] as String? ?? '',
      namePrefixed: d['display_name_prefixed'] as String? ??
          'r/${d['display_name'] ?? d['name'] ?? ''}',
      title: (d['title'] as String? ?? '').trim(),
      description: ((d['public_description'] ?? d['description']) as String? ?? '').trim(),
      subscribers: (d['subscribers'] as num?)?.toInt() ?? 0,
      accountsActive: accountsActive,
      iconUrl: icon,
      bannerUrl: banner,
      over18: d['over18'] == true,
      userHasFavorited: d['user_has_favorited'] == true,
      userIsSubscriber: d['user_is_subscriber'] as bool?,
    );
  }
}
