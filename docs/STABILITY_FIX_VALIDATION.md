# Stability fixes and second audit

Baseline: draft PR #81 (`fd6b60a`), with 182 passing regression tests.
Each finding is fixed individually, checked with executable regression tests,
then reviewed again for adjacent failures. A final audit follows all 15 fixes.

| Finding | Implementation | Regression / second review |
| --- | --- | --- |
| B02 Vote intent | Directional UI intents; shared layer owns toggling | 36 passing checks; actual feed/detail taps, all initial vote states, toggle/switch, queued rollback. Second review confirmed all callers use the shared directional contract. |
| B01 API failures | Final HTTP/API validation for all verbs; retry failures preserved; async storage errors settle | 37 passing checks. Second review traced every repository mutation and added preparation/refresh failure coverage to avoid hanging requests. |
| B03 Account cache | Account/auth-mode namespace, immutable request key, generation guard, 24-hour expiry; logout/removal purge shared cache | Three cache checks plus 37 API checks pass. Second review checked canonical query order, missing identity, late response/write, legacy payload, clock reversal and clear. Transition-start protection is also covered by B04. |
| B04 Account actions | Session epoch resets overrides/lanes; transitions block new requests and stale headers/results; refresh commits serialize with account activation and bind to original credentials | 69 passing account/API/interaction checks. Second review added delayed-token and delayed-refresh races, stale queue cancellation, pre-write blocking, and nonpersisting background refresh. |
| B05 Backup atomicity | Validate before writing; serialize session changes; snapshot both stores and roll back partial failures | Nine passing regression checks, including malformed auth/preferences, failure after auth writes, preference setter failure, exact rollback and successful export/import. Second review corrected snapshot aliasing and checked removal of newly imported keys. Persistent storage failure during rollback is reported explicitly. |
| B06 Stale requests | Pending | Pending |
| B07 Inbox cursor | Pending | Pending |
| B08 Inbox rollback | Pending | Pending |
| B09 More comments | Pending | Pending |
| B10 Video lifecycle | Pending | Pending |
| B11 Passive tracking | Pending | Pending |
| B12 Impression timers | Pending | Pending |
| B13 Update ABI | Pending | Pending |
| B14 Composer lifecycle | Pending | Pending |
| B15 Label preference | Pending | Pending |

## Final audit

Pending. Live Reddit/device checks will be recorded separately from automated
tests; passing tests alone cannot establish that every real-device behavior is
perfect.
