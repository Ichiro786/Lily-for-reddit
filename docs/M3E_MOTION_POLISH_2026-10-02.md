# Focus, menus, navigation and loading polish — 2026-10-02

Discover search and the inline comment composer use one filled outer pill with an unfilled, explicitly borderless inner input in every border state. Flutter merges missing InputDecoration properties from the app theme; the previous primary-colored focused OutlineInputBorder became white on grayscale device schemes. The global filled-input focus style also keeps its existing surface and shape without adding a stroke. Error feedback remains available through the device color scheme.

PopupMenuButton, MenuAnchor and DropdownMenu share a 16dp rounded shape, surfaceContainerHigh and transparent surface tint through AppTheme. Existing post-detail menus already have larger rounded shapes. No popup menu uses an explicit square shape in the current app.

## Navigation motion

Destination selection remains immediate. Each destination compresses to 95% during a press, then returns with a bounded spring (maximum 103%). Haptics, ink feedback, double-tap Discover search, long press and its accessible Search action remain available. Newly selected tabs enter with a short 180ms ease-out fade; previously initialized tabs retain their state and scroll position.

Downward scrolling starts the 120ms label collapse immediately. The bar waits until about 168ms, then slides below the screen, completing its exit at 420ms. On upward scrolling, the shell waits 64ms, starts the 460ms reverse motion, reveals icons during entry and finally restores labels over 200ms. Reversing direction interrupts the same controller rather than queueing independent animations. Idle events preserve a pending reveal; downward reversal cancels it. Nested and horizontal scrollers do not control this motion. At the top or when selecting a tab, navigation returns immediately to its visible target.

The navigation footprint stays constant throughout this animation. The feed extends under it, so hiding chrome does not repeatedly resize the body or shift post positions. Chrome notifications rebuild the floating controls and optional top toolbar rather than reconstructing the entire frontpage feed. Hidden controls stop their tickers and leave hit testing and accessibility traversal. Reduced-motion settings make state changes immediate and disable spring/continuous shape animations.

## Loading and refresh

The pinned [material3_expressive_loading_indicator 0.1.2](https://pub.dev/packages/material3_expressive_loading_indicator) supplies seven rounded polygon morphs. Its [source](https://github.com/priyanshupatra02/material3_expressive_loading_indicator) was inspected before integration. The app wrapper scales the library's canonical 48dp canvas for small buttons, passes the device theme's primary color and removes its periodic animation timers from inactive tabs or reduced-motion contexts. This avoids changing the application's theme system or introducing platform plugins.

All indeterminate CircularProgressIndicator and standard RefreshIndicator usages now use the shared morphing loader/refresh wrapper, including feed, Discover, Inbox, search, comments, compose and account lists. The media download's determinate percentage ring remains a progress display. Feed initialization uses one morphing loader and lazily constructed static placeholders instead of five simultaneous shimmer animations. Gesture progress still blooms a pull-controlled flower, switching to the continuous polygon sequence while the refresh request runs and retreating smoothly afterward.

## Additional behavioral fixes

| Trigger | Previously observed behavior | Repair and regression evidence |
| --- | --- | --- |
| Switch away from a tab with inline video | Offstage/TickerMode did not pause the native player immediately. | Playback eligibility includes the tab's TickerMode; fake-platform test verifies pause, resume and reuse of one decoder. |
| Ballistic overscroll or a nested vertical scroller | Could drive the outer refresh indicator without a user pull. | Only depth-zero vertical drag notifications arm refresh; direct notification regression. |
| Pull beyond threshold, then reverse before release | Retained pull extent could trigger an unintended refresh. | Track reverse drag deltas and current overscroll; regression verifies no refresh, then a valid pull still refreshes once. |
| Start a new pull/refresh while the old pull is retreating | Cancelled reset completion could zero the new gesture. | Reset generation guards protect current state; interrupted-reset regression. |
| Reselect Home while the feed is empty/error/loading | No attached data-list controller caused an early return without refreshing. | Reselect requests refresh even without that controller; empty-feed regression. |
| Return a scrolled feed to top with reduced motion | A zero-duration scroll animation is invalid. | Jump directly to the top; reduced-motion feed regression. |

## Validation and limits

Regression coverage includes focused fields in light/dark themes, actual overflow-menu surfaces/shapes, navigation ordering and stable geometry, interrupted motion, spring response, delayed reveal and reversal cancellation, inactive/reduced-motion loader teardown, refresh reversal/reset interruption and native-video pause/resume. Existing large-text, Markdown, session, media, post layout and navigation tests are included in the complete suite. Final counts and exact-revision CI/build links are recorded in PR #83.

Widget previews use real fonts and deterministic fixtures. Focused Discover/comment fields and open Inbox menus were inspected in light/dark modes. They are widget renders, not physical-phone screenshots. There is no Android SDK or connected phone in this workspace, so the arm64-v8a APK is built by GitHub Actions. Physical-device profile-mode frame measurements, live GIF/video scrolling, keyboard transitions and gesture feel still require a phone; automated tests do not establish a universal frame-rate guarantee.

The six prior app-wide follow-ups in [POST_POLISH_AUDIT_2026-10-02.md](POST_POLISH_AUDIT_2026-10-02.md) remain open. This pass addresses the requested visual/motion issues and the concrete scrolling/refresh defects above.
