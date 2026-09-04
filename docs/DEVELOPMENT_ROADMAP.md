# Lily for Reddit — Development Roadmap & Next Steps

This roadmap outlines the recommended, safest development phases for **Lily for Reddit** in strict priority order. Each milestone is designed to be incremental, easily verifiable, and free of breaking changes.

---

## Roadmap Overview

```
[Milestone 1: Phase 5 Finalization & Main Integration]
                         │
                         ▼
[Milestone 2: CI Pipeline Hardening & Regression Shield]
                         │
                         ▼
[Milestone 3: Architecture Clarification (Resolve app/ Duality)]
                         │
                         ▼
[Milestone 4: Feed Scrolling & Video Recycling Hardening]
                         │
                         ▼
[Milestone 5: Offline Action Queueing & Sync Resilience]
                         │
                         ▼
[Milestone 6: Long-Term Persistence Evolution (SQLite/Drift Migration)]
```

---

## Milestone 1: Phase 5 Finalization & Integration into `main` (Immediate)
- **Objective**: Safely integrate `feat/phase5-performance-hygiene` into the `main` branch.
- **Context**:
  - The current branch (`feat/phase5-performance-hygiene`) contains 1 commit (`1026fcd`) ahead of `main`.
  - The working tree is completely clean and tests pass deterministically.
- **Action Steps**:
  1. Verify all unit tests pass locally and in CI.
  2. Create a fast-forward pull request or merge `feat/phase5-performance-hygiene` into `main`.
  3. Tag the resulting release candidate (e.g., `v1.0.1+1002`).

---

## Milestone 2: CI Pipeline Hardening & Regression Shield (High Priority)
- **Objective**: Eliminate the "soft-fail" in CI so regressions are caught before reaching `main`.
- **Context**:
  - `.github/workflows/debug-apk.yml` currently contains `continue-on-error: true` on the `flutter test` step.
  - Comment tests and frontpage builds were stabilized in commits `163a736`, `7c466b8`, and `4240cf8`.
- **Action Steps**:
  1. Remove `continue-on-error: true` from `.github/workflows/debug-apk.yml`.
  2. Add `flutter analyze --fatal-infos` or standard lint verification.
  3. Ensure PR checks strictly block merges if any test in `test/` fails.

---

## Milestone 3: Resolve Dual-Codebase Architectural Duality (High Priority)
- **Objective**: Resolve the coexistence of the standalone Android Compose module (`app/`) and the Flutter project (`lib/` + `android/`).
- **Context**:
  - In commit `9300786`, an experimental Kotlin Jetpack Compose app was committed into `app/`, with root-level Gradle files (`build.gradle.kts`, `settings.gradle.kts`, `gradle/libs.versions.toml`).
  - This confuses Android Studio / IDE project imports, as the IDE attempts to build `:app` instead of the Flutter Android embedding in `android/`.
- **Action Steps**:
  1. Align with repository maintainers on the strategic direction:
     - **Option A (Recommended)**: Move the experimental Compose app to a dedicated branch (e.g., `experiment/native-compose`) or standalone repository, restoring root Gradle files to standard Flutter defaults.
     - **Option B**: Maintain `app/` in a dedicated subfolder with isolated Gradle settings so opening the workspace defaults cleanly to the Flutter project.

---

## Milestone 4: Feed Scrolling & Video Recycling Hardening (Medium Priority)
- **Objective**: Prevent video player thrashing and texture exhaustion during rapid fling scrolling.
- **Context**:
  - In `lib/features/feed/post_card.dart` and `inline_video.dart`, inline videos automatically initialize when visible via `VisibilityDetector`.
  - During rapid fling scrolling across multiple video posts, initializing and disposing native ExoPlayer instances can lead to memory pressure and minor stutter.
- **Action Steps**:
  1. Introduce a short velocity threshold or debounce (~150ms of quiet scroll) before instantiating native video controllers in `InlineVideo`.
  2. Ensure backgrounded or scrolled-off video controllers release hardware decoders immediately.
  3. Validate using DevTools CPU and memory profilers during aggressive scroll benchmarks.

---

## Milestone 5: Offline Action Queueing & Sync Resilience (Medium Priority)
- **Objective**: Preserve user actions (votes, saves, mark-as-read) executed while network is offline or unstable.
- **Context**:
  - Currently, `PostOverridesController` and `CommentOverridesController` perform optimistic updates, but if the network call fails, they immediately roll back to the prior state.
  - If a user loses connection in an elevator or subway, their votes and saves are lost.
- **Action Steps**:
  1. Create an `OfflineActionQueue` stored in local preferences.
  2. If an optimistic action encounters a network connection error, stage the mutation in the queue instead of immediately reverting.
  3. Replay queued actions when `RedditClient` detects restored connectivity or on app resume.

---

## Milestone 6: Long-Term Persistence Evolution (Low Priority / Future)
- **Objective**: Migrate high-volume data structures from `SharedPreferences` JSON blobs to an embedded database (SQLite via `sqflite` or `drift`).
- **Context**:
  - `InteractionVault` currently stores 30 days of seen posts and interaction flags as JSON strings in `SharedPreferences`.
  - `HistoryStore` stores viewing history as JSON.
  - Phase 5 eliminated write-frequency overhead via `DeferredPrefWriter`, but cold-start JSON deserialization could still scale unfavorably for power users.
- **Action Steps**:
  1. Introduce `drift` or `sqflite` for relational storage of seen posts and history.
  2. Implement an automated one-time migration from `SharedPreferences` to the database on first launch.
  3. Keep the public API of `interactionVaultProvider` and `historyControllerProvider` identical so UI and ranking layers require zero changes.
