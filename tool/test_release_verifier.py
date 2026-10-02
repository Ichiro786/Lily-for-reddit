"""Regression coverage for Android SDK certificate-output variants."""

import unittest

from verify_release_apks import signing_certificate


class SigningCertificateTest(unittest.TestCase):
    digest = "ab" * 32

    def test_numbered_signer(self):
        output = f"Verifies\nSigner #1 certificate SHA-256 digest: {self.digest}\n"
        self.assertEqual(signing_certificate(output), self.digest)

    def test_sdk_ranges_and_duplicate_certificate(self):
        output = "\n".join(
            f"Signer (minSdkVersion={low}, maxSdkVersion={high}) certificate SHA-256 digest: {self.digest.upper()}"
            for low, high in [(24, 32), (33, 2147483647)]
        )
        self.assertEqual(signing_certificate(output), self.digest)

    def test_public_key_and_source_stamp_are_not_the_signer(self):
        unrelated = "cd" * 32
        output = (
            f"Signer #1 public key SHA-256 digest: {unrelated}\n"
            f"Source Stamp Signer certificate SHA-256 digest: {unrelated}\n"
            f"Signer #1 certificate SHA-256 digest: {self.digest}\n"
        )
        self.assertEqual(signing_certificate(output), self.digest)

    def test_missing_or_malformed_certificate_fails(self):
        for output in ["", f"Signer #1 certificate SHA-256 digest: {self.digest[:-1]}"]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                signing_certificate(output)

    def test_unexpected_multiple_signers_fail(self):
        output = (
            f"Signer #1 certificate SHA-256 digest: {self.digest}\n"
            f"Signer #2 certificate SHA-256 digest: {'cd' * 32}\n"
        )
        with self.assertRaises(ValueError):
            signing_certificate(output)

    def test_pinned_production_certificate_matches(self):
        output = f"Signer #1 certificate SHA-256 digest: {self.digest}"
        self.assertEqual(signing_certificate(output, self.digest), self.digest)

    def test_public_fallback_certificate_is_rejected(self):
        output = f"Signer #1 certificate SHA-256 digest: {'cd' * 32}"
        with self.assertRaisesRegex(ValueError, "pinned production"):
            signing_certificate(output, self.digest)


if __name__ == "__main__":
    unittest.main()
