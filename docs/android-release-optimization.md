# Android Release Optimization Audit

## Current release configuration

The app module currently defines a single `release` build type with the release signing configuration, but no code shrinking, obfuscation, resource shrinking, or app-specific R8 file. The project uses Android Gradle Plugin 8.9.1 and Gradle 8.12. Debug and profile build types are not customized in the app module.

The application is distributed primarily as a sideloaded APK from GitHub Releases, with an in-app GitHub updater. The repository has no Play-specific publishing configuration, macrobenchmark module, baseline-profile source set, profile installer dependency, or startup-profile generation task.

## Optimizations evaluated

| Optimization | Decision | Reason |
|---|---|---|
| Release R8 code shrinking and obfuscation | Implement now | Standard release-only optimization supported by the current AGP and recommended for final release builds. |
| Release resource shrinking | Implement now | Pairs with code shrinking and can remove resources unreachable from the optimized release graph. |
| Optimized resource shrinking flag | Defer | The repository uses AGP 8.9.1; the newer optimized resource-shrinking pipeline is documented for AGP 8.12 and later. Do not add a flag that the current toolchain does not support. |
| Broad custom keep rules | Defer | No concrete R8 warning or reflection failure has been observed. Broad rules would reduce optimization and hide compatibility problems. |
| Baseline Profile / Startup Profile | Defer | The app lacks profile-generation infrastructure and is distributed mainly by sideloaded APK. Android documents weaker or delayed installation benefits for non-Play channels, so adding the benchmark/profile toolchain speculatively is not justified in this narrow PR. |

The implementation uses the AGP 8.9.1 legacy DSL: `isMinifyEnabled = true`, `isShrinkResources = true`, and the default `proguard-android-optimize.txt` rules plus an intentionally minimal app rules file. Debug and profile behavior remain unchanged.

## Keep-rule and plugin compatibility audit

The Android manifest explicitly declares the Flutter application activity and the `flutter_web_auth_2` OAuth callback activity. Flutter’s generated plugin registrant is referenced by the Flutter embedding. Notification and WorkManager background entry points are Dart VM entry points marked with `@pragma('vm:entry-point')`; R8 does not remove Dart AOT entry points. The notification plugin uses direct platform implementation calls, and the application uses no custom Java/Kotlin reflection or `getIdentifier()` resource lookup.

The app rules file therefore contains no broad `-keep class` pattern. It documents the audit and provides a controlled place for a future narrowly evidenced rule if a release smoke test or R8 diagnostic requires one. Resource shrinking should be checked with the generated `resources.txt` report, especially for manifest-referenced icons and notification resources.

## Baseline-profile feasibility for this distribution path

Baseline Profiles are technically compatible with the current AGP level, but the repository does not yet have a macrobenchmark/profile-generation module or measured user journeys. More importantly, the documented distribution path is GitHub APK download and sideload, not Google Play. Android’s official guidance notes that non-Google-Play distribution channels might not install Baseline Profiles at installation, delaying benefits until background dex optimization. Play internal sharing also does not support them, while the internal testing track does.[1]

PR 7 therefore keeps Baseline Profiles and Startup Profiles out of the implementation. A future profile PR would be justified only after adding a benchmark module, recording representative Flutter startup journeys, and measuring release APK behavior on the actual distribution channels. If Play distribution is added later, the profile decision should be revisited with a channel-specific validation plan.

## Runtime behavior and risk

The code path is unchanged at runtime when R8 preserves the reachable release graph. The main risks are a release-only missing reflective entry point, dynamically loaded resource, or plugin asset. The conservative mitigation is to avoid speculative keep rules, inspect R8 warnings and `resources.txt`, and run a signed release APK smoke test covering cold start, OAuth callback, deep links, notifications, WorkManager registration, media, image picking, sharing, and the in-app updater.

A release build may have harder-to-read stack traces without retracing maps, so the release process should retain `mapping.txt` and use retracing for crash investigation. No startup orchestration, feed logic, notification behavior, or UI code is changed by PR 7.

## Expected impact

R8 can reduce APK/Dex size and remove unreachable code, which can reduce memory pressure and improve execution efficiency. Resource shrinking can reduce the release artifact further. The exact size and startup delta are device- and dependency-dependent and must be measured from a release build; this PR intentionally makes no unverified numerical claim.

Use PR 1 instrumentation to compare a pre-PR7 release artifact against the PR7 release artifact under the same device and account conditions. Capture cold and warm launch, `first-frame`, `auth-resolution`, `first-content`, and `home-ready-proxy`. Also record APK size, installed size, R8 warnings, `mapping.txt`, and `resources.txt`. Treat any startup regression or functional smoke-test failure as a release blocker.

## References

[1]: https://developer.android.com/topic/performance/baselineprofiles/overview "Android Developers — Baseline Profiles overview"

[2]: https://developer.android.com/topic/performance/app-optimization/enable-app-optimization "Android Developers — Enable app optimization with R8"

[3]: https://developer.android.com/topic/performance/app-optimization/customize-which-resources-to-keep "Android Developers — Customize which resources to keep"
