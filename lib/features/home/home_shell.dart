import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/rate_limit.dart';
import '../../core/theme/shape_tokens.dart';
import '../auth/auth_controller.dart';
import '../explore/explore_screen.dart';
import '../feed/post_list_view.dart';
import '../inbox/inbox_controller.dart';
import '../inbox/inbox_screen.dart';
import '../notifications/inbox_poller.dart';
import '../notifications/notification_service.dart';
import '../settings/settings_controller.dart';
import '../updates/update_checker.dart';
import 'account_tab.dart';
import 'tab_signals.dart';
import 'frontpage_header.dart';
import '../navigation/m3e_floating_nav_bar.dart';

/// SharedPreferences flag: have we shown the one-time notifications suggestion?
const String _kNotifPromptedPref = 'notifyInboxPrompted';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  // Posts is created directly by build(). Other tabs stay null until first
  // selection, then remain mounted so their scroll and provider state survive.
  final List<Widget?> _tabWidgets = List<Widget?>.filled(4, null);

  final ValueNotifier<bool> _chrome = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _chrome.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeCheckUpdates();
      if (mounted) await _maybeSuggestNotifications();
    });
  }

  /// One-time, opt-in suggestion to enable inbox notifications (shown on an
  /// early app open). Declining or enabling both mark it as handled so we never
  /// nag again — it stays fully controllable in Settings either way.
  Future<void> _maybeSuggestNotifications() async {
    final prefs = ref.read(sharedPrefsProvider);
    if (prefs.getBool(_kNotifPromptedPref) ?? false) return;
    if (ref.read(settingsControllerProvider).notifyInbox) return;
    await prefs.setBool(_kNotifPromptedPref, true);
    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const Text('Get notified of replies?'),
        content: const Text(
          'Lily for Reddit can check your Reddit inbox in the background (about every 15 '
          'minutes) and notify you of replies, mentions and messages.\n\n'
          'It uses simple polling — no Firebase or tracking. You can change '
          'this anytime in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (enable != true || !mounted) return;
    final granted = await NotificationService.instance.requestPermission();
    if (!granted) return;
    ref.read(settingsControllerProvider.notifier).setNotifyInbox(true);
    await pollInbox(notify: false); // prime, don't notify for existing unread
    await registerInboxPolling();
  }

  Future<void> _maybeCheckUpdates() async {
    if (!Platform.isAndroid) return; // GitHub-APK updates are Android-only
    if (!ref.read(settingsControllerProvider).checkUpdates) return;
    final info = await UpdateChecker().check();
    if (info == null || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update available — v${info.version}'),
        content: const Text(
          'A newer version of Lily for Reddit is available on GitHub.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(
                Uri.parse(info.apkUrl ?? info.url),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Widget _createTab(int index) {
    switch (index) {
      case 1:
        return const ExploreScreen();
      case 2:
        return const InboxScreen();
      case 3:
        return const AccountTab();
      default:
        throw ArgumentError.value(index, 'index', 'Only tabs 1-3 are lazy.');
    }
  }

  bool _onScroll(ScrollNotification n) {
    final visible = scrollChromeVisible(n, _chrome.value);
    if (visible != _chrome.value) _chrome.value = visible;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final showNavLabels = ref.watch(
      settingsControllerProvider.select((s) => s.navLabels),
    );
    return Scaffold(
      // Pop variant: content flows under the detached floating nav.
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: SafeArea(
          bottom: false,
          child: _LazyKeepAliveTabHost(
            index: _index,
            tabs: [
              ValueListenableBuilder<bool>(
                valueListenable: _chrome,
                builder: (_, visible, __) =>
                    _FrontpageTab(chromeVisible: visible),
              ),
              _tabWidgets[1],
              _tabWidgets[2],
              _tabWidgets[3],
            ],
          ),
        ),
      ),
      floatingActionButton: _index == 0
          ? ValueListenableBuilder<bool>(
              valueListenable: _chrome,
              builder: (context, visible, child) => AnimatedScale(
                scale: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.fastOutSlowIn,
                child: child!,
              ),
              child: SizedBox(
                width: 64,
                height: 64,
                child: FloatingActionButton(
                  tooltip: 'Create post',
                  elevation: 0,
                  onPressed: () => context.push('/submit'),
                  child: const Icon(Icons.add_rounded, size: 28),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: _chrome,
        builder: (_, visible, __) => M3EFloatingNavBar(
          currentIndex: _index,
          unreadCount: unread,
          isMinimized: !visible || !showNavLabels,
          onSearch: () => context.push('/search'),
          onTap: (i) {
            // Re-tapping the active tab scrolls it to top (Posts also refreshes).
            if (i == _index) {
              if (i == 0) {
                ref.read(frontpageScrollSignalProvider.notifier).state++;
              } else {
                ref.read(tabReselectProvider(i).notifier).state++;
              }
              return;
            }
            setState(() {
              if (i != 0) _tabWidgets[i] ??= _createTab(i);
              _index = i;
            });
            _chrome.value = true; // always reveal chrome when switching tabs
          },
        ),
      ),
    );
  }
}

/// Keeps initialized tabs mounted while creating non-selected tabs on demand.
/// Offstage preserves each tab's element/state tree; TickerMode avoids running
/// animations for tabs that are not currently visible.
class _LazyKeepAliveTabHost extends StatelessWidget {
  const _LazyKeepAliveTabHost({required this.index, required this.tabs});

  final int index;
  final List<Widget?> tabs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < tabs.length; i++)
          Offstage(
            key: ValueKey<int>(i),
            offstage: i != index,
            child: TickerMode(
              enabled: i == index,
              child: tabs[i] ?? const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

class _FrontpageTab extends ConsumerWidget {
  const _FrontpageTab({this.chromeVisible = true});
  final bool chromeVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final username =
        ref.watch(authControllerProvider).valueOrNull?.username ?? '';
    final settings = ref.watch(settingsControllerProvider);
    final forYou = settings.forYouFeed;
    final mode = settings.topBarMode;
    // Keep the saved mode value compatible; compact mode needs no toolbar.
    final showActionRow = mode == TopBarMode.full;
    return Column(
      children: [
        // Full mode: Google-app style search bar with avatar — collapses on
        // scroll. Compact mode leaves just the feed title.
        if (showActionRow)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.fastOutSlowIn,
            alignment: Alignment.topCenter,
            child: chromeVisible
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        if (ref
                            .watch(settingsControllerProvider)
                            .showApiUsage) ...[
                          const _ApiUsagePill(),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: ShapeTokens.full,
                              border: Border.all(
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.20,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: ShapeTokens.full,
                                onTap: () => context.push('/search'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.search_rounded,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Search Reddit',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Semantics(
                          button: true,
                          label: 'Your profile',
                          child: GestureDetector(
                            onTap: () => context.push('/u/$username'),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: cs.primaryContainer,
                              child: Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        Expanded(
          child: PostListView(
            feedKey: '',
            frontpageStyle: true,
            header: FrontpageHeader(forYou: forYou),
          ),
        ),
      ],
    );
  }
}

/// Shows live Reddit API rate-limit usage alongside the search bar
/// (power-user setting). Reddit allows ~100 requests/minute per OAuth client.
class _ApiUsagePill extends ConsumerWidget {
  const _ApiUsagePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final rl = ref.watch(rateLimitProvider);
    final String label;
    if (rl == null) {
      label = 'API: 0/100';
    } else {
      label = 'API: ${rl.used}/${rl.total}';
    }
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: ShapeTokens.full,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_rounded, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
