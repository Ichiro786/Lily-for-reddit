import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/motion_tokens.dart';
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
  Timer? _revealChromeTimer;

  @override
  void dispose() {
    _revealChromeTimer?.cancel();
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
    if (!granted || !mounted) return;
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
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (scrollChromeVisible(n, true) && !scrollChromeVisible(n, false)) {
      return false; // Idle/ballistic events must not cancel a pending reveal.
    }
    final visible = scrollChromeVisible(n, _chrome.value);
    if (!visible) {
      _revealChromeTimer?.cancel();
      _revealChromeTimer = null;
      _chrome.value = false;
    } else if (!_chrome.value) {
      if (n.metrics.pixels <= n.metrics.minScrollExtent ||
          MotionTokens.reduced(context)) {
        _revealChromeTimer?.cancel();
        _revealChromeTimer = null;
        _chrome.value = true;
      } else {
        _revealChromeTimer ??= Timer(const Duration(milliseconds: 64), () {
          _revealChromeTimer = null;
          if (mounted) _chrome.value = true;
        });
      }
    }
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
              const _FrontpageTab(),
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
                duration: MotionTokens.feedback(context),
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
          isVisible: visible,
          isMinimized: !showNavLabels,
          onSearch: () {
            _revealChromeTimer?.cancel();
            _revealChromeTimer = null;
            _chrome.value = true;
            if (_index != 1) {
              setState(() {
                _tabWidgets[1] ??= _createTab(1);
                _index = 1;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ref.read(discoverSearchSignalProvider.notifier).state++;
                }
              });
            } else {
              ref.read(discoverSearchSignalProvider.notifier).state++;
            }
          },
          onTap: (i) {
            _revealChromeTimer?.cancel();
            _revealChromeTimer = null;
            _chrome.value = true;
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
class _LazyKeepAliveTabHost extends StatefulWidget {
  const _LazyKeepAliveTabHost({required this.index, required this.tabs});

  final int index;
  final List<Widget?> tabs;

  @override
  State<_LazyKeepAliveTabHost> createState() => _LazyKeepAliveTabHostState();
}

class _LazyKeepAliveTabHostState extends State<_LazyKeepAliveTabHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );
  late final Animation<double> _opacity = _entry.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );

  @override
  void didUpdateWidget(covariant _LazyKeepAliveTabHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MotionTokens.reduced(context)) {
        _entry.value = 1;
      } else {
        _entry.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionTokens.reduced(context)) _entry.value = 1;
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.tabs.length; i++)
          Offstage(
            key: ValueKey<int>(i),
            offstage: i != widget.index,
            child: TickerMode(
              enabled: i == widget.index,
              child: FadeTransition(
                opacity: _opacity,
                child: RepaintBoundary(
                  child: widget.tabs[i] ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FrontpageTab extends ConsumerWidget {
  const _FrontpageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => PostListView(
    feedKey: '',
    frontpageStyle: true,
    header: FrontpageHeader(
      forYou: ref.watch(settingsControllerProvider.select((s) => s.forYouFeed)),
    ),
  );
}
