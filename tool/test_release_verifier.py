"""Regression coverage for Android SDK certificate-output variants."""

import base64
import hashlib
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

    def test_indented_certificate_line(self):
        output = f"\t  Signer #1 certificate SHA-256 digest: {self.digest}\r\n"
        self.assertEqual(signing_certificate(output), self.digest)

    def test_numbered_sdk_range_label(self):
        output = f"Signer #1 (minSdkVersion=24, maxSdkVersion=32) certificate SHA-256 digest: {self.digest}"
        self.assertEqual(signing_certificate(output), self.digest)

    def test_colon_separated_digest(self):
        digest = ":".join(["AB"] * 32)
        output = f"Signer #1 certificate SHA-256 digest: {digest}"
        self.assertEqual(signing_certificate(output), self.digest)

    def test_pem_avoids_sdk_digest_label_formatting(self):
        certificate = b"public certificate DER returned by the verified SDK"
        encoded = base64.b64encode(certificate).decode()
        output = f"Different SDK label\n-----BEGIN CERTIFICATE-----\n{encoded[:20]}\n{encoded[20:]}\n-----END CERTIFICATE-----\n"
        expected = hashlib.sha256(certificate).hexdigest()
        self.assertEqual(signing_certificate(output, expected), expected)

    def test_duplicate_pem_sdk_ranges_are_one_certificate(self):
        output = "-----BEGIN CERTIFICATE-----\nYWJj\n-----END CERTIFICATE-----\n" * 2
        self.assertEqual(signing_certificate(output), hashlib.sha256(b"abc").hexdigest())

    def test_other_pem_certificate_fails_production_pin(self):
        output = "-----BEGIN CERTIFICATE-----\nYWJj\n-----END CERTIFICATE-----\n"
        with self.assertRaisesRegex(ValueError, "pinned production"):
            signing_certificate(output, self.digest)

    def test_multiple_distinct_pem_certificates_fail(self):
        output = (
            "-----BEGIN CERTIFICATE-----\nYWJj\n-----END CERTIFICATE-----\n"
            "-----BEGIN CERTIFICATE-----\nZGVm\n-----END CERTIFICATE-----\n"
        )
        with self.assertRaisesRegex(ValueError, "found 2"):
            signing_certificate(output)

    def test_incomplete_pem_fails(self):
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            signing_certificate("-----BEGIN CERTIFICATE-----\nYWJj")

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
