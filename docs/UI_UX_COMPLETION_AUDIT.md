# Lily for Reddit — UI/UX Remap Completion Audit

> **Branch**: `feat/ui-ux-remap-completion-audit`  
> **Date**: September 2026  
> **Status**: Comprehensive Audit & Roadmap (No production code modified)

---

## 1. Executive Summary

This audit establishes the definitive baseline for completing the UI/UX remap of Lily for Reddit into a cohesive, production-grade Material 3 Expressive (M3E) client. Following the removal of the abandoned Kotlin/Compose prototype, the Flutter codebase (`lib/`) represents the sole production product. 

While recent development phases successfully established M3E tokens, AMOLED surfaces, and basic feed scaffolding, the application suffers from notable visual inconsistencies, unfinished AI-generated stubs, and critical media aspect-ratio distortions. This document thoroughly maps every screen, details confirmed bugs, isolates the root causes of the post-card and media sizing failures, and specifies a prioritized, regression-free implementation roadmap.

---

## 2. Current UI Architecture

The application is structured as a single-activity Flutter application targeting Android and iOS, built on Flutter 3.9+ with Riverpod 2.6 for state management and GoRouter 14.6 for declarative navigation.

```
lib/
├── app.dart                    # MaterialApp.router, dynamic color, global textScaler
├── main.dart                   # Bootstrap, SharedPreferences, deferred services
├── router.dart                 # GoRouter route declarations and auth redirector
├── core/
│   ├── network/                # RedditClient (Dio), rate limiting, disk cache
│   ├── storage/                # SecureStore, InteractionVault, DeferredPrefWriter
│   ├── theme/                  # ShapeTokens, M3EColorSchemes, M3ETypography, AppTheme
│   └── widgets/                # GlassSurface, M3ELoadingIndicator, M3ERefreshIndicator
├── data/
│   └── reddit_repository.dart  # Monolithic data layer (1,072 lines)
├── features/
│   ├── auth/                   # OAuth login, Web session fallback, AuthController
│   ├── compose/                # Post submission, attachment upload
│   ├── explore/                # Subscribed communities list, local filtering
│   ├── feed/                   # PostListView, PostCard, M3EPostActionBar, FeedRanker
│   ├── home/                   # HomeShell, _LazyKeepAliveTabHost, AccountTab
│   ├── inbox/                  # Tabbed inbox, message threading, notification poller
│   ├── media/                  # GalleryCarousel, MediaViewers, VideoPlayer, NsfwBlur
│   ├── navigation/             # M3EFloatingNavBar (capsule pills, auto-minimizing)
│   ├── post/                   # PostDetailScreen, M3ECommentCard, CommentsController
│   └── settings/               # SettingsScreen (873 lines), SettingsController
└── models/                     # Freezed/JSON models (Post, Comment, Subreddit, User)
```

### Key Architectural Characteristics
- **Root Shell Navigation**: `HomeShell` manages a 4-tab `_LazyKeepAliveTabHost` (Home, Discover, Inbox, Account/Profile) with a detached, floating bottom navigation bar (`M3EFloatingNavBar`).
- **Surface Elevation Model**: Tonal surface containers (`surfaceContainerLowest` through `surfaceContainerHighest`) replace legacy shadows and divider lines. AMOLED dark mode zeroes the background (`#000000`) while card surfaces sit on `#1A1A1F`.
- **State Synchronization**: `PostOverridesController` maintains optimistic vote, score, and save deltas keyed by post ID, shared across feed cards and post detail.

---

## 3. Screen-by-Screen Status & Classification

