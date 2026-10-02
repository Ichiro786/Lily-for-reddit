# Final polish and codebase sweep — 2026-10-02

## Requested changes

- Settings no longer exposes the redundant “For You” beta switch, top-bar mode, or its API-usage replacement option. The existing For You feed chip remains available. Saved legacy toolbar preferences no longer restore the obsolete toolbar.
- Double-tapping Discover opens its existing search field, scrolls it into view, and restores the keyboard from Home or an already active Discover tab, including after Android Back dismisses the keyboard while focus remains.
- Inline comments and reply sheets share an expressive, themed attachment menu. One rotating, responsive “+” opens rounded Photo, Video, and GIF actions. Inline send appears only when content is available; next-thread navigation remains accessible in the menu.
- The GIF picker supports configuring and updating the user's key directly, stored through the existing secure store. It includes a developer-dashboard link, attribution, trending/search results, actionable errors, retry, cancellation, debouncing, and keyboard-safe layouts.

GIPHY endpoint/key handling follows the [official API documentation](https://developers.giphy.com/docs/api/) and [response codes](https://developers.giphy.com/docs/api/response-codes/). No app-wide key is bundled. Actual requests with the tester's key still need device validation.

## Refactoring and additional defects fixed

The sweep covered authentication/session boundaries, repository/network callers, feed state and scrolling, posts/comments and media composers, Discover/Inbox navigation, settings/backup/local storage, updates/notifications, and custom feeds. Changes target demonstrated defects and duplicated paths rather than replacing working architecture or upgrading unrelated dependencies.

| Defect | Result |
| --- | --- |
| Feed state updates silently cleared pagination cursors | Omitted cursor values preserve the current cursor; explicit null clears it. |
| One malformed history record broke history loading | Valid records survive corrupt rows; empty IDs are rejected and duplicates removed. |
| Corrupt saved enum indices or out-of-range sliders crashed Settings | Enum reads validate types/ranges; numeric values are finite and clamped. |
| Failed server hide still suppressed posts locally; failed Undo changed local state | Local visibility changes only after successful server operations, with session guards and friendly errors. |
| Programmatic post GIF insertion did not save its draft | Reopening the composer restores the inserted GIF URL and text. |
| Startup update checks could wait indefinitely on networking | Connect and receive timeouts bound the check. |

Inline and sheet reply submission now share image/GIF/video dispatch. Video retains its existing public-link upload path; image MIME types remain intact. Media reads and sends are serialized, controls are disabled during submission, and session changes abort continuation. Duplicate MIME helpers and obsolete toolbar code were removed. Notification-permission continuation now checks widget lifetime.

The picker owns one network client, cancels stale/disposed requests, avoids accessing a disposed composer ref after secure-storage awaits, skips malformed individual results, and distinguishes invalid keys, quotas, malformed responses, and connectivity errors. Search waits 300 ms between edits. Preview decoding is bounded; no new animation/widget dependency was needed.

## Validation

- Full Flutter suite contains 405 tests. Final full-run and CI results are recorded in PR #83. The first run exposed two tests tied to the previous dock/menu implementation; both were updated and passed targeted reruns. A clean run uses the final GIF focus correction together with its expanded regression.
- Static analysis: no issues found.
- Nineteen new regression tests cover key setup/errors/search cancellation, keyboard focus, landscape at 200% text in both themes, media serialization, video/session dispatch, GIF draft restoration, storage corruption, pagination, Settings cleanup, and hide/Undo failures.
- Existing Discover, comment, reply, keyboard-media, and composer lifecycle regressions were checked and adapted to the consolidated controls.
- Four standalone UI rendering checks passed. Light/dark attachment menus and GIF setup were visually inspected with actual Roboto and Material icons. Previews can be regenerated with `flutter test tool/polish_ui_preview_test.dart`.
- `git diff --check` passed.
- Android arm64 debug and optimized test APKs are built by the existing PR workflow; final results are reported in PR #83.

## Remaining follow-ups

These four broader issues remain outside the completed polish changes and need dedicated fixes and regression coverage:

1. **Account-owned drafts:** `lib/core/drafts.dart` namespaces drafts by compose target, without account identity. Account-switch migration and isolation must be designed before changing persisted keys.
2. **Background notification ownership:** `lib/features/notifications/inbox_poller.dart` uses a shared seen-ID preference. Concurrent background polling and account changes need ownership checks and per-account state.
3. **Custom-feed mutation failures:** `lib/features/multireddit/manage_multireddit_screen.dart` lacks consistent error handling and mounted/session checks after add/remove/delete operations; the add dialog controller also needs disposal.
4. **Other post-action dialogs:** report/crosspost and related action-dialog controllers need a full lifetime/account-session pass. Hide/Undo was corrected here; that does not establish correctness for all other actions.

Physical-device 120 Hz frame timing, native keyboard media permissions, real GIPHY credentials, Reddit community media restrictions, and live upload/network behavior remain manual checks. Automated UI tests cannot establish a universal smoothness or flawless-app claim.

This change prepares a test build for personal validation. No 2.0 version, tag, main merge, or production release is part of this stage.
