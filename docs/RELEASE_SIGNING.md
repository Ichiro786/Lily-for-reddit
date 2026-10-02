# Production release signing

Lily 2.0 uses a private production certificate for `com.ichiro.lily_for_reddit`.
The previously committed CI signing key is exposed and must never sign production
releases. The release workflow has no fallback when private secrets are missing.

Configure these **repository secrets** under **Settings → Secrets and variables →
Actions** in `Ichiro786/Lily-for-reddit`:

| Secret | Value |
| --- | --- |
| `RELEASE_KEYSTORE_BASE64` | Base64 encoding of the private production JKS file |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Production key alias |
| `KEY_PASSWORD` | Private key password |

The initial signing bundle was prepared in the ignored
`build/private-release-signing/` directory. Its four `.txt` files hold the exact
secret values. Back up this folder in private storage before deleting build files
or replacing this workspace. Never commit it, attach it to a release, or upload it
as a workflow artifact. Keep the same key for future versions of this package.

Only the public certificate's SHA-256 fingerprint is committed, in
`android/release-cert.sha256`. Before upload, `tool/verify_release_apks.py` verifies
both APK signatures against that fingerprint, along with the package, version,
ABI, release mode, and archive integrity. It produces download checksums and a
verification report. Missing secrets or a different certificate stop the release.

The approved release notes live in `docs/RELEASE_2.0.0.md`. Pull requests build and
verify without publishing. A new version merged into `main`, a matching version
tag, or a manual run with `publish` enabled publishes the release only after all
checks pass. An already published release is preserved.