| Screen / Feature | Classification | Primary Deficiencies & Evidence |
|---|---|---|
| **Home / Frontpage** (`home_shell.dart`, `post_list_view.dart`) | **Partially remapped / Visually inconsistent** | Card borders and padding feel flat; duplicate "New Post" buttons (FAB + top bar); action bar horizontally scrollable causing gesture collisions; media letterboxing. |
| **Post Card** (`post_card.dart`, `post_action_bar.dart`) | **Partially remapped / Functionally unstable** | Broken aspect ratios; 16:9 blind fallback; `BoxFit.contain` creating gray pillarboxes; thumbnail fit distorted; extreme portrait images squeezed into narrow strips. |
| **Post Detail** (`post_detail_screen.dart`) | **Partially remapped / Functionally unstable** | Monolithic file (1,064 lines); comment search and top-level jump are fake stubs (`offset + 260px`, `offset + 280px`); media sizing does not match feed card. |
| **Comment System** (`comment_card.dart`, `comments_controller.dart`) | **Mostly complete / High quality** | Expressive tonal depth rails, AMOLED card contrast, and markdown/spoiler support are solid. Needs performance cleanup on deep trees. |
| **Discover / Explore** (`explore_screen.dart`, `m3e_explore_widgets.dart`) | **Partially remapped / Visually inconsistent** | Search input does not search Reddit posts or new subreddits (only filters local cache); "Popular near you" is simply subscribed subs sorted by count. |
| **Inbox** (`inbox_screen.dart`, `m3e_inbox_widgets.dart`) | **Visually inconsistent / Functionally unstable** | Nested `Scaffold` FAB collides with `M3EFloatingNavBar`; message list items use legacy divider aesthetics rather than expressive surface cards. |
| **Profile / Account** (`account_tab.dart`, `user_screen.dart`) | **Visually inconsistent** | `AccountTab` dumps the entire settings list below the header; `UserScreen` uses legacy `_ProfileCommentCard` with default Material `Card`; dead `onViewProfile` closure. |
| **Settings** (`settings_screen.dart`, `settings_panels.dart`) | **Partially remapped / Technical debt** | Monolithic 873-line widget tree; duplicate styling; hardcoded margins; lack of category sub-page routing. |
| **Search** (`search_screen.dart`) | **Partially remapped / Requires redesign** | Plain tabbed view with older card designs; lacks expressive chips, community hero cards, and post filter pills. |
| **Submit / Compose Post** (`compose_post_screen.dart`) | **Partially remapped** | Basic text inputs; lacks modern expressive attachment tray and live Markdown split preview. |
| **Multireddit / Custom Feeds** (`multireddit/`) | **Partially remapped** | Functional but visually dated list views lacking M3E header tokens. |

---

## 4. Material 3 Expressive (M3E) Implementation Status

### Surfaces & AMOLED
- **Color Scheme**: `M3EColorSchemes` (`lib/core/theme/color_schemes.dart`) provides complete light, dark, and pure-black AMOLED palettes with full container levels.
- **Deficiency**: Several older screens (e.g. `UserScreen`, `SearchScreen`, `PolicyScreen`) still instantiate raw `Card()` or `Container(color: ...)` instead of querying `Theme.of(context).colorScheme.surfaceContainer`.

### Shapes & Corner Radii
- **Token Definition**: `ShapeTokens` (`lib/core/theme/shape_tokens.dart`) defines:
  - `extraSmall`: 12dp
  - `small`: 16dp
  - `medium`: 20dp
  - `large`: 24dp
  - `extraLarge`: 28dp
  - `full`: 999dp (Stadium)
- **Deficiency**: Inconsistent usage. `HomeShell` search bar hardcodes `BorderRadius.circular(28)`; `PostCard` uses `ShapeTokens.large`; `M3EFloatingNavBar` alternates between `28` and `999`; `CompactPostCard` uses `ShapeTokens.small`.

### Typography
- **Token Definition**: `M3ETypography` (`lib/core/theme/typography.dart`) implements expressive scale with bold weights and tight letter spacing.
- **Deficiency**: High amounts of inline `.copyWith(fontSize: ..., fontWeight: ...)` in `post_card.dart` and `post_detail_screen.dart` override and fragment the centralized typography scale.

---

## 5. Home / Frontpage Deep Audit

### 1. Top App Bar & Search Row
- **Current Structure**: `HomeShell` (`lines 310-381`) renders a Google-app style search row inside an `AnimatedSize` that hides when scrolling down.
- **Issues**:
  - **Duplicate Entrypoint**: The search row contains an `IconButton.filled` for "New post" (`Icons.edit_square`), while the screen simultaneously displays a floating `FloatingActionButton` at `FloatingActionButtonLocation.endFloat` (`Icons.add_rounded`). Having two prominent create-post buttons on the primary feed is redundant and clutters the UI.
  - **API Pill Fallback**: When `showApiUsage` is toggled on in settings, the search bar completely disappears and is replaced by an API usage pill, removing search capability entirely from the home tab.

