#!/bin/bash
set -euo pipefail
umask 077

for name in APPLE_TEAM_ID DISTRIBUTION_P12_BASE64 DISTRIBUTION_P12_PASSWORD \
    PROVISIONING_PROFILE_BASE64 ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY_BASE64; do
    if [ -z "${!name:-}" ]; then
        echo "Missing GitHub testflight environment setting: $name" >&2
        exit 1
    fi
done

export BUILD_NUMBER=${BUILD_NUMBER:-$((1000 + GITHUB_RUN_NUMBER)).${GITHUB_RUN_ATTEMPT}}
export BUNDLE_ID=com.nightwaveplaza.NightwavePlaza
export SIGNING_DIR
SIGNING_DIR=$(mktemp -d "$RUNNER_TEMP/plaza-signing.XXXXXX")
KEYCHAIN_PATH="$SIGNING_DIR/signing.keychain-db"
KEYCHAIN_PASSWORD=$(openssl rand -hex 32)
PROFILE_PATH=""
cleanup() {
    security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
    if [ -n "$PROFILE_PATH" ]; then rm -f "$PROFILE_PATH"; fi
    rm -rf "$SIGNING_DIR"
}
trap cleanup EXIT

python3 - <<'PY'
import base64
import os
from pathlib import Path
import re

if not re.fullmatch(r"[1-9][0-9]{0,3}(\.[0-9]{1,2}){0,2}", os.environ["BUILD_NUMBER"]):
    raise SystemExit("Use a CFBundleVersion such as 1001.1 (up to 4/2/2 digits).")
directory = Path(os.environ["SIGNING_DIR"])
for variable, filename in (
    ("DISTRIBUTION_P12_BASE64", "distribution.p12"),
    ("PROVISIONING_PROFILE_BASE64", "profile.mobileprovision"),
    ("ASC_PRIVATE_KEY_BASE64", "AuthKey.p8"),
):
    (directory / filename).write_bytes(base64.b64decode("".join(os.environ[variable].split()), validate=True))
PY

security cms -D -i "$SIGNING_DIR/profile.mobileprovision" > "$SIGNING_DIR/profile.plist"
PROFILE_UUID=$(python3 - <<'PY'
import datetime
import os
from pathlib import Path
import plistlib
import uuid

profile = plistlib.loads((Path(os.environ["SIGNING_DIR"]) / "profile.plist").read_bytes())
team = os.environ["APPLE_TEAM_ID"]
entitlements = profile["Entitlements"]
if team not in profile["TeamIdentifier"]:
    raise SystemExit("Provisioning profile belongs to a different Apple team.")
expected_app_ids = {f'{prefix}.{os.environ["BUNDLE_ID"]}' for prefix in profile["ApplicationIdentifierPrefix"]}
if entitlements.get("application-identifier") not in expected_app_ids:
    raise SystemExit("Provisioning profile does not match the app's bundle identifier.")
if entitlements.get("get-task-allow") or profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices"):
    raise SystemExit("An App Store Connect distribution profile is required.")
if profile["ExpirationDate"] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
    raise SystemExit("Provisioning profile has expired.")
print(str(uuid.UUID(profile["UUID"])).upper())
PY
)
export PROFILE_UUID
PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
mkdir -p "$PROFILE_DIR"
PROFILE_PATH="$PROFILE_DIR/$PROFILE_UUID.mobileprovision"
cp "$SIGNING_DIR/profile.mobileprovision" "$PROFILE_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 7200 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$SIGNING_DIR/distribution.p12" -P "$DISTRIBUTION_P12_PASSWORD" \
    -k "$KEYCHAIN_PATH" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
    -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security list-keychains -d user -s "$KEYCHAIN_PATH" "$HOME/Library/Keychains/login.keychain-db"

mkdir -p build
xcodebuild -project NightwavePlaza.xcodeproj -scheme NightwavePlaza \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath build/NightwavePlaza.xcarchive -resultBundlePath build/Archive.xcresult \
    -onlyUsePackageVersionsFromResolvedFile \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" PROVISIONING_PROFILE_SPECIFIER="$PROFILE_UUID" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" archive 2>&1 | tee build/archive.log

python3 - <<'PY'
import os
import plistlib
from pathlib import Path

options = {
    "method": "app-store-connect",
    "destination": "upload",
    "teamID": os.environ["APPLE_TEAM_ID"],
    "signingStyle": "manual",
    "signingCertificate": "Apple Distribution",
    "provisioningProfiles": {os.environ["BUNDLE_ID"]: os.environ["PROFILE_UUID"]},
    "testFlightInternalTestingOnly": True,
    "manageAppVersionAndBuildNumber": False,
    "uploadSymbols": True,
}
(Path(os.environ["SIGNING_DIR"]) / "ExportOptions.plist").write_bytes(plistlib.dumps(options))
PY

xcodebuild -exportArchive -archivePath build/NightwavePlaza.xcarchive \
    -exportPath build/export -exportOptionsPlist "$SIGNING_DIR/ExportOptions.plist" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$SIGNING_DIR/AuthKey.p8" \
    -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    2>&1 | tee build/upload.log

echo "Uploaded build $BUILD_NUMBER for TestFlight Internal Only; Apple processing is still required."
