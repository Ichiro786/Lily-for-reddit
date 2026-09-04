# Baseline Verification & Architectural Decision Record

## 1. Executive Baseline Determination

**The intended production application is unequivocally the Flutter application located in `lib/`.**

The Kotlin Jetpack Compose project located in `app/` is an unmaintained experimental prototype generated via AI Studio (`com.aistudio.lilyforreddit.app`), committed in `9300786` (`feat/m3e-post-detail-refactor`), and completely abandoned in subsequent development.

---

## 2. Comprehensive Evidence Audit

### 2.1 GitHub Actions Workflows
- Both CI/CD workflows ([`.github/workflows/debug-apk.yml`](file:///c:/Users/iramf/Lily-for-reddit/.github/workflows/debug-apk.yml) and [`.github/workflows/release-apk.yml`](file:///c:/Users/iramf/Lily-for-reddit/.github/workflows/release-apk.yml)) build **exclusively the Flutter application**:
  - Run `flutter pub get`, `flutter analyze`, and `flutter test`.
  - Read versioning from [`pubspec.yaml`](file:///c:/Users/iramf/Lily-for-reddit/pubspec.yaml).
  - Execute `flutter build apk --debug` and `flutter build apk --release --split-per-abi`.
  - Produce release artifacts from `build/app/outputs/flutter-apk/app-*-release.apk`.
- **Zero references** to `app/`, Gradle `:app`, or Kotlin compilation exist in CI.

### 2.2 Project Documentation & Manifests
- **[`README.md`](file:///c:/Users/iramf/Lily-for-reddit/README.md)**: Explicitly defines the app as:
  > *"A fast, modern Reddit client for Android, built with Flutter and a Material 3 Expressive design."*
  > Build instructions specify: `flutter pub get`, `dart run build_runner build`, `flutter build apk --release`.
- **[`docs/`](file:///c:/Users/iramf/Lily-for-reddit/docs/)**: All engineering RFCs (`android-release-optimization.md`, `hydra-fallback.md`, `startup-measurement.md`) document Flutter Dart architecture, Dart VM `@pragma('vm:entry-point')`, `flutter_web_auth_2`, and Flutter startup metrics.
- **[`pubspec.yaml`](file:///c:/Users/iramf/Lily-for-reddit/pubspec.yaml)**: Governs package version `1.0.1+1001` and the full production dependency tree.

### 2.3 Commit History & Active Development Path
- **Commit `9300786` (`feat/m3e-post-detail-refactor`)**: Introduced `app/` along with root `build.gradle.kts` and root `settings.gradle.kts`, accidentally deleting `pubspec.lock`, `debug.keystore`, and launcher assets.
- **Immediate Reversion/Fix in `163a736`**: The developer had to immediately fix the Flutter Android runner and restore `android/app/debug.keystore` to unbreak CI.
- **All 15 subsequent commits** (including `3036cbb`, `3bb5d8f`, and Phases 1 through 5: `7c466b8`, `4240cf8`, `d84f449`, `9b9b7e9`, `1026fcd`) modified **only** `lib/`, `test/`, and `android/app/`.
- The `app/` directory has received **zero commits** and zero maintenance since its initial addition.

### 2.4 Application IDs & Release Configuration
| Property | Flutter Android Runner (`android/app/`) | Compose Prototype (`app/`) |
|---|---|---|
| **Namespace** | `com.bennybar.luli_for_reddit` | `com.example.lilyforreddit` |
| **Application ID** | `com.bennybar.luli_for_reddit` | `com.aistudio.lilyforreddit.app` |
| **Signing Configs** | Production release & CI release keystores | Hardcoded `${rootDir}/debug.keystore` |
| **Optimization** | R8 Minify + Resource Shrinking enabled | `isMinifyEnabled = false` |
| **Version Code** | Inherited from Flutter (`flutter.versionCode`) | Hardcoded `versionCode = 1` |

### 2.5 Origin of `app/`: Accidental AI Studio Artifact
- File [`metadata.json`](file:///c:/Users/iramf/Lily-for-reddit/metadata.json) at the root contains:
  ```json
  {
    "name": "Lily for Reddit",
    "majorCapabilities": ["MAJOR_CAPABILITY_SERVER_SIDE_GEMINI_API"]
  }
  ```
- Application ID `com.aistudio.lilyforreddit.app` confirms that `app/` was an AI Studio code generation export checked in during an experimental prompt session.

---

## 3. Recommended Action

### **Recommendation: Option B (Remove/archive the Compose prototype from the main development path)**

#### Rationale:
1. **Tooling & IDE Conflict**: Root `settings.gradle.kts` includes `:app`. When developers or IDEs (such as Android Studio) open the repository, Gradle treats the root as a native Android Compose project instead of a Flutter project.
2. **Dead Code & Drift**: `app/` contains ~7,100 lines of uncompiled, untested code that is already out of sync with Phases 1–5 (missing interaction state consolidation, comment markdown, M3E tokenization, and debounced persistence).
3. **Preservation without Pollution**: The code can be branched to `archive/compose-prototype` or preserved in Git history. Removing `app/`, root `build.gradle.kts`, root `settings.gradle.kts`, and `gradle/` restores the repository to a clean, canonical Flutter workspace where `android/` is the sole Android host.

---

## 4. Phase 5 (`feat/phase5-performance-hygiene`) Merge Verification

### 4.1 Git Status & Delta
- **Current Branch**: `feat/phase5-performance-hygiene` (Commit `1026fcd`).
- **Base Branch**: `main` (Commit `9b9b7e9`).
- **Distance**: Exactly **1 commit ahead**, 0 commits behind. Fast-forwardable with clean working tree.

### 4.2 Exact Diff Analysis
The commit modifies 6 files:
1. **[`lib/core/storage/deferred_pref_writer.dart`](file:///c:/Users/iramf/Lily-for-reddit/lib/core/storage/deferred_pref_writer.dart) (NEW)**:
   - Reusable debounce utility with a 500ms quiet window.
   - Guarantees durability on container disposal and tests via `flush()`.
2. **[`lib/core/storage/interaction_vault.dart`](file:///c:/Users/iramf/Lily-for-reddit/lib/core/storage/interaction_vault.dart)**:
   - Replaces immediate unawaited SharedPreferences disk writes on dwell/vote with coalesced writers.
   - Prunes records older than 30 days automatically.
3. **[`lib/features/history/history_store.dart`](file:///c:/Users/iramf/Lily-for-reddit/lib/features/history/history_store.dart)**:
   - Coalesces 500-entry history list serialization on view tracking.
   - Explicit `clear()` remains immediately durable.
4. **[`lib/features/history/interest_store.dart`](file:///c:/Users/iramf/Lily-for-reddit/lib/features/history/interest_store.dart)**:
   - Coalesces interest weight updates on `bump()`.
   - Explicit `reset()` remains immediately durable.
5. **[`test/deferred_pref_writer_test.dart`](file:///c:/Users/iramf/Lily-for-reddit/test/deferred_pref_writer_test.dart) (NEW)**:
   - Verifies burst coalescing (25 events → 1 write), immediate flush behavior, and cancellation.
6. **[`test/interaction_vault_test.dart`](file:///c:/Users/iramf/Lily-for-reddit/test/interaction_vault_test.dart)**:
   - Verifies dwell burst deferral and cross-container durability post-flush.

### 4.3 Semantic Correctness & Regression Audit
- **In-Memory State Integrity**: All state mutations (`state = ...`) remain **strictly synchronous and immediate**. The UI, `FeedRanker`, and query methods (`isSeen()`, `shouldSuppress()`, `weightFor()`) read current data without any delay.
- **Disposal Safety**: Closures capture `SharedPreferences` instances directly. When a Riverpod container is disposed, `flush()` completes durability without attempting to read through disposed container refs.
- **Contract Compatibility**: No public APIs were altered or broken.

### 4.4 Merge Safety Verdict
**VERDICT: SAFE TO MERGE.**
Commit `1026fcd` is fully self-contained, introduces zero regressions, provides automated test coverage, and resolves an active performance bottleneck (UI thread frame-drops during feed scrolling).
