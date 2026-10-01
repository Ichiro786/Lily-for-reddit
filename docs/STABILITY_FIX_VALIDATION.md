# Stability fixes and second audit

Baseline: draft PR #81 (`fd6b60a`), with 182 passing regression tests.
PR #81 now includes B01–B05 and is merged into main at `d611d34`.
Its GitHub analysis, 241 tests, and arm64-v8a build passed (run 36840878472).
Each finding is fixed individually, checked with executable regression tests,
then reviewed again for adjacent failures. A final audit follows all 15 fixes.

| Finding | Implementation | Regression / second review |
| --- | --- | --- |
| B02 Vote intent | Directional UI intents; shared layer owns toggling | 36 passing checks; actual feed/detail taps, all initial vote states, toggle/switch, queued rollback. Second review confirmed all callers use the shared directional contract. |
| B01 API failures | Final HTTP/API validation for all verbs; retry failures preserved; async storage errors settle | 37 passing checks. Second review traced every repository mutation and added preparation/refresh failure coverage to avoid hanging requests. |
| B03 Account cache | Account/auth-mode namespace, immutable request key, generation guard, 24-hour expiry; logout/removal purge shared cache | Three cache checks plus 37 API checks pass. Second review checked canonical query order, missing identity, late response/write, legacy payload, clock reversal and clear. Transition-start protection is also covered by B04. |
| B04 Account actions | Session epoch resets overrides/lanes; transitions block new requests and stale headers/results; refresh commits serialize with account activation and bind to original credentials | 69 passing account/API/interaction checks. Second review added delayed-token and delayed-refresh races, stale queue cancellation, pre-write blocking, and nonpersisting background refresh. |
| B05 Backup atomicity | Validate before writing; serialize session changes; snapshot both stores and roll back partial failures | Nine passing regression checks, including malformed auth/preferences, failure after auth writes, preference setter failure, exact rollback and successful export/import. Second review corrected snapshot aliasing and checked removal of newly imported keys. Persistent storage failure during rollback is reported explicitly. |
| B06 Stale requests | Generations protect feed/search/comment/list loads, retries, ranking and pagination; profile lists use account/repository request identity | Eight race checks pass, including an initial-provider-build race. Second review preserves newer local edits when pagination finishes. |
| B07 Inbox cursor | Omitted cursor preserves existing value; explicit null ends pagination | Five checks pass: all four mutations retain pagination and can reach the end. |
| B08 Inbox rollback | Serialize mutations, restore touched items while preserving newer pages, surface failure, cancel old-session work | Six rollback/queue/account checks and 16 inbox/settings checks pass. Second review also guarded stale unread badge requests and refresh/pagination. |
| B09 More comments | Stable placeholder key, duplicate request suppression, sort/generation guard, tree merging and deduplication | Five controlled edit/reply/delete/failure/sort checks plus 16 comment/race checks pass. Second review traced nesting and destination UI loading keys. |
| B10 Video lifecycle | Resume initialized controller; retry failure; dispose replaced URLs; one owner for app/route/visibility playback | Four platform-mock checks pass. Second review found and removed the controller's competing lifecycle resume observer and a URL-change visibility race. Real-device decoder/network testing remains. |
| B11 Passive tracking | One-second sustained visible exposure, tracking/foreground/route/session checks, no build-driven impression | Five visibility tests and four scroll/brightness regressions pass. Second review checks cancellation on disabling tracking and removing the card. |
| B12 Impression timers | Owned timer, pending clear, disposal and session-generation cancellation | Four timer checks pass. Final review also reproduced disposal re-entry in deferred learning/history writers; captured snapshots and immutable account keys fix that adjacent failure. An account-switch test covers pending writes, isolation and return to the original account. |
| B13 Update ABI | Android supported-ABI bridge; explicit ABI filenames or universal fallback; otherwise release page | Three ABI/native-bridge checks and two existing version checks pass. Android compilation is checked in CI. |
| B14 Composer lifecycle | Mounted/revision/kind guards for pickers and GIF; flair revision; shared attachment and reply guards | Six actual composer checks pass. Final review also fixed GIF sheet query/disposal races and captured message/reply dependencies before upload awaits; a delayed GIF-sheet test passes. |
| B15 Label preference | HomeShell combines the stored label preference with scroll visibility | Live preference, fade and destination semantics check passes. |

## Final audit

The batch review and fresh final review are recorded in
[STABILITY_FINAL_AUDIT_2026-10-01.md](STABILITY_FINAL_AUDIT_2026-10-01.md).
Full-suite and CI results are updated there after completion. Passing automated
tests cannot establish that every real-device behavior is perfect.

The completed local full-suite run passes all **290 tests** (182 baseline,
59 B01–B05 checks, and 49 follow-up/audit regressions). The fresh audit reports
four separate source-confirmed follow-ups rather than declaring the app bug-free.
