import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/rate_limit.dart';
import '../../core/providers.dart';
import '../../core/theme/shape_tokens.dart';
import '../../data/reddit_repository.dart';
import '../auth/auth_controller.dart';
import '../feed/feed_controller.dart';
import '../inbox/inbox_controller.dart';
import '../multireddit/multireddit_providers.dart';
import '../notifications/inbox_poller.dart';
import '../notifications/notification_service.dart';
import '../updates/update_checker.dart';
import 'backup_service.dart';
import 'settings_controller.dart';
import 'settings_panels.dart';

List<Color> _accentSwatches(ColorScheme colorScheme) => [
      colorScheme.primary,
      colorScheme.error,
      colorScheme.tertiary,
      colorScheme.secondary,
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
      colorScheme.inversePrimary,
    ];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const SettingsList(),
      );
}

/// The settings list — reusable both as the full Settings screen and embedded
/// (e.g. inside the Account tab). Pass [embedded] when nesting in a scroll view.
class SettingsList extends ConsumerStatefulWidget {
  const SettingsList({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends ConsumerState<SettingsList> {
  String _query = '';

  /// Searches a tile's title/subtitle text. Non-tile widgets (dividers,
  /// sliders, section headers) are dropped from search results.
  bool _matches(Widget w, String q) {
    String t(Object? x) => x is Text ? (x.data ?? '') : '';
    String text;
    if (w is ListTile) {
      text = '${t(w.title)} ${t(w.subtitle)}';
    } else if (w is SwitchListTile) {
      text = '${t(w.title)} ${t(w.subtitle)}';
    } else {
      return false;
    }
    return text.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final all = <Widget>[
          _section(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text('Theme'),
            subtitle: Text(switch (s.themeMode) {
              ThemeMode.system => 'Follow system',
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
            }),
            onTap: () => _pickTheme(context, ctrl, s.themeMode),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_rounded),
            title: const Text('AMOLED black'),
            subtitle: const Text('Pure black surfaces in dark mode'),
            value: s.amoled,
            onChanged: ctrl.setAmoled,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.palette_rounded),
            title: const Text('Dynamic color'),
            subtitle: const Text('Use colors from your wallpaper'),
            value: s.useDynamicColor,
            onChanged: ctrl.setUseDynamicColor,
          ),
          Opacity(
            opacity: s.useDynamicColor ? 0.4 : 1,
            child: IgnorePointer(
              ignoring: s.useDynamicColor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Accent color',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final c in _accentSwatches(cs))
                          Semantics(
                            button: true,
                            label: 'Theme color ${c.toARGB32()}',
                            child: GestureDetector(
                              key: ValueKey<String>('theme-swatch-${c.toARGB32()}'),
                              onTap: () => ctrl.setSeedColor(c.toARGB32()),
                              child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: s.seedColor == c.toARGB32()
                                      ? Theme.of(context).colorScheme.onSurface
                                      : cs.surface.withValues(alpha: 0),
                                  width: 3,
                                ),
                              ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: s.seedColor == c.toARGB32()
                                      ? Icon(
                                          Icons.check_rounded,
                                          key: const ValueKey<String>('selected'),
                                          color: cs.onPrimary,
                                        )
                                      : const SizedBox.shrink(
                                          key: ValueKey<String>('unselected'),
                                        ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.format_size_rounded),
            title: const Text('Font size'),
            subtitle: Text('${(s.textScale * 100).round()}% of normal'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                const Text('A', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: s.textScale,
                    min: 0.8,
                    max: 1.4,
                    divisions: 12,
                    label: '${(s.textScale * 100).round()}%',
                    onChanged: ctrl.setTextScale,
                  ),
                ),
                const Text('A', style: TextStyle(fontSize: 22)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'The quick brown fox jumps over the lazy dog.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.view_headline_rounded),
            title: const Text('Top bar'),
            subtitle: Text(s.topBarMode.label),
            onTap: () => _pickTopBar(context, ctrl, s.topBarMode),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.label_outline_rounded),
            title: const Text('Bottom bar labels'),
            subtitle: const Text('Show text labels under the navigation icons'),
            value: s.navLabels,
            onChanged: ctrl.setNavLabels,
          ),
          const Divider(),
          _section(context, 'Feed'),
          ListTile(
            leading: const Icon(Icons.sort_rounded),
            title: const Text('Default sort'),
            subtitle: Text(s.defaultSort.label),
            onTap: () => _pickSort(context, ctrl, s.defaultSort),
          ),
          ListTile(
            leading: Icon(s.postDisplay.icon),
            title: const Text('Post display'),
            subtitle: Text(s.postDisplay.label),
            onTap: () => _pickDisplay(context, ctrl, s.postDisplay),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.blur_on_rounded),
            title: const Text('Blur NSFW media'),
            subtitle: const Text('Tap to reveal blurred images'),
            value: s.blurNsfw,
            onChanged: ctrl.setBlurNsfw,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image_outlined),
            title: const Text('Data-saver thumbnails'),
            subtitle: const Text(
                'Load smaller preview images in feeds (faster, less data)'),
            value: s.midResThumbnails,
            onChanged: ctrl.setMidResThumbnails,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome_rounded),
            title: const Text('"For You" feed (Beta)'),
            subtitle: const Text(
                'Personalized frontpage built on-device. Reddit\'s own '
                'recommendations aren\'t available to third-party apps.'),
            value: s.forYouFeed,
            onChanged: ctrl.setForYouFeed,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mark_email_read_outlined),
            title: const Text('Auto-hide read items in "For You"'),
            subtitle: const Text('Hide posts you\'ve marked/opened as read'),
            value: s.autoHideReadForYou,
            onChanged: ctrl.setAutoHideReadForYou,
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Manage "For You" subreddits'),
            subtitle: const Text('Review and undo muted / show-less subreddits'),
            onTap: () => context.push('/manage_for_you'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.swipe_rounded),
            title: const Text('Swipe to vote'),
            subtitle: const Text('Swipe posts/comments right=up, left=down'),
            value: s.swipeActions,
            onChanged: ctrl.setSwipeActions,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline_rounded),
            title: const Text('Autoplay videos'),
            subtitle: const Text('Play videos muted as you scroll the feed'),
            value: s.autoplayMedia,
            onChanged: ctrl.setAutoplayMedia,
          ),
          const Divider(),
          _section(context, 'Power-user features'),
          SwitchListTile(
            secondary: const Icon(Icons.speed_rounded),
            title: const Text('Show API usage instead of search'),
            subtitle: const Text(
                'Replace the search bar on the Posts screen with your live '
                'Reddit API rate-limit usage'),
            value: s.showApiUsage,
            onChanged: ctrl.setShowApiUsage,
          ),
          _RateLimitTile(),
          const Divider(),
          _section(context, 'Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Inbox notifications'),
            subtitle: const Text(
                'Check for replies & messages in the background (~every 15 min) '
                'and notify you. No Firebase — polling only.'),
            value: s.notifyInbox,
            onChanged: (v) => _toggleInboxNotifications(context, ref, v),
          ),
          const Divider(),
          _section(context, 'History & data'),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('History'),
            subtitle: const Text('Recently viewed (stored on this device)'),
            onTap: () => context.push('/history'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Track history'),
            subtitle: const Text('Remember and dim viewed posts (local only)'),
            value: s.trackHistory,
            onChanged: ctrl.setTrackHistory,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_off_rounded),
            title: const Text('Offline cache'),
            subtitle:
                const Text('Show the last loaded content when offline'),
            value: s.offlineCache,
            onChanged: ctrl.setOfflineCache,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dns_outlined),
            title: const Text('Cache subscriptions'),
            subtitle: const Text(
                'Keep your subreddit list in memory to speed up "For You"'),
            value: s.subsCacheEnabled,
            onChanged: ctrl.setSubsCacheEnabled,
          ),
          ListTile(
            enabled: s.subsCacheEnabled,
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Subscriptions cache time'),
            subtitle: Text('${s.subsCacheMinutes} minutes'),
            onTap: () => _pickCacheMinutes(context, ctrl, s.subsCacheMinutes),
          ),
          ListTile(
            leading: const Icon(Icons.cached_rounded),
            title: const Text('Clear cache'),
            onTap: () async {
              await ref.read(redditClientProvider).clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared')));
              }
            },
          ),
          const Divider(),
          _section(context, 'Data & Backup'),
          ListTile(
            leading: const Icon(Icons.backup_rounded),
            title: const Text('Export backup'),
            subtitle: const Text(
                'Share a JSON backup of settings, credentials, and accounts'),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore_rounded),
            title: const Text('Restore backup'),
            subtitle: const Text('Paste a previously exported JSON backup'),
            onTap: () => _restoreBackup(context, ref),
          ),
          const Divider(),
          _section(context, 'About'),
          SwitchListTile(
            secondary: const Icon(Icons.system_update_rounded),
            title: const Text('Check for updates'),
            subtitle: const Text('Check GitHub releases on launch'),
            value: s.checkUpdates,
            onChanged: ctrl.setCheckUpdates,
          ),
          ListTile(
            leading: const Icon(Icons.update_rounded),
            title: const Text('Check now'),
            onTap: () => _checkUpdatesNow(context, ref),
          ),
          const ListTile(
            leading: Icon(Icons.link_rounded),
            title: Text('Open reddit links in Lily for Reddit'),
            subtitle: Text(
                'Already supported via the Android "open with" chooser. To make '
                'Lily for Reddit the verified default, enable it under system app settings '
                '› Open by default.'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: const Text('Content & conduct policy'),
            onTap: () => context.push('/policy'),
          ),
          const Divider(),
          _section(context, 'Account'),
          ListTile(
            leading: Icon(ref.watch(authModeProvider).valueOrNull == 'web'
                ? Icons.public_rounded
                : Icons.api_rounded),
            title: const Text('Login method'),
            subtitle: Text(ref.watch(authModeProvider).valueOrNull == 'web'
                ? 'Website session (no API key) — unofficial'
                : 'Reddit API key (recommended)'),
            onTap: () => _showLoginMethodInfo(
                context, ref.read(authModeProvider).valueOrNull == 'web'),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key_rounded),
            title: const Text('Reddit API credentials'),
            subtitle: const Text('Re-enter your Client ID / Redirect URI'),
            onTap: () => _reenterCredentials(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error),
            title: Text('Clear all data',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text('Wipes credentials, tokens and login'),
            onTap: () => _clearAll(context, ref),
          ),
          const SizedBox(height: 24),
    ];

    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _groupedSettings(all)
        : all.where((w) => _matches(w, q)).toList();
    return ListView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search settings',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: ShapeTokens.large,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        ...shown,
        if (q.isNotEmpty && shown.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('No settings found')),
          ),
      ],
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(backupServiceProvider).exportBackup();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup exported successfully')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup export failed: $error')),
      );
    }
  }

  Future<String?> _requestBackupJson(BuildContext context) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Paste backup JSON'),
          content: SizedBox(
            width: 560,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 8,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: '{ "schema_version": 1, ... }',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final json = await _requestBackupJson(context);
    if (!context.mounted || json == null || json.trim().isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore settings and API keys?'),
        content: const Text(
            'This will overwrite current preferences, credentials, and saved '
            'account configurations on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;

    final result = await ref.read(backupServiceProvider).importBackup(json);
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    ref.invalidate(settingsControllerProvider);
    ref.invalidate(authControllerProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(authModeProvider);
    ref.read(redditRepositoryProvider).clearSubsCache();
    ref.invalidate(feedControllerProvider);
    ref.invalidate(inboxControllerProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(myMultiredditsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _checkUpdatesNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Checking…')));
    final checker = UpdateChecker();
    final currentVersion = await checker.currentVersion();
    final info = await checker.check(installedVersion: currentVersion);
    if (!context.mounted) return;
    if (info == null) {
      messenger.showSnackBar(SnackBar(
          content: Text(
              "You're on the latest version ($currentVersion).")));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update available — v${info.version}'),
        content: const Text('A newer version is available on GitHub.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(info.apkUrl ?? info.url),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleInboxNotifications(
      BuildContext context, WidgetRef ref, bool enable) async {
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (!enable) {
      ctrl.setNotifyInbox(false);
      await cancelInboxPolling();
      return;
    }
    final granted = await NotificationService.instance.requestPermission();
    if (!granted) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Notification permission denied. Enable it in system '
              'settings to get inbox alerts.')));
      return;
    }
    ctrl.setNotifyInbox(true);
    // Prime the "seen" set with current unread so turning this on doesn't fire a
    // notification for every pre-existing item, then start the periodic poll.
    await pollInbox(notify: false);
    await registerInboxPolling();
    messenger.showSnackBar(const SnackBar(
        content: Text('Inbox notifications on. Reddit is checked about every '
            '15 minutes.')));
  }

  List<Widget> _groupedSettings(List<Widget> all) {
    final panels = <Widget>[];
    String? title;
    final items = <Widget>[];

    void flush() {
      final currentTitle = title;
      if (currentTitle == null || items.isEmpty) return;
      panels.add(
                  M3ESettingsPanel(

          title: currentTitle,
          children: List<Widget>.of(items),
        ),
      );
      items.clear();
    }

    for (final widget in all) {
      if (widget is M3ESettingsSectionHeader) {
        flush();
        title = widget.title;
      } else if (widget is! Divider) {
        items.add(widget);
      }
    }
    flush();
    return panels;
  }

  Widget _section(BuildContext context, String title) =>
      M3ESettingsSectionHeader(title: title);

  void _pickTheme(
      BuildContext context, SettingsController ctrl, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) ctrl.setThemeMode(v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  value: m,
                  title: Text(switch (m) {
                    ThemeMode.system => 'Follow system',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickSort(
      BuildContext context, SettingsController ctrl, PostSort current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<PostSort>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) ctrl.setDefaultSort(v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final sort in PostSort.values)
                RadioListTile<PostSort>(
                  value: sort,
                  title: Text(sort.label),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickCacheMinutes(
      BuildContext context, SettingsController ctrl, int current) {
    const options = [5, 10, 30, 60];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<int>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) ctrl.setSubsCacheMinutes(v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in options)
                RadioListTile<int>(value: m, title: Text('$m minutes')),
            ],
          ),
        ),
      ),
    );
  }

  void _pickDisplay(
      BuildContext context, SettingsController ctrl, PostDisplay current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<PostDisplay>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) ctrl.setPostDisplay(v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in PostDisplay.values)
                RadioListTile<PostDisplay>(
                  value: d,
                  secondary: Icon(d.icon),
                  title: Text(d.label),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickTopBar(
      BuildContext context, SettingsController ctrl, TopBarMode current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<TopBarMode>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) ctrl.setTopBarMode(v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in TopBarMode.values)
                RadioListTile<TopBarMode>(
                  value: m,
                  title: Text(m.label),
                  subtitle: Text(m.description),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginMethodInfo(BuildContext context, bool isWeb) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login method'),
        content: Text(
          isWeb
              ? 'You\'re signed in with a website session (no API key).\n\n'
                  'This isn\'t Reddit\'s official API. It can stop working if '
                  'Reddit changes their site, and Reddit may consider it against '
                  'their usage policy and restrict or ban accounts that use it. '
                  'Use at your own risk.\n\n'
                  'To switch to the official API key method, log out and choose '
                  '"Connect Reddit account" on the login screen.'
              : 'You\'re signed in with Reddit\'s official API using your own '
                  'API key — the recommended, supported method.\n\n'
                  'If you can no longer create an API key, you can log out and '
                  'choose "Sign in via website" on the login screen, but that '
                  'unofficial method carries account risk.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _reenterCredentials(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-enter credentials?'),
        content: const Text(
            'You will be logged out and returned to the login screen. Your '
            'saved Client ID and Redirect URI will be pre-filled.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
            'This wipes your API credentials, tokens and session from this '
            'device. You will need to set everything up again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(secureStoreProvider).clearAll();
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _RateLimitTile extends ConsumerWidget {
  const _RateLimitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rl = ref.watch(rateLimitProvider);
    return ListTile(
      leading: const Icon(Icons.speed_rounded),
      title: const Text('API usage'),
      subtitle: Text(rl == null
          ? 'Reddit allows roughly 100 requests/minute. No data yet.'
          : '${rl.used}/${rl.total} used this window · resets in ${rl.resetSeconds}s'),
    );
  }
}
