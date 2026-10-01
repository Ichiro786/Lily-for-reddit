# Final stability review — 2026-10-01

B01–B05 are merged through PR #81 at `d611d34`. B06–B15 and the audit
corrections are implemented on `sesori/stability-remaining-ten`. The individual
fixes and executable evidence are in [the validation log](STABILITY_FIX_VALIDATION.md).

## Review after the 15-fix batch

Reviewed the final implementations against each original reproduction, then
traced overlapping requests, account changes, deferred persistence, and failed
operations through feed/search/profile lists, comments, inbox and badge,
tracking stores, media, composer attachments, updates and navigation settings.

The review covered positive and rejected HTTP/API results; queued vote/save
actions and token refresh; account-specific offline responses; rollback after
partial backup writes; out-of-order loads and errors; inbox cursor retention
and rollback with a later page; edits/replies/deletes during comment expansion;
duplicate taps; video visibility, route, app lifecycle and URL replacement;
tracking disabled or canceled mid-dwell; impression clear/disposal; ABI filename
selection and the native channel; delayed picker/flair completion; and live
label settings with destination semantics.

Additional corrections found during this review:

- VideoPlayer's built-in resume observer competed with visibility ownership;
  the inline widget now owns playback lifecycle. URL changes also wait for
  visibility of the new detector before starting a replacement decoder.
- The interaction vault used global keys. It now follows account-specific
  learning keys. Pending history/interest/vault writes read captured snapshots
  and immutable keys, avoiding provider re-entry during invalidation/disposal.
- Unread badge requests could write an old count under a new username. The
  request captures its account and generation and is rescheduled after transitions.
- The GIF sheet had its own query/disposal race despite the composer guard.
  It now cancels obsolete requests and guards results/errors. Message/reply
  submission dependencies are captured before attachment upload awaits.

## Fresh final deep review

Repeated the request/credential and storage ownership tracing after those
corrections. Added executable cases for an initial provider load completing
after a manual sort, account switching during pending learning writes, returning
to the first account, GIF sheet cancellation/removal, and hidden navigation
destination semantics. Rechecked media, notification, custom-feed, history and
draft sources for adjacent problems rather than treating a green suite as
proof that the entire app is bug-free.

All 15 originally reported issues have repaired implementations and passing
targeted regressions. The full application suite passes all **290 tests**,
including 49 additional regression cases in this follow-up batch. Local static
analysis reports no issues after final formatting. GitHub/Android CI results
are available through the follow-up pull request and its exact commit checks.

The first merged batch passed all 241 tests and GitHub analysis and produced
an arm64-v8a APK in [run 36840878472](https://github.com/Ichiro786/Lily-for-reddit/actions/runs/36840878472).

## Separate findings for the next pass

These are source-confirmed follow-ups, not claimed live-device reproductions.

| ID | Priority | Finding and next action |
| --- | --- | --- |
| F01 | P1 | `core/drafts.dart` uses global `draft_<target>` keys. A draft written by A can appear after switching to B. Bind drafts and submit cleanup to account identity, with an explicit legacy migration policy. |
| F02 | P1 | Background inbox notification deduplication uses global `notif_seen_ids` and does not recheck the account after fetching before notification delivery. Scope seen IDs and routes to the originating account and verify the session immediately before delivery. Exercise foreground/background isolate switching on Android. |
| F03 | P2 | `HistoryController.build` decodes all stored history strings without per-entry recovery. Malformed stored/backup history can throw while rendering history/read state. Validate serialized history on import and recover valid entries from corrupt storage without silently losing the entire list. |
| F04 | P2 | Custom-feed add/remove/delete handlers lack API error feedback and can use `WidgetRef` after a dialog/request outlives the route. Add current-session/mounted guards, error feedback, and dispose the add-subreddit text controller. |

Recommended next order: draft and notification account ownership, then corrupt
history recovery and custom-feed error/lifecycle handling.

## Practical limits

No live Reddit credentials or Android/iOS device were available for this review.
Automated video tests use the platform interface; decoder failures, real network
loss, Impeller brightness behavior, background notification isolation, and actual
ABI installation still need phone testing. The one-second/60% dwell threshold
and compact controls should also be assessed at large accessibility text scales
and with tall media. No claim of perfect behavior on every device is made.
