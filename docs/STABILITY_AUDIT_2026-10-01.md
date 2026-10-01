# Stability audit — 2026-10-01

Baseline: main at `13564115bcbdda21dacdbb021b4873fd3c67b98d` (PR #80).

The three requested fixes are implemented in this branch. The action row uses
36 dp outlines, 20 dp frontpage icons, aligned vote/count/comment controls, and
48 dp vertical interaction regions. It stays on one line; narrow viewports and
large text can scroll the row horizontally. Navigation responds to the first
downward gesture from the top, fades/collapses labels together over 120 ms,
and reveals them over 200 ms. Reduced motion takes effect immediately.

Read-state changes now update the history index before notifying subscribers.
Whole-card press tint is removed from full and mini cards, and read dimming is
painted as a card-local, noninteractive overlay instead of a subtree color
filter. Scrolling and recommender visibility do not create a read overlay.
The pixel regression checks an unread card before a press, during a drag,
after a visibility/dwell signal, and after marking/removing an explicit read
entry. Android device/Impeller verification is still needed for the reported
device-specific brightness symptom.

## Scope and evidence

The review covered the 106 non-generated Dart source modules through route,
request, state, lifecycle, and persistence tracing, with focused inspection of
the risky paths listed below. It also examined Android/iOS configuration and
both APK workflows. Areas covered: authentication and account switching;
home, For You, subreddit and custom feeds; Explore/search; post detail and
comments; vote/save/moderation; profile/saved/history; post/reply/message
composition and uploads; inline/fullscreen media; settings, backups, updates,
and notifications.

Validation: Flutter 3.47.5 / Dart 3.13.4; static analysis reports no issues;
the full regression suite passes all 182 tests. Nine controlled diagnostic
probes reproduce the faulty outcomes listed below. The layout also has a
rendered geometry check using Roboto at normal phone widths.
[Diagnostic probes](stability_audit_probes_test.dart) use controlled responses
and in-memory storage. They assert the existing faulty outcomes to demonstrate
the findings; they are deliberately outside the normal acceptance suite.
Run them explicitly with `flutter test docs/stability_audit_probes_test.dart`.

This audit combines executable reproductions and source-confirmed defects.
Real Reddit credentials, Android/iOS device lifecycle, network outages on a
phone, and architecture-specific APK installation need follow-up testing.

## Findings to tackle next

P1 = release-priority correctness, account isolation, or data-loss problem.
P2 = ordinary functionality or recovery failure. P3 = presentation preference.

| ID | Priority | Finding | Evidence |
| --- | --- | --- | --- |
| B01 | P1 | Rejected HTTP mutations can appear successful | Diagnostic reproduction |
| B02 | P1 | Tapping an active feed vote sends an unsupported zero direction | Diagnostic reproduction |
| B03 | P1 | Private offline responses share cache keys across accounts | Source confirmed |
| B04 | P1 | Vote/save overrides and queued actions survive an account switch | Source confirmed |
| B05 | P1 | Failed backup restore can already overwrite credentials | Diagnostic reproduction |
| B06 | P2 | Old requests overwrite newer feed/search state | Diagnostic reproductions |
| B07 | P2 | Inbox actions discard the pagination cursor | Diagnostic reproduction |
| B08 | P2 | Failed inbox deletion/read changes have no rollback | Diagnostic reproduction |
| B09 | P2 | Comment edits can strand a load-more placeholder | Diagnostic reproduction |
| B10 | P2 | Inline videos pause on exit but fail to resume on re-entry | Source confirmed |
| B11 | P2 | Disabled history still records passive visibility as engagement | Diagnostic reproduction |
| B12 | P2 | Impression timers outlive their store/account; clearing does not cancel pending writes | Source confirmed |
| B13 | P2 | Auto-update chooses the largest split APK rather than the device ABI | Source confirmed |
| B14 | P2 | Picker completion can call setState after the composer closes | Source confirmed |
| B15 | P3 | Navigation-label setting is stored but never read by the nav | Source confirmed |

### B01 — rejected HTTP mutations can appear successful

[`RedditClient`](../lib/core/network/reddit_client.dart) accepts every HTTP
status below 500. After a failed refresh, a 401 also falls through.
[`RedditRepository.vote`, `setSaved`, subscription, inbox, and moderation
methods](../lib/data/reddit_repository.dart) await the response without checking
its status. The interaction layer consequently commits and reports success
for a rejected 403/429 response instead of rolling back.

Reproduce: return HTTP 403 from `/api/vote`; the local vote remains active and
the vault records an upvote. The diagnostic probe demonstrates this without
performing a server mutation. Fix: centralize non-success status/API error
validation, including the final response after authentication retry.

### B02 — tapping an active feed vote sends zero

[`M3EPostActionBar`](../lib/features/feed/post_action_bar.dart) emits zero when
tapping the already-active arrow.
[`PostCard._actions`](../lib/features/feed/post_card.dart) forwards that value
to [`InteractionActions.votePost`](../lib/core/interaction_actions.dart), which
accepts only directional intents `1` and `-1` and resolves toggling itself.

Reproduce: open a feed card with `likes: true`, then tap upvote. Debug builds
raise an assertion. In release mode, zero gets mapped back to the requested
target zero, but the pathway violates the documented directional contract and
does not have valid debug coverage. Fix: use one intent contract at all
callers; cover upvote/unvote, downvote/unvote, and switching directions through
the actual feed and detail controls.

### B03 — private offline cache crosses account boundaries

[`RedditClient._cacheKey`](../lib/core/network/reddit_client.dart) consists only
of path and query. [`ResponseCache`](../lib/core/network/response_cache.dart)
uses one directory, with no account/auth-mode namespace or expiry. Account
reset clears the subscription cache and providers, but leaves disk responses.

Reproduce on a device: load account A's inbox, switch to account B, then go
offline and open the same inbox category. Its fallback cache key is identical
to A's, so A's cached private response can be returned. Fix: namespace private
responses by account and auth mode, isolate in-flight writes, and define
logout/removal retention and expiry behavior.

### B04 — vote/save state and action queues cross accounts

[`resetAccountData`](../lib/features/profile/profile_header.dart) invalidates
feeds, inbox, subscriptions, and custom feeds, but leaves post/comment
overrides and `interactionActionsProvider` alive. Overrides are keyed solely
by Reddit thing ID. `_ActionLane` can also continue draining requests after
the active credentials have changed.

Reproduce: vote/save a post as A, switch to B, and view the same post. A's
override can mask B's server state. With a slow request, queue another vote
and switch accounts before it drains; the shared client can use B's current
credentials for the queued request and record learning in the new account's
store. Fix: scope both presentation overrides and action lanes to an immutable
session/account identity; terminate or bind outstanding work during switches.

### B05 — backup failure can leave partially overwritten credentials

[`BackupService.importBackup`](../lib/features/settings/backup_service.dart)
validates field types, then writes API keys and auth data before finishing
validation of expiry, account entries, and supported preference values.
[`SecureStore.restoreAuthData`](../lib/core/storage/secure_store.dart) can
reject an expiry after several writes have already happened.

Reproduce: import a backup with a different client ID and string expiry
`invalid-date`. The result reports failure, but the client ID has changed.
Null preferences are also accepted by initial validation and rejected during
writing. Fix: validate the entire normalized payload first, snapshot existing
values, and restore them if any commit write fails.

### B06 — late requests replace newer user choices

[`FeedController.loadMore`](../lib/features/feed/feed_controller.dart)
captures an old `FeedState` and writes it after awaiting the network.
Sort changes, refreshes, and account resets have no shared generation guard.
[`SearchScreen._search`](../lib/features/search/search_screen.dart) likewise
has no query/revision token. The same pattern deserves protection in comments
sort/refresh and [`PagedList`](../lib/features/feed/paged_list.dart).

Reproduce: start Hot load-more, select New, finish New first, then finish the
old Hot page. The feed returns to Hot. For search, submit first then second,
return second first, and first last: the text field says second but the list
shows first's results. Both sequences are reproduced in the probes. Fix:
require a current request generation, sort/query/account identity, and live
provider before committing an asynchronous result.

### B07 — inbox mutations discard pagination

[`InboxState.copyWith`](../lib/features/inbox/inbox_controller.dart) always
assigns its nullable `after` argument, even when omitted. `markRead`,
`markUnread`, `deleteMessage`, and `markAllRead` omit it.

Reproduce: load an inbox with a next-page cursor and mark one item read.
`after` becomes null and pagination stops. Fix: distinguish an omitted cursor
from explicitly clearing it, and test each local inbox mutation with a
nonempty cursor.

### B08 — failed inbox actions silently keep optimistic state

[`InboxController`](../lib/features/inbox/inbox_controller.dart) removes
messages or changes read status optimistically and swallows failures.
`markAllRead` can throw after changing all local items. None restores the
previous snapshot or communicates a recoverable failure.

Reproduce: confirm deleting a message with the repository failing offline.
The message disappears locally and reappears after refresh. The delete probe
demonstrates the missing rollback. Fix: use versioned optimistic actions with
rollback/error feedback, preserving unrelated later changes and the cursor.

### B09 — load-more comment replacement depends on object identity

[`CommentsController.loadMore`](../lib/features/post/comments_controller.dart)
replaces a placeholder using `identical(n, moreNode)`. While its request is
pending, `applyEdit`, `insertReply`, or `removeComment` can copy the tree and
replace that object's identity. The successful response then inserts nothing.
Repeated taps can also start overlapping requests for the same placeholder.

Reproduce: begin loading a more node, apply an edit that rebuilds the tree,
then return new comments. The placeholder remains. Fix: match placeholders by
stable identity, guard request generations/sort, and deduplicate outstanding
more-node requests.

### B10 — inline video does not resume after leaving the viewport

[`InlineVideo._onVisibility`](../lib/features/feed/inline_video.dart) pauses
an initialized controller on exit. On re-entry it calls
`_initializeIfVisible`, which returns immediately because `_c != null`.
The existing initialized controller never receives another `play()` call.
Initialization failure also leaves `_initializing` true when `_c` is cleared,
preventing a later retry. URL changes and route/app lifecycle need coverage.

Reproduce: let a video autoplay, scroll away far enough to pause it while the
card stays mounted, then scroll back. Fix: distinguish resume from initialize,
reset failure flags, and manage visibility, route, app lifecycle, and URL
changes together. Verify using a platform video mock and on an Android device.

### B11 — passive visibility is recorded while history is disabled

[`PostCard`](../lib/features/feed/post_card.dart) calls `recordDwell` as soon
as visible fraction reaches 0.6, without checking `trackHistory` or waiting
for dwell time. For You impressions are recorded from build, so cached or
rebuilt cards can count even when not actually viewed. The new brightness
regression verifies these signals stay distinct from read state; the underlying
tracking behavior remains a separate finding.

Reproduce: disable history, render an unread card, and deliver visibility.
The vault still records it as seen. Fix: honor tracking settings consistently,
require meaningful sustained visibility, and record an impression once per
actual exposure rather than every rebuild/batch window.

### B12 — impression timers survive disposal and clear

[`ImpressionStore`](../lib/features/history/interest_store.dart) schedules an
uncancelable `Future.delayed` callback, keeps pending IDs through clear, and
has no disposal guard. Account-dependent rebuilds can change `_key` before an
old batch is flushed; container disposal can leave the callback reading dead
state/ref. Clearing impressions can be undone two seconds later by that batch.

Reproduce: record an impression, clear immediately, then wait two seconds.
The cleared ID can return. Also exercise disposal and an account switch in
that window. Fix: own/cancel the timer, clear pending IDs, and bind batches to
their account key; add lifecycle tests.

### B13 — update downloader guesses architecture from APK size

[`UpdateChecker.check`](../lib/features/updates/update_checker.dart) selects
the largest `.apk`, assuming it is universal. The release workflow publishes
only split `arm64-v8a`, `armeabi-v7a`, and `x86_64` APKs. File size is not an ABI
identifier. The automatically chosen binary can fail to install on the phone.

Reproduce: supply a newer release where the x86_64 split is largest; it becomes
the Android phone's download URL. Fix: select from supported device ABIs with
explicit filename/metadata matching, or offer a chooser/release page when no
compatible asset can be established. Test split-only and universal releases.

### B14 — composer callbacks can update disposed state

[`ComposePostScreen._pickImage`, `_pickGallery`, `_pickVideo`, and
`_insertGif`](../lib/features/compose/compose_post_screen.dart) await external
UI and then call `setState` without checking mounted. Similar attachment
callbacks in reply/message composers deserve the same lifecycle test.

Reproduce: open a picker, remove the composer route while the picker operation
is pending, then complete the selection. Fix: check the current route/state
after awaits and keep cancellation from entering the error callback of a dead
composer. Also protect subreddit flair responses from stale selection races.

### B15 — navigation-label preference has no consumer

[`SettingsList`](../lib/features/settings/settings_screen.dart) exposes and
persists `navLabels`, but [`HomeShell`](../lib/features/home/home_shell.dart)
and [`M3EFloatingNavBar`](../lib/features/navigation/m3e_floating_nav_bar.dart)
never read it.

Reproduce: turn off navigation labels, return home, and remain stationary.
Labels still appear. Fix: feed the preference into nav presentation while
retaining destination semantics and scroll-triggered behavior.

## Recommended next order

1. Unify vote intent and validate HTTP/API mutation failures (B02, B01).
2. Isolate account caches, overrides, and action queues (B03, B04).
3. Make backup restore atomic (B05).
4. Add generation guards and reliable inbox/comment recovery (B06–B09).
5. Fix media lifecycle, tracking timers, update ABI selection, and composer
   lifecycle (B10–B14); wire the label preference (B15).

These findings are reported for the next stability work; their diagnostic
probes should be converted to desired-behavior regression tests as each fix
lands. A green existing suite does not cover these sequences yet.
