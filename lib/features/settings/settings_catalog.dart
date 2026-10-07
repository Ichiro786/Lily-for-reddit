import 'package:flutter/material.dart';

/// Stable destinations shared by navigation and search. Preference behavior
/// remains owned by SettingsController and the existing action handlers.
enum SettingsCategory {
  appearance(
    'Appearance',
    'Theme, colors, font and layout',
    Icons.palette_outlined,
  ),
  feed('Feed', 'Home feed, post display and media', Icons.view_list_outlined),
  power(
    'Power user features',
    'Gestures, player and advanced options',
    Icons.tune_rounded,
  ),
  history(
    'History & data',
    'History, cache and offline content',
    Icons.history_rounded,
  ),
  backup(
    'Data & backup',
    'Export, import and manage app data',
    Icons.cloud_outlined,
  ),
  account(
    'Account',
    'Login, credentials and security',
    Icons.person_outline_rounded,
  ),
  about('About', 'Updates, links and legal', Icons.info_outline_rounded);

  const SettingsCategory(this.title, this.description, this.icon);
  final String title, description;
  final IconData icon;
}

enum SettingId {
  theme(SettingsCategory.appearance, 'Theme', 'light dark follow system mode'),
  amoled(
    SettingsCategory.appearance,
    'AMOLED black',
    'pure black dark surfaces',
  ),
  dynamicColor(
    SettingsCategory.appearance,
    'Dynamic color',
    'wallpaper material you palette',
  ),
  accent(
    SettingsCategory.appearance,
    'Accent color',
    'custom seed swatches palette',
  ),
  font(
    SettingsCategory.appearance,
    'Font size',
    'text scale slider preview accessibility',
  ),
  navLabels(
    SettingsCategory.appearance,
    'Bottom bar labels',
    'navigation icons text',
  ),
  sort(SettingsCategory.feed, 'Default sort', 'hot new rising top'),
  display(SettingsCategory.feed, 'Post display', 'cards mini layout'),
  nsfw(
    SettingsCategory.feed,
    'Blur NSFW media',
    'adult sensitive reveal images',
  ),
  dataSaver(
    SettingsCategory.feed,
    'Data-saver thumbnails',
    'smaller preview images bandwidth',
  ),
  hideRead(
    SettingsCategory.feed,
    'Hide read posts automatically',
    'seen opened unread',
  ),
  resume(
    SettingsCategory.feed,
    'Resume feeds where I left off',
    'restore position sort continuity',
  ),
  forYou(
    SettingsCategory.feed,
    'Manage "For You" subreddits',
    'muted show less communities',
  ),
  swipe(SettingsCategory.power, 'Swipe to vote', 'gestures right up left down'),
  autoplay(SettingsCategory.power, 'Autoplay videos', 'player media muted'),
  apiUsage(SettingsCategory.power, 'API usage', 'rate limit requests reset'),
  notifications(
    SettingsCategory.power,
    'Inbox notifications',
    'background replies messages polling permission',
  ),
  history(SettingsCategory.history, 'History', 'recently viewed local'),
  trackHistory(
    SettingsCategory.history,
    'Track history',
    'remember dim viewed posts',
  ),
  offline(
    SettingsCategory.history,
    'Offline cache',
    'last loaded content connection',
  ),
  subscriptions(
    SettingsCategory.history,
    'Cache subscriptions',
    'subreddits memory for you',
  ),
  cacheTime(
    SettingsCategory.history,
    'Subscriptions cache time',
    'duration minutes ttl',
  ),
  clearCache(
    SettingsCategory.history,
    'Clear cache',
    'storage cached responses',
  ),
  export(
    SettingsCategory.backup,
    'Export backup',
    'share JSON settings credentials accounts',
  ),
  restore(
    SettingsCategory.backup,
    'Restore backup',
    'import paste JSON data preferences',
  ),
  manageAccounts(
    SettingsCategory.account,
    'Manage accounts',
    'switch add remove sign in login',
  ),
  loginMethod(
    SettingsCategory.account,
    'Login method',
    'website session oauth API key',
  ),
  credentials(
    SettingsCategory.account,
    'Reddit API credentials',
    'client ID redirect URI keys',
  ),
  clearAll(
    SettingsCategory.account,
    'Clear all data',
    'delete wipe logout credentials tokens',
  ),
  updates(
    SettingsCategory.about,
    'Check for updates',
    'GitHub releases launch',
  ),
  checkNow(SettingsCategory.about, 'Check now', 'download new version update'),
  links(
    SettingsCategory.about,
    'Open reddit links in Lily for Reddit',
    'default app Android open with chooser',
  ),
  policy(
    SettingsCategory.about,
    'Content & conduct policy',
    'legal rules guidelines',
  );

  const SettingId(this.category, this.title, this.keywords);
  final SettingsCategory category;
  final String title, keywords;

  bool matches(String query) {
    final text = '$title $keywords ${category.title}'.toLowerCase();
    return query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .every(text.contains);
  }
}
