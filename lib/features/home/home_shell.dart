import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/rate_limit.dart';
import '../../core/widgets/glass_surface.dart';
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

  bool _chrome = true;

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
            'this anytime in Settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable')),
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
            'A newer version of Lily for Reddit is available on GitHub.'),
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

  bool _onScroll(UserScrollNotification n) {
    if (n.depth != 0) return false;
    final m = n.metrics;
    // Near the top or overscrolling (iOS rubber-band) — keep chrome shown and
    // don't toggle, so the bar doesn't bounce in/out as you scroll back up.
    if (m.outOfRange || m.pixels <= m.minScrollExtent + 4) {
      if (!_chrome) setState(() => _chrome = true);
      return false;
    }
    if (n.direction == ScrollDirection.reverse && _chrome) {
      setState(() => _chrome = false);
    } else if (n.direction == ScrollDirection.forward && !_chrome) {
      setState(() => _chrome = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final navLabels =
        ref.watch(settingsControllerProvider.select((s) => s.navLabels));
    return Scaffold(
      // Pop variant: content flows under the detached floating nav.
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: SafeArea(
          bottom: false,
          child: _LazyKeepAliveTabHost(
            index: _index,
            tabs: [
              _FrontpageTab(chromeVisible: _chrome),
              _tabWidgets[1],
              _tabWidgets[2],
              _tabWidgets[3],
            ],
          ),
        ),
      ),
      bottomNavigationBar: M3EFloatingNavBar(
        selectedIndex: _index,
        unread: unread,
        minimized: !_chrome,
        showLabels: navLabels,
        onSelected: (i) {
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
            _chrome = true; // always reveal chrome when switching tabs
          });
        },
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

/// Three-dot menu to switch the feed's post display type.
class _DisplayMenu extends ConsumerWidget {
  const _DisplayMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: 'Display',
      onSelected: (v) {
        if (v == 'autoplay') {
          ctrl.setAutoplayMedia(!s.autoplayMedia);
        } else {
          ctrl.setPostDisplay(
              PostDisplay.values.firstWhere((d) => d.name == v));
        }
      },
      itemBuilder: (_) => [
        for (final d in PostDisplay.values)
          PopupMenuItem(
            value: d.name,
            child: Row(
              children: [
                Icon(d.icon, size: 20),
                const SizedBox(width: 12),
                Text(d.label),
                if (d == s.postDisplay) ...[
                  const Spacer(),
                  const Icon(Icons.check_rounded, size: 18),
                ],
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'autoplay',
          child: Row(
            children: [
              const Icon(Icons.play_circle_outline_rounded, size: 20),
              const SizedBox(width: 12),
              const Text('Autoplay media'),
              const Spacer(),
              if (s.autoplayMedia) const Icon(Icons.check_rounded, size: 18),
            ],
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
    final expandable = mode == TopBarMode.expandable;
    final hasTrailing = expandable;
    // Full mode pins the action row; Expandable floats it in on demand.
    final showActionRow = mode == TopBarMode.full;
    return Column(
      children: [
        // Full mode: Google-app style search bar with avatar — collapses on
        // scroll. Compact mode hides it; Expandable shows it on demand.
        if (showActionRow)
          AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: chromeVisible
              ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: ref.watch(settingsControllerProvider).showApiUsage
                    ? _ApiUsagePill()
                    : GlassSurface(
                        borderRadius: BorderRadius.circular(28),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => context.push('/search'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded,
                                    color: cs.onSurfaceVariant),
                                const SizedBox(width: 12),
                                Text('Search Reddit',
                                    style:
                                        TextStyle(color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: 'New post',
                icon: const Icon(Icons.edit_square, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                onPressed: () => context.push('/submit'),
              ),
              const _DisplayMenu(),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Your profile',
                child: GestureDetector(
                  onTap: () => context.push('/u/$username'),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold),
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
            header: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, hasTrailing ? 10 : 8, hasTrailing ? 4 : 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    forYou ? 'For You' : 'Frontpage',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (forYou) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Personalized on-device · Beta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ),
                  ] else
                    const Spacer(),
                  // Expandable mode: one button that floats the toolbar in.
                  if (expandable)
                    IconButton(
                      tooltip: 'Toolbar',
                      icon: const Icon(Icons.more_horiz_rounded),
                      onPressed: () =>
                          _showFloatingToolbar(context, ref, username),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Expandable top-bar mode: floats the full toolbar (search, new post, display,
/// profile) in from the top as a dismissible overlay — it never displaces the
/// feed.
Future<void> _showFloatingToolbar(
    BuildContext context, WidgetRef ref, String username) {
  final router = GoRouter.of(context);
  final cs = Theme.of(context).colorScheme;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Toolbar',
    barrierColor: Colors.black.withValues(alpha: 0.30),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) {
      void close() => Navigator.of(ctx).pop();
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(28),
              tintOpacity: 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          close();
                          router.push('/search');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  color: cs.onSurfaceVariant),
                              const SizedBox(width: 12),
                              Text('Search Reddit',
                                  style:
                                      TextStyle(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      tooltip: 'New post',
                      icon: const Icon(Icons.edit_square, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                      ),
                      onPressed: () {
                        close();
                        router.push('/submit');
                      },
                    ),
                    const _DisplayMenu(),
                    const SizedBox(width: 4),
                    Semantics(
                      button: true,
                      label: 'Your profile',
                      child: GestureDetector(
                        onTap: () {
                          close();
                          router.push('/u/$username');
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.06), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Shows live Reddit API rate-limit usage in place of the search bar
/// (power-user setting). Reddit allows ~100 requests/minute per OAuth client.
class _ApiUsagePill extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final rl = ref.watch(rateLimitProvider);
    final String label;
    if (rl == null) {
      label = 'API usage · no calls yet';
    } else {
      label = 'API ${rl.used}/${rl.total} · resets ${rl.resetSeconds}s';
    }
    return GlassSurface(
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.speed_rounded, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
