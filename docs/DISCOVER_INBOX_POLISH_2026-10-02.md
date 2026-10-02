# Discover and Inbox polish — 2026-10-02

The compact Frontpage header no longer has a Toolbar or Display overflow button. Feed display and autoplay remain in Settings. The saved `expandable` setting remains compatible, but its user-facing name and description now say Compact.

Discover in the floating bottom navigation selects immediately on the first tap. A second tap within Flutter's double-tap timeout opens the existing global search view with keyboard focus. Spaced taps still reselect/scroll to the top. Long press and the accessibility Search Reddit action provide alternate access. Returning from search retains Discover and its state.

Discover places the search dock above Explore, followed by one horizontal Filter/All/Communities/Posts/favorites/sort row. Recently visited communities share a compact rounded panel. Popular communities use narrow portrait cards with centered avatars, membership counts and Join buttons. Sorting offers Recommended, Name and Most members; Joined remains available in the filter sheet. Device color schemes, AMOLED settings and text scaling determine the surfaces, text and controls.

Inbox has one category row: All, Unread, Mentions, Messages, Sent. Its labels and API categories share one definition. The duplicate All/Replies/Mentions/Messages/filter row is removed. Message cards use rounded Material surfaces with working ink feedback, avatar, author/time, subject, body preview and unread dot. Compose sits above the HomeShell's floating navigation inset.

## Additional bugs repaired during this pass

| ID | Trigger and previous behavior | Repair / verification |
| --- | --- | --- |
| D01 | Select Posts, then return from search: the community filter stayed `posts` and rejected every community. | Open post search without changing the community filter; query and return-state regression. |
| D02 | Repeated Join/Favorite taps sent overlapping mutations using the same old flag. | One pending mutation per community; duplicate-Join regression. |
| D03 | Complete a community mutation after account change or screen disposal: it could mutate the new account's visited list or use a disposed ref. | Capture the account epoch and require a mounted, matching session before completion; account-switch and disposal regressions. |
| D04 | Join/Favorite left popular cards stale, and updating a community absent from history had no visible local effect. | Update displayed metadata across recent/popular cards, invalidate both feeds; joined/favorite consistency regression. |
| D05 | A failed popular request appeared as an empty result with no retry. | Show a friendly error and dedicated retry; successful retry regression. |
| D06 | A failed subscribed feed hid successful popular data and recent visits. | Render independent sections and errors; combined subscription/popular-failure regression. |
| D07 | Refreshing a short community list could not pull to refresh, or reused the repository's cached subscription list. | Always-scrollable physics, clear subscription cache, await guarded provider reloads. |
| I01 | Failed swipe-delete restored an Inbox card that Dismissible still considered dismissed. | Let the controller own removal and rollback; failed-delete widget regression plus existing delete-confirmation test. |
| I02 | Inbox's nested Scaffold placed its compose FAB underneath the floating bottom navigation. | Respect the inherited navigation inset; HomeShell geometry and hit-testing regression. |
| I03 | Inbox failures exposed transport exception text and had no retry button; short lists were difficult to refresh. | Friendly retryable ErrorView and always-scrollable error/data lists. |

## Validation

All 340 local tests pass and `flutter analyze --no-pub` reports no issues. Fourteen new regression tests cover immediate/spaced/double/long-press navigation, focused global search and return, category endpoint mapping, mutation races/disposal/state consistency, failed-delete rollback, compose geometry, independent retries and 320/390 dp layouts at 200% text in light/dark themes. Existing navigation, concept, session and delete tests also pass. Final CI results are recorded in PR #83 after execution.

Manual widget renders use real typography and deterministic fake communities/messages. They are previews, not live Reddit or physical-phone screenshots. Android builds are performed by the PR workflow with `--target-platform android-arm64`; local Android compilation is unavailable in this workspace.

## Remaining checks and prior findings

Confirm gesture timing, keyboard/back behavior, touch scrolling, live Reddit joins/favorites, notification delivery and message actions on a phone. The displayed Popular near you title follows the supplied reference; its current source is Reddit's general popular-community endpoint, not device geolocation.

The six previously documented app-wide follow-ups remain open in [POST_POLISH_AUDIT_2026-10-02.md](POST_POLISH_AUDIT_2026-10-02.md): account-owned drafts, notification ownership, corrupt-history recovery, custom-feed lifecycle/errors, failed-hide rollback and post-action dialog/completion lifetimes. This pass does not mark those resolved.
