# Startup measurement (PR 1)

PR 1 adds opt-in startup instrumentation only. It records monotonic timestamps and frame timing logs; it does not defer services, change routing, alter provider behavior, or change feed loading.

## Enable instrumentation

Run a debug or profile build with:

```bash
flutter run --profile --dart-define=LULI_STARTUP_METRICS=true
```

The flag is disabled by default. When disabled, the coordinator does not emit logs, add frame callbacks, or change control flow.

## Read the markers

Filter device logs for `luli.startup`:

```bash
adb logcat -s luli.startup luli.startup.frame
```

The elapsed values are monotonic milliseconds from the Dart startup instrumentation clock. The expected markers are:

| Marker | Meaning |
|---|---|
| `main_entered` | Dart entered `main()`. This is the process-start proxy available from Dart and is not Android TTID. |
| `run_app_called` | The existing pre-`runApp()` initialization completed and `runApp()` is about to be called. |
| `first_flutter_frame` | The first root-app post-frame callback ran. |
| `auth_resolved` | The router observed that the auth provider was no longer loading. |
| `first_feed_item_visible` | The first frontpage post became partially visible through `VisibilityDetector`. |
| `fully_interactive_home` | One post-frame callback after the first visible item marker; this is the current app-level proxy for a usable home screen. |
| `frame build=... raster=...` | Build and raster durations reported by Flutter for frame timing batches. |

The most useful deltas are:

```text
pre-runApp = run_app_called - main_entered
first-frame = first_flutter_frame - run_app_called
auth-resolution = auth_resolved - first_flutter_frame
first-content = first_feed_item_visible - auth_resolved
home-ready-proxy = fully_interactive_home - first_feed_item_visible
```

The marker definitions are intentionally explicit. `first_flutter_frame` is a Flutter callback marker, while Android TTID should be measured independently from the system. `first_feed_item_visible` measures an actual visible frontpage item rather than only provider completion.

## Android launch measurements

Measure cold, warm, and hot starts separately. For a cold-start-oriented measurement, force-stop the package and start the launcher activity:

```bash
adb shell am start -S -W \
  com.bennybar.luli_for_reddit/.MainActivity \
  -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER
```

Record the `ThisTime`/`TotalTime` output and the Android `Displayed` log line as TTID. Compare that with the Dart `first_flutter_frame` marker. A later PR may add a more formal fully-drawn signal if the project needs TTFD reporting; PR 1 deliberately avoids native behavior changes.

## Required scenarios

Capture at least one run for each scenario: logged-out launch, logged-in standard feed, logged-in For You feed with a cold subscription cache, logged-in For You feed with a warm cache, and notification/deep-link launch when available. Record device model, Android version, build mode, network condition, and whether the app process was force-stopped.

## Limitations

The sandbox used to prepare PR 1 does not contain Flutter/Dart tooling or an attached Android device, so timings cannot be collected here. Before comparing PR 1 with later optimization PRs, run the same scenarios on a representative low-end Android device and retain the raw log excerpts.

## PR 2 comparison

PR 2 changes the critical path in one way: `SharedPreferences.getInstance()` remains awaited because the existing `sharedPrefsProvider` override must be available when the root app is built. Analytics initialization, the telemetry-only username/auth-mode lookup, WorkManager initialization, and optional inbox-poll registration now begin from a post-frame callback through `startDeferredStartupServices()`.

Auth/session resolution remains in `AuthController` and the existing router redirect. PR 2 does not add a second auth gate, change login routing, or allow deferred service failures to affect the UI. The expected measurement change is a shorter `run_app_called - main_entered` interval, while `auth_resolved` and feed markers should retain their existing semantics.

For a before/after comparison, collect PR 1 and PR 2 runs under the same device, build mode, account state, network condition, and cache state. Compare these values:

| Metric | Expected PR 2 behavior |
|---|---|
| `pre-runApp` | Should decrease because four optional/telemetry tasks no longer block `runApp()`. |
| `first-frame` | Should remain stable or improve; deferred services must not block the first Flutter frame. |
| `auth-resolution` | Should remain functionally unchanged because `AuthController` still owns session resolution. |
| `first-content` | May move independently of deferred services; use it to detect any unexpected interaction with the initial feed. |
| `home-ready-proxy` | Should remain comparable; investigate any regression before proceeding to PR 3. |

The deferred coordinator logs failures under `luli.startup.deferred` and intentionally treats them as non-fatal. A successful baseline run should also confirm that opted-in inbox polling is still registered after startup and that analytics events continue to be emitted when analytics is enabled.
