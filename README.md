# Nightwave Plaza for iOS

iOS client for [Nightwave Plaza](https://plaza.one), a 24/7 vaporwave radio.

The UI is a web app (a mobile build of the plaza.one interface) shown in a WKWebView. Everything else is native: audio playback, lock screen controls, metadata, video backgrounds.

## Requirements

- Xcode 27.1 or newer
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

## GitHub Actions

Both workflows are started manually from the Actions tab:

- **TestFlight Internal Testing** (`ios-testflight.yml`): runs on `master`, downloads
  the current production web UI with SHA-256 verification, archives a Release build,
  signs it and uploads to TestFlight Internal Only. It does not wait for simulators.
  Apple still needs to process the uploaded build.
- **iOS Smoke and Screenshots** (`ios-screenshots.yml`): builds and runs the bundled
  app on iPhone Duo and iPhone 18 Pro in independent matrix jobs. Each job requires
  the real web UI's `onReady` handshake before capturing screenshots. A failure on
  one device does not cancel the other. This checks startup and the bridge, not
  audio playback or all UI interactions.

Both use the `xcode-27` runner and Xcode 27.1. The smoke script selects the newest
available iOS 27 runtime whose `supportedDeviceTypes` includes the requested phone:
currently iOS 27.1 for Duo and iOS 27.0 for 18 Pro. A missing compatible runtime
fails explicitly; a different phone is never substituted.

Download `screenshots-<device>-<attempt>` from the smoke run's artifacts: Duo has
`small` and `large` PNGs; 18 Pro has one PNG. Duo is folded before `small` and
unfolded before `large`, with the active display verified before capture. CI uses
[duoctl](https://github.com/skarol/duoctl) pinned to commit
`c6ff3e961a9858fb061907448e702d7d1617dc4a` to animate the hinge; this relies on
private simulator interfaces and is confined to CI, not the app. Pose state is
saved in `*.pose.log`. Black/transparent frames are retried for up to 30 seconds;
a persistently blank frame fails the job. This pixel check does not prove the UI
is correct. Failure captures have a `-failure` suffix and preserve the current
pose without attempting to fold the device. `simulator-diagnostics-<device>-<attempt>` includes the
runtime inventory, boot/install/app logs and build result. Distribution logs and
dSYMs are in `testflight-diagnostics-<attempt>`.

The GitHub environment `testflight` must contain:

- Variable `APPLE_TEAM_ID`.
- Secrets `DISTRIBUTION_P12_BASE64`, `DISTRIBUTION_P12_PASSWORD` and
  `PROVISIONING_PROFILE_BASE64` (App Store distribution profile for
  `com.nightwaveplaza.NightwavePlaza`).
- Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_BASE64` for the App Store
  Connect API key with permission to upload this app.

Before Keychain import, CI verifies the source `.p12` with OpenSSL and repackages
it with SHA-1/3DES PKCS12 algorithms for compatibility with Apple's importer.
The intermediate private key remains encrypted; temporary files are removed on
exit. The original GitHub secrets do not need conversion. An OpenSSL verification
failure is reported separately from a Keychain import failure.

Signing preflight checks the profile's iOS platform, team, bundle ID, distribution
type, expiration and certificate fingerprints against valid code-signing identities
in the temporary Keychain. The profile's UUID is preserved as issued. CI installs
it in both `~/Library/Developer/Xcode/UserData/Provisioning Profiles` and
`~/Library/MobileDevice/Provisioning Profiles`, verifies the copies and removes
them on exit. `signing.log` records validation and profile locations without private
keys or the full profile; it also records whether the copies survived until cleanup.

The optional `build_number` input overrides the generated build number
(`1000 + github.run_number`, followed by the run attempt). Overrides must exceed
previous TestFlight builds; after a large manual override, subsequent runs may
also need an override. CI creates an empty `SENTRY_DSN` configuration.

Local smoke-script regression checks (Python 3.11+):

```sh
python3 -m pip install -r Scripts/requirements-ci.txt
python3 -m unittest discover -s Scripts -p 'test_ci_simulator_smoke.py' -v
```

The previous TestFlight run [41448050956](https://github.com/nightwaveplaza/app-ios/actions/runs/41448050956)
compiled successfully and passed the Duo handshake, then failed creating 18 Pro
on the Duo-only iOS 27.1 runtime (simctl exit 147). Its signing/upload job was
skipped because it depended on that smoke job. Runtime compatibility is also
tracked in [actions/runner-images#15000](https://github.com/actions/runner-images/issues/15000).

## How it works

- `Scripts/fetch_view.sh` downloads the pre-built web UI into `NightwavePlaza/WebApp`. This folder is not stored in git.
- On launch the app starts a local server on `127.0.0.1:8080` and loads it in a WKWebView.
- The web UI talks to the native side through a JS bridge: playback control, backgrounds, sleep timer, theme color and language.
- Song metadata comes from ID3 tags in the HLS stream, then the app fetches song details from the Plaza API for the lock screen.

## Comments

- Comment only non-obvious logic — do not comment self-explanatory code.
- Write brief, plain English comments without flowery language.
- Start comments with a capital letter and omit trailing periods.
- Describe the code as it is now (e.g., `// Done this way because...`), never the editing history or diff (`// Changed A to B...`).
