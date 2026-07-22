# Nightwave Plaza for iOS

iOS client for [Nightwave Plaza](https://plaza.one), a 24/7 vaporwave radio.

The UI is a web app (a mobile build of the plaza.one interface) shown in a WKWebView. Everything else is native: audio playback, lock screen controls, metadata, video backgrounds.

## Requirements

- Xcode 15 or newer
- `jq` for the fetch script (`brew install jq`)

## Building

1. Download the latest web UI bundle:

```
./Scripts/fetch_view.sh
```

Use `./Scripts/fetch_view.sh dev` if you want the dev snapshot instead.

2. Create `AppConfig.xcconfig` in the project root (this file is not in git):

```
SENTRY_DSN =
```

Leave the value empty if you don't need Sentry.

3. Open `NightwavePlaza.xcodeproj` and build. Dependencies (Sentry, Swifter) are resolved by Swift Package Manager on first build.

## How it works

- `Scripts/fetch_view.sh` downloads the pre-built web UI into `NightwavePlaza/WebApp`. This folder is not stored in git.
- On launch the app starts a local server on `127.0.0.1:8080` and loads it in a WKWebView.
- The web UI talks to the native side through a JS bridge: playback control, backgrounds, sleep timer, theme color and language.
- Song metadata comes from ID3 tags in the HLS stream, then the app fetches song details from the Plaza API for the lock screen.