### 2. Page Title & Feed Subtitle
- **Current Structure**: A text row displaying "Frontpage" or "For You" with an expandable toolbar trigger.
- **Issues**:
  - Spacing above the title is cramped (`EdgeInsets.fromLTRB(16, 8, 16, 0)`), causing the title to visually collide with the collapsing search bar.
  - Subtitle "Personalized on-device · Beta" truncates awkwardly on standard portrait phone widths.

### 3. Sorting & Filter Chips
- **Current Structure**: `_SortBar` renders horizontal `FilterChip` items (Hot, New, Rising, Top, For You).
- **Issues**:
  - Chips use `surfaceContainerLow` with `BorderSide(outlineVariant)`. When selected, the background flips to `primary` with `onPrimary`. While functionally clear, the chips lack expressive pressed animations and subtle elevation changes.
  - The "Top" time selector uses a standard generic modal bottom sheet (`_showTimeSheet`) instead of an expressive dropdown or segmental pill.

### 4. Post List View (`PostListView`)
- **Current Structure**: `ListView.separated` inside `M3ERefreshIndicator`.
- **Issues**:
  - `ListView.separated` specifies `separatorBuilder: (_, __) => const SizedBox.shrink()`. Using a separated list view with an empty separator allocates unused closure frames for every item.
  - Bottom padding is hardcoded to `130dp` to prevent the floating navigation bar from covering the last item. This value is uncoordinated with device bottom insets or minimized nav bar states.
  - Read-post filtering in the "For You" feed triggers an un-indexed linear search (`history.containsId`) on every rebuild.

---

## 6. Post Card and Media System Deep Audit

### Critical Root-Cause Analysis of Media Aspect-Ratio Failures

The issue where post images and videos display with bad proportions, excessive heights, or awkward letterboxing originates from **six distinct, verified root causes**:

```
[Reddit API Payload]
       │
       ├── 1. Unescaped XML entities: "&amp;" in URLs corrupts CDN auth signature
       ├── 2. Video metadata omitted: "reddit_video" width/height ignored in Post.fromData
       ├── 3. Crossposts ignored: "crosspost_parent_list[0]" media/preview omitted
       │
       ▼
[Post Model (models/post.dart)]
  previewWidth = null / corrupted
  previewHeight = null / corrupted
       │
       ▼
[intrinsicMediaAspectRatio (core/media_aspect_ratio.dart)]
  width/height null? ──► FORCES 16 / 9 FALLBACK
       │
       ▼
[PostCard Media Layout (features/feed/post_card.dart)]
       ├── 4. AspectRatio(16/9) + CachedNetworkImage(fit: BoxFit.contain)
       │      ──► Portrait image squeezed into center with large gray side bars
       │
       ├── 5. Capped tall media: SizedBox(height: maxHeight) + BoxFit.contain
       │      ──► Long infographics shrunk into unreadable miniature strips
       │
       └── 6. Mini thumbnails (72x72): fit changed to BoxFit.contain in commit 3bb5d8f
              ──► Rectangular photos letterboxed inside small square thumbs
```

#### Detailed Breakdown of Causes:

1. **Unescaped XML Entities in Preview and Gallery URLs** (`models/post.dart:168, 187, 203`):
   Reddit's API returns image and gallery URLs with XML-encoded ampersands (e.g. `https://preview.redd.it/...jpg?width=640&amp;crop=smart&amp;s=abc123xyz`).
   Unlike `models/reddit_user.dart` and `models/subreddit.dart` which explicitly run `.replaceAll('&amp;', '&')`, `models/post.dart` passes the raw string with `&amp;` to `CachedNetworkImage`. HTTP clients parse `amp;s` as the query parameter key, breaking CDN query authentication and resulting in failed image loads or fallback placeholders.

2. **Omission of Video Aspect-Ratio Dimensions** (`models/post.dart:103-106`):
   When a post is a native Reddit video (`is_video: true`), the preview image object is frequently omitted or only contains a thumbnail. The true dimensions reside in `d['media']['reddit_video']['width']` and `height`. In `Post.fromData`, `previewWidth` and `previewHeight` are populated exclusively from `preview?.width` and `preview?.height`. When `preview` is absent, video dimensions are lost, causing `intrinsicMediaAspectRatio` to fall back to `16 / 9`. Vertical videos (9:16 or 3:4) are thus incorrectly constrained to a 16:9 box.

3. **Blind 16:9 Aspect Ratio Fallback** (`core/media_aspect_ratio.dart:7-11`):
   `intrinsicMediaAspectRatio` unconditionally returns `16 / 9` whenever dimensions are missing. Assuming landscape geometry for unknown mobile media creates massive letterboxing when the downloaded asset is vertical or square.

