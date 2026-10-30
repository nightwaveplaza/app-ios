# AGENTS.md

Guidance for AI coding agents working in the **Nightwave Plaza** iOS repository.

## Git & Commit Rules

Never mention AI assistance in commit messages and never add `Co-Authored-By` trailers. Do not commit or push anything unless explicitly asked.

## Overview

Nightwave Plaza — iOS client for the online radio at https://plaza.one. It is a hybrid app: a thin native Swift/UIKit shell (audio playback, lockscreen, background video) hosting a Vue SPA ("WebApp") rendered in a `WKWebView`. The SPA bundle is **not authored in this repo** — it is downloaded pre-built by `Scripts/fetch_view.sh` into `NightwavePlaza/WebApp/` (gitignored except its `.gitignore`). **Never edit files inside `NightwavePlaza/WebApp/` directly.**

## Commands & Setup

- **Build (compile check):**
  `xcodebuild -project NightwavePlaza.xcodeproj -scheme NightwavePlaza -destination 'generic/platform=iOS Simulator' build`
  *(or target a specific available simulator via `-destination 'platform=iOS Simulator,name=iPhone 16'`)*
- **Fetch/refresh embedded web UI:**
  `Scripts/fetch_view.sh` (prod: downloads latest release from `https://akai.plaza.one/app-view/manifest-ios.json` with sha256 verification) or `Scripts/fetch_view.sh dev` (dev snapshot bundle). Requires `jq`. The script wipes `WebApp/` before unpacking.

- **Dependencies:** Swift Package Manager only (`Sentry`, `Swifter`). The `Pods/` directory is a legacy leftover — there is no `Podfile`; do not use or resurrect CocoaPods.
- **Config:** `AppConfig.xcconfig` is gitignored (holds `SENTRY_DSN`, injected into `Info.plist`; Sentry is skipped at runtime if absent). The build expects this file to exist locally.
- **Target & Versioning:** Deployment target is iOS 15.6. Versioning uses CalVer (`MARKETING_VERSION`, e.g. `26.6.1`). There are no meaningful unit tests yet (only Xcode template stubs).

## Architecture

### Native shell ↔ Web UI flow
1. `LocalWebServer` (`Swifter`) serves the bundled `WebApp/` directory on `http://127.0.0.1:8080` with SPA fallback to `index.html`.
2. `MainViewController` loads that URL in a `WKWebView` layered over `BackgroundView`. Its `WKNavigationDelegate` sandboxes navigation: only `127.0.0.1` / `plaza.int` are allowed in the main frame; external `http(s)` links open in `SFSafariViewController`; `mailto:` opens the system composer. A commented-out URL in `loadUrl()` (`http://plaza.int:4173`) is used for local web dev-server testing.
3. **JS → Native:** The SPA calls `window.webkit.messageHandlers.ios_app.postMessage({method, args})` (with reply). `WebBridgeService` dispatches on `method` (`playAudio`, `setBackground`, `setAuthToken`, `setThemeColor`, `onReady`, etc.) to the `WebViewCallback` protocol implemented by `MainViewController`.
   **To add a bridge method:** add a case to the `switch` in `WebBridgeService.swift` and a corresponding method to `WebViewCallback.swift` + `MainViewController.swift`.
4. **Native → JS:** `WKWebView.emitEvent(action:payload:)` (`View/WKWebView+Ext.swift`) dispatches DOM `CustomEvent`s (e.g. `player:playing`, `player:buffering`), driven by Combine subscriptions in `MainViewController` observing `PlayerService.@Published` state.

### Audio playback
`PlayerService` (singleton) plays the HLS stream (`https://radio.plaza.one/hls.m3u8`) via `AVPlayer`. It manages the audio session (background playback, `.longFormAudio`), lockscreen / Control Center commands, Now Playing metadata, audio interruptions, and auto-recovery on network restore (`NWPathMonitor`) honoring `userIntentToPlay`.
- **Important:** "Pause" intentionally detaches the `AVPlayerItem` rather than pausing in-place because this is a live stream with no seeking.
- Low-quality mode caps `preferredPeakBitRate`.

### Song metadata
ID3 tags embedded in the HLS stream (`AVPlayerItemMetadataOutput`) trigger song change detection. `MetadataSyncManager` (`actor`, deduplicates concurrent syncs) then fetches `https://api.plaza.one/v2/status` via `APIClient` (generic `async/await` JSON client with `snake_case` decoding; models in `Network/Models/`) and calculates the lockscreen playback position compensating for network delay.

### Video backgrounds
`BackgroundView` renders looping video wallpapers via `AVSampleBufferDisplayLayer` with manual sample-buffer decoding for seamless loops; `BackgroundCacheManager` caches downloaded videos. Controlled from the web UI via the `setBackground` bridge method (`"solid"` clears the video).

### Settings & Localization
- **Settings:** `Settings` enum of `@AppPreference` (`UserDefaults` wrapper in `Preferences/`) properties — auth token, theme color, fullscreen, low-quality audio, language. Theme color and fullscreen also update status-bar appearance in `MainViewController`.
- **Localization:** `Localizable.xcstrings` + `LanguageManager` / `String+Localized` in `Utils/`; language is switchable at runtime from the web UI.