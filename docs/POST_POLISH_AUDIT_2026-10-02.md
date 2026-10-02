# Post polish and follow-up audit — 2026-10-02

This pass builds on draft PR #83 and the earlier 15 stability fixes. It covers
the supplied device screenshots, post/detail search, comment controls, reply
Markdown/media, account startup and transitions, and adjacent failure paths.
Automated reproductions and source findings are distinguished below.

## Implemented and checked

| ID | Finding | Repair and executable evidence |
| --- | --- | --- |
| P01 | Top-bar search takes space from the title. | Remove the icon; double-tap the title to open a rounded, themed search dialog with autofocus and expressive/reduced-motion timing. Post options retain an accessible Search comments entry. `post_concept_test.dart` exercises both paths, distant selection and tree changes. |
| P02 | A wide score/text pushes Save onto a separate line. | Pin Save at the end of the action row; let voting/Reply/overflow scroll on narrow screens. `reply_polish_test.dart` checks its baseline, 48dp target and tap at 200% text in both directions. |
| P03 | Spoiler preprocessing rewrites code examples and escaped markers. | Parse native markers through Markdown syntax, before the blockquote rule for valid standalone spoilers. Code and escaped examples stay literal. |
| P04 | Revealed spoilers lose Markdown formatting and can show encoded entity text. | Keep the original payload and render rich revealed content through the canonical comment renderer. Links, formatting and media retain their behavior. |
| P05 | Reused spoiler widgets can show replacement text without a new reveal. | Reset reveal state when the payload changes. Replacement-body regression passes. |
| P06 | Fixed-length code regexes miss long/unclosed fences, indented code and multi-backtick spans. | Protect source slices using fence width, quoted/list fence prefixes, indented lines and exact inline delimiter runs. Such media/token examples are neither fetched nor replaced. |
| P07 | Trimming the first line destroys indented-code meaning. | Remove blank leading lines and trailing whitespace while retaining leading code indentation. |
| P08 | Media links with parentheses, angle destinations or titles are mangled. | Scan balanced syntax and use CommonMark nodes to resolve destinations; preserve formatted captions. Regression covers titled and parenthesized URLs. |
| P09 | Reference-style images leave dangling text and unused definitions can become attachments. | Resolve reference names with the Markdown document; protect definitions from URL extraction. Only actual references create attachments. |
| P10 | URL stripping loses punctuation; GIF tokens are reordered before earlier images. | Scan in source order, deduplicate normalized URLs and retain punctuation outside the consumed destination. |
| P11 | Literal sentinel names can be replaced with unrelated protected text. | Transform original source slices; eliminate placeholder substitution. Code/escaped emote and literal-name regressions pass. |
| P12 | Relative Reddit links fail; invalid destinations and launcher failures escape the rendering path. | Resolve relative permalinks, validate destinations, fall back from unavailable in-app browsers, and return failure with link feedback. Unsupported Markdown images retain alternative text instead of invoking an arbitrary image loader. |
| P13 | Raw search snippets can reveal spoilers. | Found while implementing the dialog: mask hidden spoilers before matching/display and strip formatting/media URLs for readable snippets. No preview fetches attachments. |
| P14 | Explore can start during auth changes and retain an Account changed cancellation. | Wait for initial auth, skip requests during transitions, rebuild repositories after transition completion, and invalidate client config on identity changes instead of every auth-state emission. Guests do not query subscriptions. Startup/same-account/stale-response/guest regressions pass. |
| P15 | Explore's failure view exposes transport details and has no retry. | Render friendly copy and a functional Retry button. Widget regression fails the first request, retries successfully, and checks that Dio details are absent. |

The parser also adds native Reddit superscript and community/user mentions,
retaining GitHub-flavored tables, task/nested lists, formatting and scrollable code.
Comment content parses attachments/text together once. Search results use
comment identity when resolving their final scroll index; the modal owns its
controller through dismissal, avoiding route/controller lifetime coupling.

## Double-check and final review

After the repairs, rechecked source ownership and failure paths, then reran the
application suite and static analysis. The follow-up adds 18 regression cases:
13 parser/layout cases, four Explore lifecycle/retry cases, and one menu-access
case. The earlier search tests now exercise the dialog and identity-based selection.
Exact suite, analysis and arm64-v8a build results are recorded on PR #83.

The review traced code/escape boundaries, media source ordering and references,
hidden-spoiler access, tree mutations while searching, dialog dismissal,
48dp hit regions, large-text/RTL layouts, auth initialization, same-identity
transitions, guest subscriptions, late account responses, retry and repository
subscription caching. It also revisited drafts, notifications, history,
custom feeds and post-option actions rather than assuming a green suite
establishes that every app path is bug-free.

## Remaining source-confirmed follow-ups

| ID | Priority | Evidence and next action |
| --- | --- | --- |
| F01 | P1 | `lib/core/drafts.dart` still uses global `draft_<target>` keys. Bind drafts and successful-submit cleanup to an immutable account identity; define a legacy migration policy. Previously reported, still open. |
| F02 | P1 | `lib/features/notifications/inbox_poller.dart` retains global `notif_seen_ids` and does not revalidate account ownership immediately before notification delivery. Scope IDs/payloads and add a final session check, then exercise Android's background isolate. Previously reported, still open. |
| F03 | P2 | `HistoryController.build` decodes every serialized entry without per-entry recovery. A malformed record can prevent history/read-state rendering. Validate backup/import records and retain valid entries when recovering corrupt storage. Previously reported, still open. |
| F04 | P2 | Custom-feed management can use `WidgetRef` after its dialog/request outlives the route, lacks API failure feedback, and does not dispose the add-subreddit controller. Add lifecycle/session guards and retryable errors. Previously reported, still open. |
| F05 | P2 | Post options record local dismissal before `setHidden` succeeds. Failure leaves the For You suppression signal behind; Undo also assumes the current account. Commit the hide signal on success or roll it back safely, and bind Undo to the originating account. Newly confirmed in `post_actions.dart`. |
| F06 | P2 | Report/crosspost dialogs allocate controllers without disposing them. Crosspost completion also pushes a route without checking whether the originating page/session remains current. Give the dialogs owned controller lifetimes and guard late completion before feedback/navigation. Newly confirmed in `post_actions.dart`. |

Recommended order: F01 and F02 for account ownership, F03 for startup/read-state
recovery, then F04–F06 for failed and deferred user actions. These six are not
included in the completed repair claims above.

## Practical limits

No live Reddit credentials or Android/iOS device were available. CI produces a
debug arm64-v8a APK; real decoding, GIF animation, scrolling/frame pacing,
platform pickers and background delivery still need phone validation. Source
inspection is not a live-device reproduction, and this report does not claim
the entire application is flawless.
