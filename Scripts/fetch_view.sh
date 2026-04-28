#!/bin/bash

ENV=${1:-prod}

if [ "$ENV" == "dev" ]; then
    echo ">>> [AppView] Running in DEV mode"
    MANIFEST_URL="https://akai.plaza.one/app-view/dev-manifest-ios.json"
else
    echo ">>> [AppView] Running in PROD mode"
    MANIFEST_URL="https://akai.plaza.one/app-view/manifest-ios.json"
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

echo ">>> [AppView] Project root resolved to: $PROJECT_ROOT"

OUT_DIR="${PROJECT_ROOT}/NightwavePlaza/WebApp"
echo ">>> [AppView] OUT_DIR will be $OUT_DIR"

APP_VERSION_CODE=$(agvtool what-version -terse | tr -d ' \n')

echo ">>> [AppView] Current iOS Build Number (versionCode): $APP_VERSION_CODE"

VERSION_FILE="${OUT_DIR}/version.txt"

echo ">>> [AppView] Fetching version manifest..."

MANIFEST=$(curl -s -f "$MANIFEST_URL")

TARGET_VERSION=$(echo "$MANIFEST" | jq -r '.versions | max_by(.view_version) | .view_version')
TARGET_URL=$(echo "$MANIFEST" | jq -r '.versions | max_by(.view_version) | .url')
EXPECTED_HASH=$(echo "$MANIFEST" | jq -r '.versions | max_by(.view_version) | .sha256')

if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
    if [ "$CURRENT_VERSION" -ge "$TARGET_VERSION" ]; then
        echo ">>> [AppView] Local view ($CURRENT_VERSION) is up to date. Skip downloading."
        exit 0
    fi
fi

echo ">>> [AppView] Downloading view version $TARGET_VERSION..."
curl -L -o /tmp/view.zip "$TARGET_URL"

CALCULATED_HASH=$(shasum -a 256 /tmp/view.zip | awk '{ print $1 }')

if [ "$CALCULATED_HASH" != "$EXPECTED_HASH" ]; then
    echo "Hash mismatch! Expected: $EXPECTED_HASH, Got: $CALCULATED_HASH"
    rm /tmp/view.zip
    exit 1
fi

find "$OUT_DIR" -mindepth 1 ! -name '.gitignore' -exec rm -rf {} +
unzip -q /tmp/view.zip -d "$OUT_DIR"
rm /tmp/view.zip

echo "$TARGET_VERSION" > "$VERSION_FILE"
echo ">>> [AppView] Version $TARGET_VERSION successfully embedded."
