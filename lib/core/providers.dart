import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reddit_repository.dart';
import '../features/auth/auth_controller.dart';
import '../features/settings/settings_controller.dart';
import 'network/rate_limit.dart';
import 'network/reddit_client.dart';
import 'network/response_cache.dart';

final redditClientProvider = Provider<RedditClient>((ref) {
  var active = true;
  final client = RedditClient(
    ref.watch(secureStoreProvider),
    ref.watch(authRepositoryProvider),
    onRateLimit: (rl) => ref.read(rateLimitProvider.notifier).state = rl,
    cacheEnabled: () => ref.read(settingsControllerProvider).offlineCache,
    cache: ref.watch(responseCacheProvider),
    sessionReady: () => active && !ref.read(authTransitionProvider),
  );
  // Re-read auth mode (OAuth vs website session) on any login / account switch.
  ref.listen(authControllerProvider, (_, __) => client.invalidateAuthConfig());
  ref.listen(
    authSessionEpochProvider,
    (_, __) => client.invalidateAuthConfig(),
  );
  ref.onDispose(() {
    active = false;
    client.invalidateAuthConfig();
  });
  return client;
});

final redditRepositoryProvider = Provider<RedditRepository>((ref) {
  ref.watch(authSessionEpochProvider);
  ref.watch(authControllerProvider.select((s) => s.valueOrNull?.username));
  final repo = RedditRepository(ref.watch(redditClientProvider));
  void apply(Settings s) {
    repo.subsCacheEnabled = s.subsCacheEnabled;
    repo.subsCacheTtl = Duration(minutes: s.subsCacheMinutes);
  }

  apply(ref.read(settingsControllerProvider));
  ref.listen(settingsControllerProvider, (_, s) => apply(s));
  return repo;
});
