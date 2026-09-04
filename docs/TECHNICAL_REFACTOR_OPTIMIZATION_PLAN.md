# Lily for Reddit — Technical Refactoring & Optimization Plan

> **Branch**: `feat/ui-ux-remap-completion-audit`  
> **Date**: September 2026  
> **Status**: Technical Architecture Plan & Optimization Blueprint

---

## 1. Architecture Assessment

The Lily for Reddit Flutter codebase follows a feature-driven folder organization (`lib/features/*`) supported by a shared core (`lib/core/*`) and data models (`lib/models/*`). While this structure is conceptually sound, previous rapid iterations have concentrated disproportionate amounts of responsibility into a handful of oversized files.

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                   │
│   HomeShell · PostListView · PostCard · PostDetailScreen │
└────────────────────────────┬────────────────────────────┘
                             │ watches / reads
┌────────────────────────────▼────────────────────────────┐
│                    Controller Layer                     │
│  FeedController · CommentsController · SettingsController│
└────────────────────────────┬────────────────────────────┘
                             │ queries
┌────────────────────────────▼────────────────────────────┐
│                    Repository Layer                     │
│               RedditRepository (1,072 lines)             │
└────────────────────────────┬────────────────────────────┘
                             │ executes
┌────────────────────────────▼────────────────────────────┐
│                      Network Layer                      │
│                RedditClient (Dio) · Catbox              │
└─────────────────────────────────────────────────────────┘
```

### Architectural Deficiencies:
1. **Monolithic UI/Business Logic Coupling**: `post_detail_screen.dart` (1,064 lines) combines UI rendering, Markdown style caching, comment tree flattening, search offset manipulation, and reply dispatching.
2. **God Repository**: `RedditRepository` (1,072 lines) acts as a single point of failure for 14 disparate concerns: listings, client-side ranking, comment graphs, voting, user profiles, subreddits, multireddits, moderation, inbox messages, search, and image host uploads.
3. **Fragile Controller Subscriptions**: `PostCard` subscribes to multiple granular settings without grouped selector tuples, leading to unnecessary build cycles when unrelated settings mutate.

---

## 2. Refactoring Candidates

The following 5 targeted refactoring candidates address concrete maintainability, performance, and testing bottlenecks without undertaking risky broad rewrites:

### Candidate 1: Decompose `PostDetailScreen` into Modular Sub-Widgets
- **Files**: `lib/features/post/post_detail_screen.dart` (1,064 lines)
- **Current Problem**: The file contains `_PostDetailScreenState`, `_PostHeader`, `_CommentTile`, search navigation, and bottom sheet handlers. It is error-prone to edit and difficult to test in isolation.
- **Proposed Solution**:
  - Extract `PostDetailHeader` into `lib/features/post/widgets/post_detail_header.dart`.
  - Extract `CommentSearchCoordinator` into `lib/features/post/controllers/comment_search_coordinator.dart` to compute real index targets instead of fixed pixel offsets.
  - Extract `CommentTile` into `lib/features/post/widgets/comment_tile.dart`.
- **Expected Benefit**: Reduces file length by 65%, isolates comment search testing, and prevents post header state from triggering comment sliver rebuilds.
- **Risk**: Low (pure widget extraction).
- **Complexity**: Medium.

### Candidate 2: Domain-Split `RedditRepository`
- **Files**: `lib/data/reddit_repository.dart` (1,072 lines)
- **Current Problem**: Merges post feed fetching, comment tree traversal, multireddit CRUD, inbox polling, and image uploading into one class. Mocking this repository in unit tests requires extensive boilerplate.
- **Proposed Solution**: Split into focused domain repositories coordinated by `RedditRepository` or distinct providers:
  - `FeedRepository`: Listing queries, post ranking algorithms, pagination cursors.
  - `CommentsRepository`: Tree fetching, comment replies, moreChildren expansion.
  - `SubredditRepository`: Subscriptions, community details, flairs.
  - `InboxRepository`: Messages, mentions, unread markers.
- **Expected Benefit**: Dramatically improves unit testability; allows distinct caching TTLs per domain; decouples network failures.
- **Risk**: Low (interface delegation preserves backward compatibility).
- **Complexity**: Medium.

### Candidate 3: Modularize `SettingsScreen` into Domain Panels
- **Files**: `lib/features/settings/settings_screen.dart` (873 lines), `settings_panels.dart`
- **Current Problem**: An 873-line continuous array of `ListTile` and `SwitchListTile` widgets, embedded entirely inside `AccountTab`.
- **Proposed Solution**:
  - Extract distinct panels: `AppearanceSettingsPanel`, `FeedSettingsPanel`, `MediaSettingsPanel`, `NotificationSettingsPanel`, `DataStoragePanel`.
  - Introduce sub-route navigation (`/settings/appearance`, `/settings/feed`, etc.) for desktop/tablet readiness, while `AccountTab` renders clean high-level summary cards pointing to sub-routes.
- **Expected Benefit**: Eliminates UI clutter on the Profile/Account tab; simplifies settings search; isolates provider rebuilds.
- **Risk**: Very Low.
- **Complexity**: Low.

### Candidate 4: Unify Media Container Pipeline (`MediaFrame`)
- **Files**: `lib/features/feed/post_card.dart`, `lib/features/post/post_detail_screen.dart`, `lib/core/media_aspect_ratio.dart`
- **Current Problem**: Feed post cards and post detail screens calculate media constraints differently. Post cards use `LayoutBuilder` with an `AspectRatio` box, while post detail uses `ConstrainedBox(minHeight: 120, maxHeight: 0.65 * height)` without pre-reserved aspect ratios, causing layout jumping.
- **Proposed Solution**:
  - Create a unified `MediaFrame` widget that encapsulates:
    - Smart aspect ratio calculation from `Post` metadata.
    - Capped tall media handling with gradient fade and expand affordance.
    - Uniform `ClipRRect(borderRadius: ShapeTokens.large)`.
    - Memory-efficient `CachedNetworkImage` downscaling.
- **Expected Benefit**: Guarantees identical, predictable media presentation across feed, search, user profile, and post detail; eliminates visual layout jumping.
- **Risk**: Medium (touches core media display).
- **Complexity**: Medium.

### Candidate 5: Extract Post Card Display Variants
- **Files**: `lib/features/feed/post_card.dart` (1,007 lines), `compact_post_card.dart`
- **Current Problem**: `PostCard` handles full card (`_cardsCard`), large card (`_largeCard`), and mini card (`_miniCard`) in a single stateful widget, interleaving video controller bindings and swipe gestures.
- **Proposed Solution**: Extract `LargePostCard`, `CardPostCard`, and `MiniPostCard` into dedicated stateless presenters wrapped by an interaction shell.
- **Expected Benefit**: Clean separation of display modes; enables isolated widget golden tests; simplifies gesture binding.
- **Risk**: Low.
- **Complexity**: Medium.

---

## 3. State-Management Improvements

### 1. Single-Flight Token Refresh Mutex (`RedditClient`)
- **Current Problem**: In `lib/core/network/reddit_client.dart` (lines 50-60), when an access token expires, multiple concurrent requests (feed + inbox + subscriptions) receive a `401 Unauthorized` simultaneously. Each request independently calls `await _auth.refresh()`. Reddit's OAuth server can invalidate concurrent refresh tokens or fail requests with `400 Bad Request`.
- **Solution**: Implement an in-flight `Completer<String?>? _refreshCompleter` inside `RedditClient`:
  ```dart
  Future<String?> _refreshTokenSingleFlight() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;
    final completer = Completer<String?>();
    _refreshCompleter = completer;
    try {
      final token = await _auth.refresh();
      completer.complete(token);
      return token;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }
  ```

### 2. Selective Rebuild Filtering with `.select()`
- **Current Problem**: In `PostListView` and `HomeShell`, widgets frequently watch `ref.watch(settingsControllerProvider)` directly. When any unrelated setting changes (e.g. `checkUpdates` or `notifyInbox`), the entire post feed or shell rebuilds.
- **Solution**: Consistently apply narrow selectors, e.g.:
  `ref.watch(settingsControllerProvider.select((s) => (s.forYouFeed, s.autoHideReadForYou)))`

### 3. Comment Presentation Memory Scoping
- **Current Problem**: `flattenedCommentPresentationProvider` caches formatted markdown trees keyed by `(key, MarkdownStyleSheet)`. Deep comment trees with 500+ comments retain large widget and element graphs in memory.
- **Solution**: Ensure auto-dispose is active on `commentsControllerProvider` and `flattenedCommentPresentationProvider` when leaving the post detail route, releasing large text trees immediately.

---

## 4. Rendering & Rebuild Optimizations

### 1. Eliminate Separated ListView Overhead in Feed
- **Current Problem**: `PostListView` uses `ListView.separated` with `separatorBuilder: (_, __) => const SizedBox.shrink()`. This creates an empty separator element between every item.
- **Solution**: Convert to `ListView.builder` with direct item spacing (`margin` or padding on `PostCard`), reducing widget instantiation overhead by 50% during scrolling.

### 2. Resolve Media Layout Shifts
- **Current Problem**: In `PostDetailScreen`, images load inside an unconstrained box starting at 120dp height, jumping to full image height upon HTTP response.
- **Solution**: Apply `AspectRatio` or computed height constraints prior to image download using the pre-parsed `previewWidth` and `previewHeight`.

### 3. RepaintBoundary Optimization
- **Current Status**: `PostListView` wraps each `PostCard` in `RepaintBoundary(key: ValueKey<String>('post-card-${post.id}'))`.
- **Optimization**: Retain `RepaintBoundary` around `PostCard`, but ensure `M3EPostActionBar` is isolated so that upvoting or saving only repaints the action bar and does not invalidate the post media layer or thumbnail raster cache.

---

## 5. Networking Improvements

### 1. Rate-Limiting Compliance & Queue Smoothing
- Reddit enforces a strict ~100 requests/minute limit per client ID.
- **Implementation**: The existing `RateLimitTracker` in `lib/core/network/rate_limit.dart` captures `x-ratelimit-remaining` and `x-ratelimit-reset`. We should introduce an active client queue interceptor that automatically delays outbound non-critical requests (e.g. prefetching or background history sync) when remaining quota drops below 10 requests.

### 2. Unified Network Error Mapping
- Wrap Dio HTTP exceptions into domain-level failures (`NetworkUnavailableException`, `AuthenticationExpiredException`, `RateLimitExceededException`, `RedditServerException`) with user-friendly strings, eliminating raw stack traces and JSON parsing error messages in the UI.

---

## 6. Caching Improvements

### 1. Subscription List Memory Cache (`RedditRepository`)
- `RedditRepository._subsCache` caches user subscriptions for 10 minutes.
- **Optimization**: Persist subscriptions to local cache with an ETag/timestamp check so cold starts do not wait for up to 5 sequential paged requests before rendering the "For You" feed or Discover screen.

### 2. Disk Response Cache Pruning
- `ResponseCache` (`lib/core/network/response_cache.dart`) caches GET responses for offline viewing. Ensure that an asynchronous background LRU eviction job purges records older than 7 days, capping maximum cache size at 50MB.

---

## 7. Persistence Improvements

### 1. Batching & Debouncing Preferences IO
- Phase 5 introduced `DeferredPrefWriter` for `InteractionVault`.
- **Recommendation**: Extend `DeferredPrefWriter` to `InterestStore` and `HistoryStore` to prevent burst writes from blocking the main thread during rapid post flipping or feed browsing.

### 2. SharedPreferences Migration Strategy
- Maintain `SharedPreferences` for user configuration and small flags, but avoid storing large serialized JSON strings (e.g. hundreds of post IDs). Keep `InteractionVault` keys partitioned and aggressively prune expired items (>30 days).

---

## 8. Media Performance Improvements

### 1. Exact Pixel Downscaling (`CachedNetworkImage`)
- Ensure `memCacheWidth` and `memCacheHeight` are computed accurately using device pixel ratio (`MediaQuery.devicePixelRatioOf(context)`):
  `final cacheWidth = (width * dpr).round().clamp(1, 1080).toInt();`
  `final cacheHeight = (height * dpr).round().clamp(1, 1920).toInt();`
- Avoid passing 0 or negative values to memory cache parameters to prevent image decoding errors.

### 2. Feed Video Player Pool Lifecycle
- Multiple `InlineVideo` instances mounted in feed cards must immediately pause and release hardware decoders when scrolled out of view.
- Ensure `VisibilityDetector` on `InlineVideo` pauses playback when visibility fraction is < 50% and disposes controllers after 30 seconds off-screen.

---

## 9. Test Coverage Gaps

The test suite currently contains 23 test files with strong coverage for `InteractionVault`, `ThemeTokens`, and basic `PostCard` rendering. However, critical gaps exist:

### Critical Gaps to Close:
1. **Deterministic Media Aspect Ratio Tests**:
   - Test missing width/height payloads (verify non-distorted discovery).
   - Test extreme portrait images (>3:1 ratio) verifying top-alignment and expand button.
   - Test extreme landscape images (<1:3 ratio).
   - Test video dimensions extracted from `reddit_video`.
   - Test gallery items with mixed aspect ratios.
2. **Comment Search & Navigation Tests**:
   - Verify that comment search calculates the exact target index of matching text.
   - Verify that top-level comment jump targets the nearest subsequent depth-0 comment.
3. **Network Token Refresh Concurrency**:
   - Simulate 5 simultaneous requests with 401 responses; verify exactly one call to `AuthRepository.refresh()` is made.
4. **Crosspost Data Parsing**:
   - Test `Post.fromData` on a Reddit crosspost payload; verify media and preview data are correctly populated from `crosspost_parent_list[0]`.

---

## 10. Android Production Optimization

### 1. ABI Split APK Distribution (`--split-per-abi`)
- **Current State**: GitHub Actions builds a single fat APK containing `armeabi-v7a`, `arm64-v8a`, `x86_64`. APK download size is ~55MB.
- **Optimization**: Update release pipeline to run `flutter build apk --release --split-per-abi`.
- **Impact**: Generates a dedicated `app-arm64-v8a-release.apk` of approximately **18MB to 22MB** (~60% size reduction), dramatically speeding up downloads for 99% of modern Android devices.

### 2. Gradle Build Speed & Daemon Optimization
- In `android/gradle.properties`:
  - Disable obsolete Jetifier: `android.enableJetifier=false` (all dependencies are modern AndroidX).
  - Enable parallel execution: `org.gradle.parallel=true`.
  - Enable caching: `org.gradle.caching=true`.
  - Configure configuration caching: `org.gradle.configuration-cache=true`.
- **Impact**: Reduces local and CI clean build times by 25-40%.

### 3. ProGuard / R8 Rule Auditing
- Review `android/app/proguard-rules.pro` to ensure rules for `flutter_local_notifications` and `workmanager` remain minimal and strictly scoped to entry point keep definitions, avoiding speculative broad rules.

---

## 11. CI / Build Considerations

1. **Gradle Cache Action**: Utilize `actions/cache` in GitHub Actions for `~/.gradle/caches` and `~/.gradle/wrapper` to shave 2-3 minutes off every PR build.
2. **Flutter Artifact Cache**: Cache the Flutter SDK download in CI runners to eliminate repeated tarball extraction on every trigger.
3. **Hardened Test Enforcement**: The test enforcement hardening implemented on `chore/harden-ci-tests` must be merged into `main` before feature development begins, ensuring any regression immediately fails CI.

---

## 12. Risk Assessment

| Risk Area | Severity | Likelihood | Mitigation Strategy |
|---|---|---|---|
| Media aspect ratio regressions | High | Medium | Implement comprehensive deterministic widget tests for all ratios prior to UI modifications. |
| Gesture conflicts on post cards | Medium | Medium | Remove horizontal scrolling from `M3EPostActionBar` and test with `SwipeActions` enabled. |
| Token refresh deadlock | High | Low | Implement timeout fail-safes (e.g. 15s) on single-flight refresh completer. |
| In-app updater compatibility | Medium | Low | Ensure APK split naming conventions match `UpdateChecker` URL parsing logic. |

---

## 13. Recommended Implementation Order

To deliver maximum value without regressions or repeated rewrites, work should proceed in four sequential phases:

```
┌────────────────────────────────────────────────────────┐
│  Phase 1: Media Pipeline & Geometry Hardening (P0)     │
│  - Unescape &amp; in post preview/gallery URLs             │
│  - Extract video dimensions from reddit_video          │
│  - Restore BoxFit.cover on square thumbnails           │
│  - Fix capped tall media preview & expand badge        │
│  - Add comprehensive media aspect-ratio tests          │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Phase 2: Post Card & Frontpage M3E Polish (P1)        │
│  - Redesign PostCard visual styling & typography       │
│  - Make M3EPostActionBar responsive (no scroll)        │
│  - Remove duplicate New Post button on Home            │
│  - Fix Home top bar spacing & chip styling             │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Phase 3: Post Detail & Navigation Realization (P1/P2) │
│  - Fix real comment search indexing & scrolling        │
│  - Fix real next-top-level comment jumping             │
│  - Unify Post Detail media with MediaFrame             │
│  - Resolve Inbox nested Scaffold FAB collision         │
│  - Replace UserScreen comment card with M3ECommentCard │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Phase 4: Architecture, Android & CI Polish (P2/P3)    │
│  - Single-flight token refresh mutex in RedditClient   │
│  - Decompose post_detail_screen.dart & settings_screen │
│  - Enable --split-per-abi in release build             │
│  - Optimize android/gradle.properties (no Jetifier)    │
└────────────────────────────────────────────────────────┘
```
