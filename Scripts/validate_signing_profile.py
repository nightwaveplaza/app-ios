"""Validate a decoded iOS distribution profile against usable Keychain identities."""

import datetime
import hashlib
import os
from pathlib import Path
import plistlib
import re
import sys
import uuid


def validate_profile(profile, team, bundle_id, identities):
    profile_uuid = profile["UUID"]
    # Validate the UUID without changing the identifier stored in the signed profile
    if not re.fullmatch(r"[0-9a-fA-F-]{36}", profile_uuid):
        raise ValueError("Invalid provisioning profile UUID")
    uuid.UUID(profile_uuid)
    if team not in profile["TeamIdentifier"]:
        raise ValueError("Provisioning profile belongs to a different Apple team")
    if "iOS" not in profile.get("Platform", []):
        raise ValueError("An iOS provisioning profile is required")
    entitlements = profile["Entitlements"]
    expected_ids = {f"{prefix}.{bundle_id}" for prefix in profile["ApplicationIdentifierPrefix"]}
    if entitlements.get("application-identifier") not in expected_ids:
        raise ValueError("Provisioning profile does not match the app's bundle identifier")
    if entitlements.get("get-task-allow") or profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices"):
        raise ValueError("An App Store Connect distribution profile is required")
    if profile["ExpirationDate"] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
        raise ValueError("Provisioning profile has expired")
    allowed = {hashlib.sha1(cert).hexdigest().upper() for cert in profile.get("DeveloperCertificates", [])}
    usable = set(re.findall(r'^\s*\d+\) ([0-9A-Fa-f]{40}) ', identities, re.MULTILINE))
    if not allowed.intersection(identity.upper() for identity in usable):
        raise ValueError(
            "No valid code-signing identity in the imported Keychain matches the profile's "
            "DeveloperCertificates. Check the certificate/profile pair, private key, "
            "certificate expiry and Apple certificate chain"
        )
    return profile_uuid


def main():
    directory = Path(os.environ["SIGNING_DIR"])
    profile = plistlib.loads((directory / "profile.plist").read_bytes())
    identities = (directory / "identities.txt").read_text()
    try:
        profile_uuid = validate_profile(profile, os.environ["APPLE_TEAM_ID"], os.environ["BUNDLE_ID"], identities)
    except (ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"Signing preflight failed: {error}") from error
    print(f"Validated iOS App Store profile {profile_uuid}; expires {profile['ExpirationDate'].isoformat()}; "
          "matching valid signing identity found", file=sys.stderr)
    print(profile_uuid)


if __name__ == "__main__":
    main()
