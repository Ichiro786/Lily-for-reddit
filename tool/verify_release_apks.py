"""Verify the two signed Android release APKs before preparing downloads."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile


ANDROID = "{http://schemas.android.com/apk/res/android}"
PACKAGE = "com.ichiro.lily_for_reddit"
ABIS = {"armeabi-v7a": 1, "arm64-v8a": 2}


def run(*args):
    return subprocess.check_output([str(arg) for arg in args], text=True).strip()


def signing_certificate(output, expected=None):
    # Prefer the certificate bytes over SDK-specific human-readable labels.
    pem_certificates = re.findall(
        r"-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----",
        output, re.DOTALL,
    )
    if pem_certificates:
        digests = {
            hashlib.sha256(base64.b64decode(re.sub(r"\s+", "", pem), validate=True)).hexdigest()
            for pem in pem_certificates
        }
    elif "-----BEGIN CERTIFICATE-----" in output:
        raise ValueError("Incomplete signing certificate PEM")
    else:
        digests = text_certificate_digests(output)
    if len(digests) != 1:
        # Verification prints public certificate information only. Retain the
        # output on failure so a new SDK format can be diagnosed without guessing.
        raise ValueError(f"Expected one signing certificate; found {len(digests)}. Verifier output:\n{output[:4000]}")
    digest = digests.pop()
    if expected is not None and digest != expected:
        raise ValueError("APK certificate does not match the pinned production certificate")
    return digest


def text_certificate_digests(output):
    # Android's verifier prints either numbered signers or SDK-range signers.
    # Parse certificates only; public-key and source-stamp hashes are unrelated.
    matches = re.findall(
        r"^[ \t]*Signer[^\r\n]*? certificate SHA-256 digest:[ \t]*([0-9a-fA-F:]+)[ \t\r]*$",
        output, re.MULTILINE,
    )
    digests = {digest.replace(":", "").lower() for digest in matches}
    if any(not re.fullmatch(r"[0-9a-f]{64}", digest) for digest in digests):
        raise ValueError("Malformed signing certificate fingerprint")
    return digests


def prepare(version, build_number, input_dir, output_dir, sdk, expected_certificate):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or build_number < 1:
        raise ValueError("Invalid release version/build number")
    if not re.fullmatch(r"[0-9a-f]{64}", expected_certificate):
        raise ValueError("Invalid production certificate fingerprint")
    analyzer = sdk / "cmdline-tools/latest/bin/apkanalyzer"
    signers = list((sdk / "build-tools").glob("*/apksigner"))
    if not analyzer.is_file() or not signers:
        raise RuntimeError("Android SDK apkanalyzer and apksigner are required")
    signer = max(signers, key=lambda path: tuple(map(int, re.findall(r"\d+", path.parent.name))))
    output_dir.mkdir(parents=True, exist_ok=True)
    checksums, records = [], []
    certificate = None
    for abi, code in ABIS.items():
        apk = input_dir / f"app-{abi}-release.apk"
        manifest = ET.fromstring(run(analyzer, "manifest", "print", apk))
        if manifest.get("package") != PACKAGE:
            raise ValueError(f"Wrong package in {apk.name}")
        if manifest.get(ANDROID + "versionName") != version:
            raise ValueError(f"Wrong version in {apk.name}")
        version_code = int(manifest.get(ANDROID + "versionCode", "0"))
        # Flutter assigns a distinct code to each ABI split.
        if version_code != build_number + code * 1000:
            raise ValueError(f"Unexpected ABI version code in {apk.name}: {version_code}")
        app = manifest.find("application")
        if app is None or app.get(ANDROID + "debuggable", "false") != "false":
            raise ValueError(f"Debuggable or missing application in {apk.name}")
        with zipfile.ZipFile(apk) as archive:
            if archive.testzip() is not None:
                raise ValueError(f"Corrupt APK archive: {apk.name}")
            names = archive.namelist()
            packaged_abis = {name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith(".so")}
            if packaged_abis != {abi}:
                raise ValueError(f"Wrong native libraries in {apk.name}: {packaged_abis}")
            for library in ("libapp.so", "libflutter.so"):
                if f"lib/{abi}/{library}" not in names:
                    raise ValueError(f"Missing {library} in {apk.name}")
        signature = run(signer, "verify", "--verbose", "--print-certs", "--print-certs-pem", apk)
        digest = signing_certificate(signature, expected_certificate)
        if certificate is not None and certificate != digest:
            raise ValueError("The two APKs use different signing certificates")
        certificate = digest
        filename = f"lily-for-reddit-{version}-{abi}.apk"
        destination = output_dir / filename
        shutil.copyfile(apk, destination)
        sha256 = hashlib.sha256(destination.read_bytes()).hexdigest()
        checksums.append(f"{sha256}  {filename}\n")
        record = dict(filename=filename, abi=abi, package=PACKAGE, version=version,
                      version_code=version_code, debuggable=False,
                      bytes=destination.stat().st_size, sha256=sha256,
                      certificate_sha256=digest)
        records.append(record)
        print(f"Verified {filename}: {PACKAGE}, {version} ({version_code}), {abi}, signed, non-debuggable")
    print(json.dumps(records, indent=2))
    (output_dir / "checksums-sha256.txt").write_text("".join(checksums), encoding="utf-8")
    (output_dir / "build-verification.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-number", type=int, required=True)
    parser.add_argument("--input-dir", type=Path, default=Path("build/app/outputs/flutter-apk"))
    parser.add_argument("--output-dir", type=Path, default=Path("build/release-downloads"))
    parser.add_argument("--certificate-file", type=Path, default=Path("android/release-cert.sha256"))
    args = parser.parse_args()
    sdk_root = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk_root:
        raise RuntimeError("Android SDK environment is missing")
    expected_certificate = args.certificate_file.read_text(encoding="utf-8").strip().lower()
    prepare(args.version, args.build_number, args.input_dir, args.output_dir, Path(sdk_root), expected_certificate)


if __name__ == "__main__":
    main()
