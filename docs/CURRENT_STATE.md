# Lily for Reddit — Current Development State & Phase Audit

## 1. Executive Status

- **Current Active Branch**: `feat/phase5-performance-hygiene` (Commit `1026fcd`)
- **Main Branch**: `main` (Commit `9b9b7e9` — identical to `feat/phase4-state-consolidation`)
- **Relationship**: The current branch is **1 commit ahead** of `main`, representing the completed implementation of Phase 5 (storage performance hygiene).
- **Working Tree**: Clean (all phase implementations are committed).

---

## 2. Architectural Evolution & Phase Accomplishments

```
[origin/feat/m3e-frontpage-home] (Commit 3bb5d8f)
       │
       ▼
[Phase 1: fix/phase1-interaction-state] (Commit 7c466b8)
  - Decoupled vote presentation from score arithmetic.
  - Controlled presenter pattern in M3ECommentCard.
  - Fixed explore screen link copying & sort header canonical labels.
       │
       ▼
[Phase 2: feat/m3e-tokenize-post-detail] (Commit 4240cf8)
  - Tokenized PostDetailScreen, CommentCard, CommentComposeBar to M3E.
  - Multi-colored 3.5dp depth rails (primary/secondary/tertiary @ 55%).
  - Deterministic container/onContainer avatar color pairs.
  - Enforced AMOLED (#16161C on #000000) card contrast.
       │
       ▼
[Phase 3: feat/phase3-comment-markdown] (Commit d84f449)
  - Restored full markdown rendering for comments.
  - Implemented InteractiveSpoiler (<spoiler>...</spoiler>) tap-to-reveal.
  - Built pre-rendered FlattenedCommentPresentation cache in controller.
  - Kept text selection disabled in comment bodies to avoid breaking spoilers.
       │
       ▼
[Phase 4: feat/phase4-state-consolidation] (Commit 9b9b7e9) ◄── [main]
  - Centralized optimistic interaction mutations for Posts and Comments.
  - Introduced CommentOverridesController (likes, score, saved) with auto-revert.
  - Unified PostOverridesController across feed cards and detail headers.
  - Synchronized interaction state seamlessly across screen transitions.
       │
       ▼
[Phase 5: feat/phase5-performance-hygiene] (Commit 1026fcd) ◄── [HEAD]
  - Introduced DeferredPrefWriter (500ms debounce quiet-window).
  - Coalesced high-frequency SharedPreferences serialization in InteractionVault.
  - Coalesced writes in HistoryStore (view tracking) and InterestStore (affinities).
  - Added flushPersisted() for zero data loss on screen disposal and tests.
```

---

## 3. Deep-Dive: The Five Targeted Refactoring Phases

### Phase 1: Interaction State & Score Handling (`7c466b8`)
- **Problems Addressed**:
  - Tapping upvote or downvote previously caused double score increments or incorrect score toggling due to UI components performing local arithmetic while background overrides were also running arithmetic.
  - In `explore_screen.dart`, link copying failed due to malformed URI parameters.
  - In `subreddit_header.dart`, redundant copy and layout artifacts degraded blueprint fidelity.
- **Key Changes**:
  - Rewrote `M3ECommentCard` as a pure **controlled presenter**: it displays `score`, `voteState`, and `isSaved` passed from its parent and performs zero local math.
  - Extracted canonical `commentSortLabels` in `post_detail_screen.dart` to guarantee sort menus reflect actual controller state.
- **Verification & Test Coverage**:
  - `test/comment_tree_test.dart`: Validated score calculation and controlled presenter events.
  - `test/explore_copy_link_test.dart`: Validated deep link clipboard formatting.
  - `test/post_card_test.dart`, `test/post_detail_sort_label_test.dart`, `test/post_overrides_test.dart`.

---

### Phase 2: Post Detail M3E Tokenization (`4240cf8`)
- **Problems Addressed**:
  - Hardcoded colors, irregular margins, inconsistent radii, and low-contrast borders across `PostDetailScreen`, `M3ECommentCard`, and `CommentComposeBar`.
  - In AMOLED dark mode, comment cards blended into the background without perceptible depth.
- **Key Changes**:
  - Replaced hardcoded color values with strict `Theme.of(context).colorScheme` tokens (`surfaceContainer`, `surfaceContainerHigh`, `primaryContainer`).
  - Added dynamic multi-color depth rails: nested comments dynamically alternate rail colors (`primary`, `secondary`, `tertiary`) with a 3.5dp rounded line.
  - Added deterministic avatar palettes (`_getAuthorAvatarColor`) pairing accessible container and onContainer colors by username hash.
- **Verification & Test Coverage**:
  - Added `test/post_detail_theme_test.dart` (222 lines) verifying token usage, rail colors across depths, and AMOLED contrast ratios.

---

### Phase 3: Comment Markdown & Interactive Spoilers (`d84f449`)
- **Problems Addressed**:
  - Comment bodies were previously rendered as plain text or had broken markdown formatting and unstyled spoiler tags (`>!spoiler!<`).
  - Using `flutter_markdown` with selectable spans caused all custom element builders (spoilers) to be ignored by Flutter.
