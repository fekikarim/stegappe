# Release Runbook — STEG Internship Companion (`stegappe/`)

## Application identity

- Android `applicationId` / namespace: `tn.steg.stegappe`
- iOS bundle id: `tn.steg.stegappe`
- Change both only via a tracked commit (they identify the app in
  stores, not a business fact).

## Environment configuration (no secrets in the repo)

```sh
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.steg.tn \
  --dart-define=WS_BASE_URL=wss://api.steg.tn
```

- `API_BASE_URL` defaults to `http://10.0.2.2:8080` (Android emulator
  loopback to a host backend). Always override for any shared build.
- `WS_BASE_URL` defaults to the ws(s) twin of `API_BASE_URL`.
- Version comes from `pubspec.yaml` (`flutter.versionCode/Name`).

## Android release signing (never commit secrets)

1. Generate the keystore once, OFF the repo machine path:
   `keytool -genkey -v -keystore stegappe-release.keystore -alias stegappe-release -keyalg RSA -keysize 2048 -validity 10000`
2. `cp android/key.properties.example android/key.properties`
   (git-ignored) and fill the real passwords + absolute store path.
3. `flutter build appbundle --release --dart-define=...`
4. Without `key.properties`, release builds fall back to debug keys —
   local testing only, never distribution.

The `.keystore` file and `key.properties` MUST NOT appear in git
(`android/.gitignore` covers `key.properties`; keep keystores outside
the repo entirely).

## iOS release

- Open `ios/Runner.xcworkspace`, select the Team + provisioning for
  `tn.steg.stegappe`, then Product → Archive.
- No signing secrets live in the repo (Xcode manages them).

## Pre-release gate (must all pass)

```sh
flutter analyze
flutter test
flutter test test/live --dart-define=LIVE_BACKEND=true   # needs local backend
flutter build appbundle --release --dart-define=API_BASE_URL=...
```

Plus the current `docs/MOBILE_QA_REPORT.md` acceptance items.
