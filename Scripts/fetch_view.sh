#!/bin/bash
set -euo pipefail

VIEW_ENV=${1:-prod}
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$PROJECT_ROOT/NightwavePlaza/WebApp"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

case "$VIEW_ENV" in
    prod)
        curl --fail --silent --show-error --location --retry 3 \
            https://akai.plaza.one/app-view/manifest-ios.json -o "$WORK_DIR/manifest.json"
        TARGET=$(jq -ce '.versions | max_by(.view_version) |
            select(.url | type == "string" and startswith("https://")) |
            select(.sha256 | type == "string" and test("^[a-fA-F0-9]{64}$"))' "$WORK_DIR/manifest.json")
        BUNDLE_URL=$(jq -r '.url' <<< "$TARGET")
        EXPECTED_HASH=$(jq -r '.sha256 | ascii_downcase' <<< "$TARGET")
        echo ">>> [AppView] Downloading version $(jq -r '.view_version' <<< "$TARGET")"
        ;;
    dev)
        BUNDLE_URL=https://akai.plaza.one/app-view/dev/build-mobile-snapshot.zip
        ;;
    *)
        echo "Usage: $0 [prod|dev]" >&2
        exit 1
        ;;
esac

curl --fail --silent --show-error --location --retry 3 "$BUNDLE_URL" -o "$WORK_DIR/view.zip"
if [ "$VIEW_ENV" = prod ]; then
    CALCULATED_HASH=$(shasum -a 256 "$WORK_DIR/view.zip" | awk '{print $1}')
    if [ "$CALCULATED_HASH" != "$EXPECTED_HASH" ]; then
        echo ">>> [AppView] SHA-256 mismatch; existing bundle kept." >&2
        exit 1
    fi
fi

# Validate the download before replacing the last usable bundle.
unzip -q "$WORK_DIR/view.zip" -d "$WORK_DIR/unpacked"
test -s "$WORK_DIR/unpacked/index.html"
mkdir -p "$OUT_DIR"
find "$OUT_DIR" -mindepth 1 ! -name '.gitignore' -delete
cp -R "$WORK_DIR/unpacked/." "$OUT_DIR/"
echo ">>> [AppView] Bundle embedded successfully."