4. **Inappropriate `BoxFit.contain` in AspectRatio Containers** (`features/feed/post_card.dart:800, 850`):
   In commit `3bb5d8f`, `CachedNetworkImage` was set to `fit: BoxFit.contain`. When an `AspectRatio` box is built from metadata that differs slightly from the bitmap, or when the 16:9 fallback is active, `BoxFit.contain` centers the image with pillarbox or letterbox gaps instead of cleanly filling the container.

5. **Infographic Shrinkage on Capped Tall Media** (`features/feed/post_card.dart:844-849`):
   When media height exceeds `maxHeight`, `PostCard` forces a box of `height: maxHeight` with `BoxFit.contain`. For tall infographics or comics (e.g. 1000x4000), `BoxFit.contain` shrinks the entire image to fit within the height, rendering it as an unreadable narrow sliver in the middle of the card. The correct design behavior is `BoxFit.cover` with `Alignment.topCenter` plus a gradient scrim and an expressive "Tap to expand" badge.

6. **Square Thumbnail Distortion** (`features/feed/post_card.dart:550, 895`):
   In compact/mini cards and link previews, the 72x72 thumbnail container was changed to `BoxFit.contain`. Rectangular thumbnails are shrunk with black/gray bars inside the 72x72 box rather than filling the square using `BoxFit.cover`.

### Why Post Cards Feel Visually Weak

1. **Double-Border "Box-in-a-Box" Syndrome**: `PostCard` applies an outline border and 12dp horizontal margin to the card shell, and then applies another `ClipRRect(borderRadius: ShapeTokens.large)` to the media inside `Padding(16, 14, 12, 10)`. The media appears trapped inside nested rounded boxes.
2. **Weak Typography Contrast**: Post titles use `FontWeight.w700` but lack dynamic line height and tight letter spacing. Flairs and metadata pills compete with the title rather than supporting it.
3. **Mismatched Action Bar**: `M3EPostActionBar` has inconsistent container colors (`surfaceContainerHigh` for voting pill vs `surfaceContainerLow` for comment/share/save icons).
4. **Horizontal Scroll Hijack**: Wrapping the action bar in a `SingleChildScrollView` prevents horizontal swipes on `PostCard` from triggering upvote/downvote gestures.

---

## 7. Post Detail Screen Audit

### 1. Header & Post Content
- Community and author metadata are laid out with standard `CircleAvatar` and text columns.
- Media container in `PostDetailScreen._media` (`lines 848-854`) uses `ConstrainedBox(minHeight: 120, maxHeight: maxHeight)` with `Container(color: surfaceContainerLowest)`. It does NOT use `intrinsicMediaAspectRatio` or pre-calculate height, causing severe layout shifts when the image finishes loading.
- Markdown body rendering correctly supports spoiler tags via `interactive_spoiler.dart`, but selftext is not selectable.

### 2. Comment Navigation & Search Stubs (CONFIRMED BUGS)
- **Comment Search** (`lines 112-122`):
  ```dart
  void _scrollToMatch() {
    if (_matchIndices.isEmpty) return;
    _scrollController.animateTo(
      (_scrollController.offset + 260).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
  ```
  The search bar claims to find matching comments, but `_scrollToMatch` ignores the matching comment's position and blindly scrolls 260 pixels down.
- **Top-Level Comment Jump** (`lines 192-202`):
  ```dart
  void _jumpNextTopLevel() {
    if (_flat.isEmpty || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + 280).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
  ```
  The button that claims to jump to the next root comment blindly advances 280 pixels down, regardless of comment depths or heights.

### 3. Comment Card Presentation (`M3ECommentCard`)
- Depth rails (`3.5dp` wide with cyclical scheme accents `cs.primary`, `cs.secondary`, `cs.tertiary`) provide excellent visual hierarchy.
- Surface color is correctly aligned to `colorScheme.surfaceContainer`.
- Collapse state and reply counting (`+$replyCount`) work cleanly.

---

## 8. Discover / Explore Audit

### 1. Misleading Search Experience
- `ExploreScreen` features a prominent search bar with the placeholder `"Search communities and posts"`.
- However, `_search.onChanged` only filters the locally loaded `subscribedSubredditsProvider` list in memory.
- Tapping search or submitting a query does not query Reddit's search API or navigate to `/search`. Users searching for new communities or topics are misled.

