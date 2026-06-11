#!/bin/bash
ENV=${1:-prod}

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
echo ">>> [AppView] Project root resolved to: $PROJECT_ROOT"

OUT_DIR="${PROJECT_ROOT}/NightwavePlaza/WebApp"
echo ">>> [AppView] OUT_DIR will be $OUT_DIR"

if [ "$ENV" == "dev" ]; then
    echo ">>> [AppView] Running in DEV mode, downloading bundle directly..."
    BUNDLE_URL="https://akai.plaza.one/app-view/dev/build-mobile-snapshot.zip"
    curl -L -o /tmp/view.zip "$BUNDLE_URL"
    find "$OUT_DIR" -mindepth 1 ! -name '.gitignore' -exec rm -rf {} +
    unzip -q /tmp/view.zip -d "$OUT_DIR"
    rm /tmp/view.zip
    echo ">>> [AppView] Dev bundle embedded."
    exit 0
fi

echo ">>> [AppView] Running in PROD mode"
MANIFEST_URL="https://akai.plaza.one/app-view/manifest-ios.json"

echo ">>> [AppView] Fetching version manifest..."
MANIFEST=$(curl -s -f "$MANIFEST_URL")
if [ -z "$MANIFEST" ]; then
    echo ">>> [AppView] Failed to fetch manifest. Skipping."
    exit 1
fi

TARGET_VERSION=$(echo "$MANIFEST" | jq -r '.versions | max_by(.view_version) | .view_version')
TARGET_URL=$(echo "$MANIFEST" | jq -r '.versions | max_by(.view_version) | .url')
EXPECTED_HASH=$(echo "$MANIFEST" | jq -r '.versions | max_by(.view_version) | .sha256')

echo ">>> [AppView] Downloading view version $TARGET_VERSION..."
curl -L -o /tmp/view.zip "$TARGET_URL"

CALCULATED_HASH=$(shasum -a 256 /tmp/view.zip | awk '{ print $1 }')
if [ "$CALCULATED_HASH" != "$EXPECTED_HASH" ]; then
    echo ">>> [AppView] Hash mismatch! Expected: $EXPECTED_HASH, Got: $CALCULATED_HASH"
    rm /tmp/view.zip
    exit 1
fi

find "$OUT_DIR" -mindepth 1 ! -name '.gitignore' -exec rm -rf {} +
unzip -q /tmp/view.zip -d "$OUT_DIR"
rm /tmp/view.zip
echo ">>> [AppView] Version $TARGET_VERSION successfully embedded."
