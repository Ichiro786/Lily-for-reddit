# Lily for Reddit — Development Roadmap & Next Steps

This roadmap outlines the completed architectural milestones and future engineering priorities for **Lily for Reddit**.

---

## 1. Completed Engineering Milestones

```
[Phase 1: Post Detail Visual Modernization] ──► COMPLETED (Commit 7400db0)
[Phase 2: Comments, Spoilers & Markdown]   ──► COMPLETED (Commit a348314)
[Phase 3: Profile & Appearance Redesign]   ──► COMPLETED (Commit c94ae3a)
[Phase 4: Explore & Search Modernization]  ──► COMPLETED (Commit 98e826d)
[Phase 5: Inbox Screen Modernization]      ──► COMPLETED (Commit 6354a10)
[Phase 6: Parametric Refresh Indicator]    ──► COMPLETED (Commit 0c901b5)
[Phase 7: Release Automation & PR Hygiene] ──► COMPLETED (Commit c3a8f15)
```

### Phase 1: M3E Post Detail Visual Modernization (Completed)
- 1:1 blueprint alignment with `1000038223.png`: flat canvas header, 24dp rounded media, tonal rich link previews, stickied pin badges, and tonal sort capsule chips.
- 100% strict test coverage in `test/post_detail_m3e_test.dart`.

### Phase 2: Comments, Interactive Spoilers & Markdown Polish (Completed)
- Canonical M3E markdown stylesheet in `interactive_spoiler.dart`.
- Tonal segmented capsule vote controls on comment cards.
- Bottom sheet overflow menu (Copy, Share, View Profile).
- Pre-rendered Markdown AST caching in `flattenedCommentPresentationProvider`.

### Phase 3: Profile & Appearance Modernization (Completed)
- 1:1 blueprint alignment with `1000038216.png` (Right Pane).
- Curated 8-color M3 Expressive seed palette with Bloom Lilac default and high-contrast checkmarks.
- Visual dimming and touch disabled state for manual swatches when dynamic color is active.
- `M3EProfileHeader` embedded atop standalone Settings view.

### Phase 4: Explore & Search Screen Modernization (Completed)
- 1:1 blueprint alignment with `1000038216.png` (Left Pane).
- Persistent `VisitedCommunityStore` with 500ms debounced write coalescing.
- Real Reddit `/subreddits/popular` endpoint querying with fallback active user telemetry.
- Category filter chips, search dock, and live activity dots.

### Phase 5: Inbox Screen Modernization (Completed)
- 1:1 blueprint alignment with `1000038216.png` (Center Pane).
- Top App Bar with mark-all-read icon and 3-dots overflow menu.
- Primary category tabs with rounded underline indicator and secondary filter bar.
- Modern 16dp rounded message cards with monogram avatars and unread indicator dot.
- Preserved PR #74 destructive swipe-to-delete confirmation dialog.

### Phase 6: M3E Dynamic Shape-Morphing Refresh Indicator (Completed)
- Parametric 12-lobed flower geometry (`computeM3EFlowerPath`) using cubic Bézier fillets.
- Smooth morphing from exact circle ($t = 0$) to 12-lobed flower ($t = 1$).
- Dual-mode `M3ELoadingIndicator` (determinate pull progress vs. indeterminate breathing rotation).
- Damped harmonic spring retract physics (`Curves.easeOutCubic` over 240ms).

### Phase 7: Release Automation & PR Backlog Clearance (Completed)
- Configured `.github/workflows/release-apk.yml` for tag pushes (`v*`) and `workflow_dispatch`.
- Automated split-per-ABI packaging (`arm64-v8a`, `armeabi-v7a`, `x86_64`) with SHA-256 checksum generation.
- Closed stale draft PR #39 with explanatory comment.
- Audited and closed superseded draft PRs #26 and #31, achieving **0 open PRs**.

---

## 2. Future Engineering Milestones

```
[Milestone 8: Production Release Tagging & Release Verification]
                         │
                         ▼
[Milestone 9: Tablet, Foldable & Large-Screen Adaptive Layouts]
                         │
                         ▼
[Milestone 10: Offline Action Queueing & Reconnection Replay]
                         │
                         ▼
[Milestone 11: Relational Persistence Migration (Drift/SQLite)]
                         │
                         ▼
[Milestone 12: Community Feedback & Telemetry Optimization]
```

### Milestone 8: Production Release Tagging (Immediate / Next)
- **Objective**: Publish the modernized application as a formal GitHub release.
- **Action Steps**:
  1. Tag release `v1.0.2` on `main`.
  2. Verify automated `.github/workflows/release-apk.yml` execution.
  3. Confirm split-per-ABI APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`) and `checksums-sha256.txt` are attached to the release assets.

### Milestone 9: Tablet, Foldable & Large-Screen Adaptive Layouts (High Priority)
- **Objective**: Provide an optimized two-pane experience for foldable phones, tablets, and desktop form factors.
- **Action Steps**:
  1. Introduce a master-detail split layout when screen width exceeds 720dp (feed on left, active post/comments on right).
  2. Adapt bottom navigation dock into an M3E Navigation Rail for landscape and large screens.
  3. Ensure comment compose dock anchors properly in dual-pane setups.

### Milestone 10: Offline Action Queueing & Reconnection Replay (Medium Priority)
- **Objective**: Prevent lost user interactions when voting or saving posts with intermittent or offline connectivity.
- **Action Steps**:
  1. Create an `OfflineActionQueue` backed by local storage.
  2. Stage failed optimistic mutations in the queue when network errors occur rather than immediately rolling back.
  3. Automatically flush and replay queued mutations when network reachability is restored.

### Milestone 11: Relational Persistence Migration (Medium Priority)
- **Objective**: Transition high-volume data structures from JSON blobs to structured local storage.
- **Action Steps**:
  1. Migrate `InteractionVault` (seen posts, interaction records) and `HistoryStore` to an embedded relational database (e.g. `drift` or `sqflite`).
  2. Provide a seamless, one-time data migration from `SharedPreferences` on app upgrade.
  3. Keep provider APIs identical to avoid ripples in UI or scoring components.

### Milestone 12: Community Feedback & Telemetry Optimization (Ongoing)
- **Objective**: Gather real-world user feedback on M3 Expressive typography, contrast, and animation performance across diverse Android devices.
- **Action Steps**:
  1. Collect opt-in frame drop metrics and scroll performance data.
  2. Iterate on contrast ratios, font scaling preferences, and animation durations based on user reports.