### 2. Pseudo "Popular" Section
- The "Popular near you" section simply takes the subscribed subreddits list and sorts it by subscriber count (`popular.take(8)`). It does not fetch trending or popular Reddit communities from `/r/popular` or `/subreddits/popular`.

### 3. Visual Treatment
- `M3EPopularCommunityCard` and `M3ERecentCommunityTile` adhere to M3E tokens well, but the vertical scrolling list feels repetitive and lacks rich subreddit description snippets.

---

## 9. Inbox Screen Audit

### 1. Nested Scaffold & FAB Collision
- `InboxScreen` returns a full `Scaffold` with its own `FloatingActionButton` ("New message", `Icons.edit_rounded`).
- Because `InboxScreen` is hosted within `HomeShell`, this nested FAB is rendered in the bottom right corner directly over or behind `HomeShell`'s `M3EFloatingNavBar`, making it difficult or impossible to tap without triggering navigation.

### 2. Message Styling
- Message tiles use generic `ListTile` formatting with thin dividers rather than elevated M3E surface containers.
- Unread messages lack a distinct high-contrast accent indicator (such as an active pill or primary container tint).

---

## 10. Profile and Settings Audit

### 1. Account Tab Overload
- `AccountTab` displays `M3EProfileHeader`, followed immediately by the entire embedded `SettingsList`, followed by Custom Feeds.
- Mixing account management, entire application settings, and multireddit creation in a single continuous scroll view creates cognitive overload and poor discoverability.

### 2. User Screen Inconsistency
- `UserScreen` (`lib/features/user/user_screen.dart`) renders user comments using `_ProfileCommentCard` (`lines 126-172`), which wraps content in a standard Material `Card()` with `ShapeTokens.extraLarge` and no depth rails or action buttons. This completely breaks visual parity with `M3ECommentCard`.
- Line 81 defines `onViewProfile: () {}` — an empty closure that renders a non-functional "View profile ›" button on the user's own profile screen.

### 3. Settings Monolith
- `SettingsScreen` (`lib/features/settings/settings_screen.dart`) is 873 lines long and contains 15+ sub-menus inline. It should be partitioned into clean sub-routes or modal panels (Appearance, Feed & History, Media, Notifications, About).

---

## 11. Complete Bug and Quirk Inventory

### Confirmed Bugs (Definite functional or rendering failures)

1. **Unescaped XML entities (`&amp;`) in Reddit media URLs**:
   - *File*: `lib/models/post.dart:168, 187, 203`
   - *Impact*: Corrupts CDN authentication tokens (`amp;s`), causing image loads to fail.
2. **Missing video dimension extraction**:
   - *File*: `lib/models/post.dart:103-104`
   - *Impact*: Video dimensions in `reddit_video` are ignored when `preview` is absent, forcing vertical videos into a 16:9 box.
3. **Stubbed comment search scrolling**:
   - *File*: `lib/features/post/post_detail_screen.dart:115`
   - *Impact*: `_scrollToMatch` blindly scrolls `+260px` instead of locating the matched comment.
4. **Stubbed top-level comment jump**:
   - *File*: `lib/features/post/post_detail_screen.dart:195`
   - *Impact*: `_jumpNextTopLevel` blindly scrolls `+280px` instead of finding the next depth 0 comment.
5. **Square thumbnail letterboxing (`BoxFit.contain`)**:
   - *File*: `lib/features/feed/post_card.dart:550, 895`
   - *Impact*: 72x72 mini thumbnails and link preview images are shrunk with black borders.
6. **Nested Scaffold FAB collision in Inbox**:
   - *File*: `lib/features/inbox/inbox_screen.dart:46-55`
   - *Impact*: New message FAB overlaps and conflicts with `M3EFloatingNavBar`.

### Likely Bugs (High probability edge cases & race conditions)

1. **Crosspost media data loss**:
   - *File*: `lib/models/post.dart:61-110`
   - *Impact*: Does not inspect `crosspost_parent_list[0]`, resulting in blank previews for crossposted media.
2. **Concurrent OAuth token refresh race in `RedditClient`**:
   - *File*: `lib/core/network/reddit_client.dart:50-60`
   - *Impact*: Concurrent 401s trigger multiple parallel `refresh()` requests, risking token revocation.
