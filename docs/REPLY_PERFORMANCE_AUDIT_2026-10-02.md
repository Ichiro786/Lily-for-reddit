# Reply stability and feed performance audit — 2026-10-02

The reported build was a debug APK. Debug builds include development overhead;
APK size alone does not determine frame smoothness. This pass removes concrete
avoidable work and prepares an AOT, R8/resource-shrunk arm64 test build. It does
not claim measured 120 Hz performance without a physical device trace.

## Findings addressed

| Area | Finding | Result |
| --- | --- | --- |
| Android clipboard | pasteboard 0.2.0 has no Android image implementation; tapping Paste showed MissingPluginException | Native content-URI clipboard channel reads image bytes on a worker, preserves MIME, caps reads at 20 MB; actionable errors replace plugin details |
| Reply entrance | Keyboard autofocus competed with the sheet entrance | Focus follows route animation completion; 300 ms entrance, reduced-motion support |
| Reply viewport | Fixed column could overflow with keyboard and large text | Bounded, scrollable sheet; wrapping attachment and formatting controls |
| Reply editing | GIF insertion appended/reset selection and programmatic edits did not save drafts | Shared selection-aware formatting/GIF insertion; controller listener debounces draft saves and flushes on exit/background |
| Reply lifetime | Caller WidgetRef could outlive its screen | Sheet owns its Consumer ref; repository captured before opening |
| Concurrent actions | Attachment reads and GIF picker could overlap send or repeat | Serialized actions, busy feedback, disabled send while choosing attachments, guarded completion after disposal |
| Send completion | Late completion could remove a newer draft | Clear only the matching sent draft; successful sends do not recreate drafts during disposal |
| Account changes | Open reply could target a changed session | Epoch check before send and after upload; stale results are not returned to the caller |
| Media captions | Code spans or escaped brackets split a Markdown media link before parsing | Whole link label retained, including escaped punctuation and code captions |
| Spoiler privacy | Escaped closing marker could terminate hiding/redaction early | Escape-aware marker matching in media extraction, interactive rendering and search snippets |
| Comment rendering | Media extraction repeated on parent/theme/keyboard rebuilds | Parsed content retained until the body changes; preview uses the same renderer as comments |
| Cached feed cards | Offscreen animations continued to consume work | Per-card TickerMode changes only the animation wrapper with a cached child; visibility callbacks ignore disposed cards |
| Inactive tabs | Passive dwell could complete while a kept-alive tab was inactive | Ancestor TickerMode gates dwell eligibility and cancels pending exposure |
| Seen storage | Retention cutoff recalculated for every entry | One cutoff per update |
| Subreddit initialization | About and posts each displayed a morphing loader | One header indicator while either request is pending, static post skeletons below |

Formatting shortcuts include bold, italic, code and spoiler, with an explicit
themed Markdown preview. No new UI dependency is introduced: the existing
Flutter Material components and pinned expressive loading package cover these
controls. Live Markdown parsing is avoided while typing in the editor.

## Verification and second review

`flutter analyze --no-pub`: clean. Full suite: **376 tests passed**, including
**19 new regressions**. Reply cases cover entrance/focus timing, selection and
IME handling, MIME/empty/missing clipboard results, serialized/disposed attachment
reads, friendly errors, GIF draft persistence, preview/editor switching, failed
send retention, late send/new draft races, account-change rejection, successful
draft clearing and a 320 dp keyboard viewport at 200% text.

Loading cases complete about/posts in both orders and fail about independently;
they assert one active indicator, static skeletons, then no loader when requests
finish. Inactive-tab exposure now has a regression alongside the existing dwell
and video lifecycle tests. Existing code/fence/reference/media/spoiler regressions
remain green. Light/dark reply editor and preview widget renders were inspected.

The second review checked disposal callbacks, duplicate sends, controller
selection changes, preview updates, session completion, matching-draft clearing,
loader ownership, method-channel MIME contract and Gradle signing paths. The
first regression run caught a queued visibility callback touching a disposed
notifier; the mounted guard was added before the full passing run. The escaped
spoiler regression also exposed transformation slices breaking redaction; whole
spoiler transforms now prevent that leak.

CI builds both the debug APK and an optimized **arm64-v8a test APK**. The latter
uses release compilation and shrinking with the development certificate, enabling
an in-place update of the existing debug app. It is a PR artifact, not a tagged
production release. Android channel compilation and packaging are verified by CI;
actual clipboard grants/IME transitions still need a device check.

## Performance measurement still needed

At 120 Hz, each UI/raster frame has approximately **8.33 ms**. On a physical
device, compare the optimized APK against debug on the same feed, first with a
warm image cache, then a cold cache. Profile mode plus Flutter DevTools should
separate UI build/layout costs from raster/image decoding and platform media
costs. Use a representative feed with tall photos and GIF/video posts, repeat
flings and reply open/close, and inspect slow-frame traces before changing
cache sizes or introducing more animation packages. A smaller APK or passing
widget tests cannot establish this timing target.

Sources: [Flutter rendering performance](https://docs.flutter.dev/perf/rendering-performance),
[Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance),
[DevTools performance view](https://docs.flutter.dev/tools/devtools/performance).

The prior app-wide follow-ups in POST_POLISH_AUDIT_2026-10-02.md remain open.
In particular drafts are still keyed by target rather than account. This pass
guards an open reply's session and newer text; it does not migrate all stored
drafts to account ownership. Notification ownership, corrupt-history recovery,
custom feeds, failed-hide rollback and unrelated action-dialog lifetimes also
remain separate work.