- **Key Changes**:
  - Created `lib/features/post/interactive_spoiler.dart`:
    - `normalizeRedditSpoilers()` regex replacing `>!text!<` with `<spoiler>text</spoiler>`.
    - `SpoilerInlineSyntax` parsing `<spoiler>` markdown elements.
    - `RedditSpoilerBuilder` rendering `InteractiveSpoiler` widgets.
    - `InteractiveSpoiler` provides tap-to-reveal with smooth animated containers.
    - `buildCommentMarkdownBody()` establishes the single canonical markdown path.
  - Created `flattenedCommentPresentationProvider` in `comments_controller.dart` to pre-render and cache markdown bodies outside the build pass.
- **Verification & Test Coverage**:
  - Added `test/comment_markdown_test.dart` (140 lines) testing spoiler syntax, nesting, and formatting.

---

### Phase 4: State Consolidation (`9b9b7e9` — Current `main`)
- **Problems Addressed**:
  - Post and comment interactions (vote, save, comment count changes) lived in fragmented stores. Returning from a post detail screen to the feed often caused vote states to revert or jump.
  - Network failures during voting left the UI in a desynchronized state.
- **Key Changes**:
  - Created `lib/features/post/comment_overrides.dart` with `CommentOverridesController`:
    - Centralizes `vote()` and `toggleSave()` with optimistic state updates.
    - Automatically captures previous state and rolls back if the network API throws.
  - Enhanced `lib/features/feed/post_overrides.dart` with `PostOverridesController`:
    - Centralized optimistic transitions and revert-on-failure.
    - Unified feed card (`PostCard`) and detail header (`_PostHeader`) on this single source of truth.
- **Verification & Test Coverage**:
  - Added `test/comment_overrides_test.dart` (277 lines) and extended `test/post_overrides_test.dart`.

---

### Phase 5: Storage Performance Hygiene (`1026fcd` — Current `HEAD`)
- **Problems Addressed**:
  - High-frequency user interactions (scrolling through feed items triggering dwell recording in `VisibilityDetector`, voting, viewing posts) triggered immediate synchronous `jsonEncode` and `SharedPreferences` writes of entire maps (hundreds of entries), causing frame drops and main-thread I/O jank.
- **Key Changes**:
  - Created `lib/core/storage/deferred_pref_writer.dart`:
    - Debounces writes with a 500ms quiet window.
    - Guarantees durability via `flush()` on container disposal or screen teardown.
  - Refactored `InteractionVault` (`interaction_vault.dart`):
    - Separate debounced writers for `interactedPosts` and `seenPosts`.
    - Automated pruning of records older than 30 days (`interactionVaultMaxAge`).
  - Refactored `HistoryStore` (`history_store.dart`) and `InterestStore` (`interest_store.dart`):
    - Debounced incremental updates while keeping explicit user clears durable immediately.
- **Verification & Test Coverage**:
  - Added `test/deferred_pref_writer_test.dart` (54 lines) and updated `test/interaction_vault_test.dart` (27 lines).

---

## 4. Unfinished Work, Technical Debt & Operational Risks

### 4.1 The Dual Codebase Anomaly (`app/` Compose module)
- **Status**: Commit `9300786` introduced an entire Kotlin Jetpack Compose Android app in `app/`, alongside root `build.gradle.kts` and root `settings.gradle.kts`.
- **Debt & Risk**:
  - The repository now has two Android build systems: `android/` (the Flutter runner) and `app/` (the Compose app).
  - Android Studio automatically opens the root as an Android project pointing to `app/`, hiding or confusing the Flutter implementation in `lib/`.
  - The Compose app in `app/` has **zero tests**, is not built by CI, and diverged from the Flutter app during Phases 1–5.

### 4.2 CI Test Suite Soft-Fail
- **Status**: In `.github/workflows/debug-apk.yml`, the test execution step is configured with:
  ```yaml
  - name: Run Flutter tests
    id: flutter-test
    continue-on-error: true
    run: flutter test
  ```
- **Debt & Risk**:
  - CI reports build success even when tests fail.
  - This was originally added because the comment test suite was unstable before commit `163a736`. Now that Phases 1–5 have stabilized the tests, this soft-fail creates a regression hazard.

### 4.3 Scalability of SharedPreferences for Persistence
- **Status**: The Flutter app stores seen posts, post interactions (up to 30 days), viewing history, and learned interest weights in `SharedPreferences` via JSON strings.
- **Debt & Risk**:
  - As user history grows over weeks of active browsing, parsing large JSON strings on startup or during container recreation increases memory footprint and parse latency.
  - While Phase 5 successfully eliminated write jank via debouncing, read/deserialization on cold start remains an eventual scaling bottleneck compared to a structured SQLite / Drift / Isar engine.

### 4.4 Reddit API Platform Fragility & Hydra Fallback
- **Status**: Reddit has restricted third-party developer key creation and blocked anonymous `.json` endpoints.
- **Debt & Risk**:
  - The fallback "Hydra" web session mode (`docs/hydra-fallback.md` & `web_login_screen.dart`) violates Reddit's User Agreement and lacks support for media upload leases (cannot post images/galleries/videos via web session mode).

### 4.5 Video Player Recycling in Rapid Feed Fling
- **Status**: Feed videos use `InlineVideo` with `chewie` and `video_player`.
- **Debt & Risk**:
  - During rapid scroll flings across multiple video posts, initializing and disposing native ExoPlayer instances can lead to texture leaks or stutter if the user scrolls faster than player controllers can dispose.
