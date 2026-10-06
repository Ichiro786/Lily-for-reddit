# Lily for Reddit 2.0.1: Smoother Comments and Continuous Feeds

This update fixes the navigation, comment composer, feed continuity, back navigation, and gallery issues reported after Lily 2.0.

## What's fixed

- Balanced spacing around the selected pill in the floating navigation bar.
- A left-hand **+** inside the comment field opens a smooth Photo, Video, and GIF tray above the keyboard. Your draft, cursor, and keyboard focus stay in place, with a separate Send button on the right.
- **Hide read posts automatically** now works across For You, Hot, New, Rising, Top, subreddit, and custom feeds using persisted seen/read state. Your history stays available.
- A separate **Resume feeds where I left off** setting restores your last feed and sort. Returns within ten minutes restore the previous position when the loaded posts still match; longer returns, changed listings, and explicit refreshes open fresh content at the top.
- **New posts** appears only when fresh items have been confirmed. Tapping it reveals those posts, and filtered pagination continues looking for unread content without changing Reddit's sort order.
- Android Back returns Discover, Inbox, and Profile to Home. Posts, settings, subreddits, and media viewers still close first when open.
- Galleries prepare and decode the next and previous images using the existing cache. The preload window follows your swipes and releases its image listeners on memory pressure or disposal.

## Downloads

| APK | Device |
| --- | --- |
| [Lily 2.0.1 — arm64-v8a](https://github.com/Ichiro786/Lily-for-reddit/releases/download/v2.0.1/lily-for-reddit-2.0.1-arm64-v8a.apk) | Most modern 64-bit Android phones |
| [Lily 2.0.1 — armeabi-v7a](https://github.com/Ichiro786/Lily-for-reddit/releases/download/v2.0.1/lily-for-reddit-2.0.1-armeabi-v7a.apk) | Supported 32-bit ARM Android devices |

Install the APK for your device over the production 2.0.0 release to keep your accounts, settings, and history.