3. **Explore search query trap**:
   - *File*: `lib/features/explore/explore_screen.dart:148-172`
   - *Impact*: Prompts user to "Search communities and posts" but never searches Reddit's API.
4. **Dead tap handler on Profile header**:
   - *File*: `lib/features/user/user_screen.dart:81`
   - *Impact*: Tapping "View profile ›" on `UserScreen` does nothing.

### Major Visual Inconsistencies

1. **Double-bordered post cards**: Outlined card shell containing an outlined/clipped media container.
2. **Post Detail vs Feed media discrepancy**: Feed uses aspect-ratio box; Post Detail uses unconstrained `minHeight: 120` box with layout jump.
3. **Profile comment card divergence**: `_ProfileCommentCard` in `UserScreen` uses raw `Card` instead of `M3ECommentCard`.
4. **Duplicate New Post triggers on Home**: FAB and top search bar button visible at the same time.
5. **Action bar horizontal scrollbar**: Scroll container intercepts post-card swipe gestures.
6. **Hardcoded 130dp bottom padding**: Fragile spacing across feed, inbox, and explore lists.
7. **Inconsistent chip shapes & states**: Sorting chips, kind filter chips, and flair pills vary in padding, border, and active fills.
8. **Settings screen visual overload**: Full settings list embedded inside the Account tab.

### Interaction Quirks

1. **Action bar scroll vs swipe-to-vote**: Dragging horizontally on the post card action bar scrolls the buttons rather than voting.
2. **Explore search clear vs keyboard dismiss**: Clearing the search query does not unfocus the keyboard.
3. **For You tune sheet double-tap fallthrough**: Mitigated by `TapGuard`, but sheet animation remains slightly abrupt.
4. **Top bar expandable mode toolbar overlay**: Dismissing the toolbar overlay requires tapping outside; back gesture closes the app if not handled.
5. **Notification permission prompt on cold start**: Alerts user on first launch before they have experienced the app.

---

## 12. Priority Classification & Recommended Sequence

### Priority Summary
- **P0 (Blockers & Critical Functional Bugs)**: 
  - Fix `&amp;` unescaping in `post.dart`.
  - Fix video dimension extraction in `post.dart`.
  - Fix thumbnail `BoxFit.cover` regression.
  - Implement real comment index scrolling for search and top-level jump in `post_detail_screen.dart`.
  - Remove nested FAB collision in `inbox_screen.dart`.
- **P1 (Core Feed & Card M3E Completion)**:
  - Redesign `PostCard` to match M3E visual direction (edge-to-edge media option, clean typography, high-contrast surface).
  - Solve infographic/tall media capping with gradient fade + "Tap to expand" badge.
  - Fix `M3EPostActionBar` layout (non-scrolling responsive flex row).
  - Remove duplicate "New Post" button on Home.
- **P2 (Screen Polish & Visual Parity)**:
  - Unify Post Detail media container with feed media logic.
  - Wire Explore search bar to global Reddit search.
  - Replace `UserScreen`'s `_ProfileCommentCard` with `M3ECommentCard`.
  - Separate `AccountTab` settings into dedicated navigation destinations.
- **P3 (Architecture & Polish)**:
  - Split `post_detail_screen.dart`, `reddit_repository.dart`, and `settings_screen.dart`.
  - Tokenize remaining hardcoded dimensions and text styles.

---

## 13. Recommended First Implementation Task

> **RECOMMENDATION**: Begin immediately with **Phase 1: Media Pipeline & Post Card Geometry Hardening**.

### Scope of Task 1:
1. **Unescape `&amp;` in `models/post.dart`** (`_firstPreviewImage`, `_medPreviewUrl`, `_parseGallery`).
2. **Extract `reddit_video` width/height** into `previewWidth`/`previewHeight` in `models/post.dart`.
3. **Eliminate blind 16:9 fallback in `core/media_aspect_ratio.dart`** when dimensions are unknown; implement smart aspect-ratio discovery.
4. **Restore `BoxFit.cover` on square thumbnails** in `post_card.dart` and `compact_post_card.dart`.
5. **Fix capped tall media** in `post_card.dart` (use top-aligned crop with subtle gradient and "Tap to expand" badge instead of shrinking the image).
6. **Add deterministic unit tests** covering all media geometry cases in `test/post_card_test.dart`.

This directly fixes the most visible defects reported by users, restores correct media rendering across the entire application, and lays the rock-solid foundation required for the visual redesign of the post card.
