import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/deep_links.dart';
import 'core/startup_metrics.dart';
import 'core/theme/app_theme.dart';
import 'core/reddit_constants.dart';
import 'features/auth/auth_controller.dart';
import 'features/inbox/inbox_controller.dart';
import 'features/notifications/notification_service.dart';
import 'features/settings/settings_controller.dart';
import 'router.dart';

class LuliApp extends ConsumerStatefulWidget {
  const LuliApp({super.key});

  @override
  ConsumerState<LuliApp> createState() => _LuliAppState();
}

class _LuliAppState extends ConsumerState<LuliApp>
    with WidgetsBindingObserver {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  bool _resumeRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final startup = StartupMetrics.instance;
    startup.startFrameTimings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startup.markFirstFlutterFrame();
    });
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);

    // Tapping an inbox notification deep-links to the comment/message.
    NotificationService.onSelectRoute = (route) {
      if (mounted) ref.read(routerProvider).push(route);
    };
    NotificationService.instance
        .init()
        .then((_) => NotificationService.instance.handleLaunch());
  }

  void _handleLink(Uri uri) {
    final route = routeForRedditUrl(uri);
    if (route != null) ref.read(routerProvider).push(route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _resumeRefreshScheduled) return;
    _resumeRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeRefreshScheduled = false;
      if (!mounted) return;
      // Revalidate auth and sync inbox after resume, but do it after the frame
      // so returning to the app never blocks the visible UI. The unread provider
      // keeps its cached value and schedules its own stale-while-refresh fetch.
      ref.invalidate(authControllerProvider);
      ref.invalidate(inboxControllerProvider);
      ref.invalidate(unreadCountProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final seed = Color(settings.seedColor);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamic = settings.useDynamicColor;
        return MaterialApp.router(
          title: RedditConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(
            useDynamic ? lightDynamic?.harmonized() : null,
            seed: seed,
          ),
          darkTheme: AppTheme.dark(
            useDynamic ? darkDynamic?.harmonized() : null,
            seed: seed,
            amoled: settings.amoled,
          ),
          themeMode: settings.themeMode,
          // Global font-size control (scales all text in the app).
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                  textScaler: TextScaler.linear(settings.textScale)),
              child: child!,
            );
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('he'), // RTL
            Locale('ar'), // RTL
            Locale('es'),
            Locale('fr'),
            Locale('de'),
          ],
          routerConfig: router,
        );
      },
    );
  }
}
