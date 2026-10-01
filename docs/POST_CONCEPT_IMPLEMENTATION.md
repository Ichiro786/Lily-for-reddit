# Post and comment concept implementation

The supplied reference guides the flat post-detail canvas, subreddit/author
hierarchy, bold title, tonal flair, rounded media frame, vote/comments/save/share
pills, sort caption, rounded comment cards and floating comment dock. Feed media
shares the same portrait presentation. Device light/dark/dynamic colors and the
existing appearance settings remain authoritative.

## Layout and interaction

- Source aspect ratios determine media height. Tall images expand and collapse
  in place; both the capped and expanded states contain the entire source.
  Galleries animate to the current item's ratio and handle changing/empty lists.
- Detail actions retain directional vote intents and shared optimistic state.
  Their glyphs align in one row; narrow widths/large text can scroll horizontally.
  Comment actions wrap at large text sizes, with 48dp targets and bounded scores.
- Reply rails fill the full card height without intrinsic layout passes.
  Seven rainbow accents are harmonized with the active primary and generated
  at the active brightness; text and surfaces use the device's ColorScheme.
- Collapse/expansion uses the shared expressive shape and motion tokens.
  Reduced motion bypasses size animation, including the zero-duration layout
  assertion discovered by testing. Sort dropdowns use themed rounded menus.
- Comment search and next-thread navigation scroll to list indices instead of
  guessed pixel distances. Search remains editable while the list scrolls.
  Reply placeholders fetch inline, deduplicate existing requests/results and
  retain a retry with visible feedback when fetching fails.

## Media

Comment GIFs, images and direct MP4/WebM attachments render automatically, with
fullscreen access. Autoplay and reduced-motion preferences govern animation and
video playback. Video retains visibility, app lifecycle and route ownership from
the stability fixes, and now preserves the full frame with accessible mute controls.

Reddit emotes resolve through response metadata, rather than guessing Giphy URLs.
GIF image hints/query strings and preview variants retain the animated source.
Missing emote metadata has an explicit fallback. Duplicate URLs render once;
Markdown link captions remain readable. Code examples remain text. Spoiler media
is not loaded before reveal and can be hidden again. Post/comment image errors
provide inline retries.

## Verification

The regression suite adds 18 cases: rainbow contrast across five schemes;
deep nesting/long names/200% text; intrinsic portrait geometry; intermediate
expansion frames and collapse; reduced motion; metadata emotes; inline duplicate
media and collapse; failed inline reply loading/retry; distant search; action
order/directional callbacks/target sizes; mixed and empty galleries; animated GIF
source selection; actual dropdown selection; skipping a long reply branch;
spoiler reveal/hide; protected code/media-link captions; and stable search targets
when preceding reply branches collapse; and light-theme media overlay contrast.

The whole application suite and analysis are run before publication. Exact GitHub
results and the arm64-v8a build are linked from the associated draft pull request.
Existing vote/save, request ordering, account ownership, composer, media lifecycle
and backup regressions remain in the suite.

Local visual inspection renders dark, light and portrait screens with real
Roboto/MaterialIcons and a generated image fixture. These are layout previews,
not live Reddit or device screenshots. Real-device decoder behavior, Android/iOS
scroll performance, large galleries and platform pickers still require phone testing.
This does not claim every possible post or device is flawless.

Material guidance: [M3 foundations](https://m3.material.io/foundations/).
Platform motion handling: [Flutter disableAnimations](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html).
