# Branding and keyboard media — 2026-10-02

Android namespace, application ID, Kotlin activity package and Reddit User-Agent
now use `com.ichiro.lily_for_reddit`. Android treats this as a separate app:
the old installation's settings, drafts and login are not migrated automatically.
The registered OAuth callback scheme remains `luli://oauth` so existing Reddit
client configurations still work. The internal Dart package and iOS bundle ID
are separate identifiers and remain unchanged.

The supplied gray Lily/orbit reference is reconstructed as clean vector geometry
with a subtle lavender-gray gradient and charcoal icon surface. Launcher masks
and shadows are left to Android rather than baked into adaptive foregrounds.
Color and monochrome foregrounds share the same shape, fit the central 66 dp
safe region of a 108 dp adaptive canvas, and the monochrome layer contains only
opaque white artwork on transparency. Android can apply wallpaper/theme colors
without tinting an opaque square. The notification small icon also uses this
transparent glyph. Legacy Android icons, iOS light/dark/tinted icons and store
metadata use raster exports from the same geometry; old launcher layers and
purple splash artwork are removed.

Default, night and Android 12 launch themes have pure `#000000` surfaces,
black system bars and the new icon. The pre-Flutter window background is also
black. iOS launch backgrounds and splash generator configuration match.
Rebuild assets with `flutter test tool/branding/generate_assets_test.dart`.

Both the inline comment field and reply sheet advertise GIF, WebP, PNG and JPEG
through Flutter ContentInsertionConfiguration. They retain original bytes/MIME
instead of converting animated GIFs or stickers to JPEG. Keyboard bytes are
accepted directly; a content-URI fallback uses the native worker reader.
Attachments are limited to 20 MB, show actionable failures, ignore completions
after disposal and prevent send while reading. Inline selection reaches the
parent synchronously, avoiding a read/send race; failed sends restore the
attachment in the controlled compose bar. Reply keyboard reads are isolated
from gallery/GIF picker busy state so those operations cannot overlap.

Verification: **386 tests passed**, clean static analysis, plus 10 new regressions covering
MIME/bytes, URI fallback, unsupported and oversized content, pending-read send
timing, disposal, reply text preservation and a real TextInputClient.commitContent
event through Flutter's system channel. CI builds debug and optimized arm64
APKs and checks the packaged application ID with apkanalyzer. Android compilation
validates the vector gradients and launch resources; iOS assets are statically
updated but no Xcode build is available in this environment.

Themed icons require a compatible launcher with themed icons enabled. Keyboard
rich content requires a supporting Android keyboard; subreddit/server media
rules still apply to posting. Native uploads and the existing linked-media
fallback are unchanged. Actual launcher masks/colors, cold launch and Gboard/
Samsung Keyboard selections remain physical-device checks.

Sources: [Android adaptive icon requirements](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive),
[Flutter keyboard content insertion](https://api.flutter.dev/flutter/widgets/ContentInsertionConfiguration-class.html).
