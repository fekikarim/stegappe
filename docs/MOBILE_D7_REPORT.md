# Mobile D7 Report — Engineering & UX Gate

Date: 2026-09-16 — `stegappe/` (Flutter 3.47.2 / Dart 3.13.2).

## Verification

- `flutter analyze` → No issues found.
- `flutter test` → **123 passed + 1 skip** (live STOMP test).
- `flutter build web` → success.
- `flutter build apk --release` (prod defines) → success (58.8 MB).

## Gate items

- **Large histories**: paginated everywhere (tasks/journal 20–50,
  deliverables 50, messages 30/page + 500-item cap); builder/sliver
  lists only; 300-message scroll smoke passes.
- **Rebuilds**: providers watched at leaf granularity; controllers own
  transient state; no global rebuild loops found in audit.
- **Images/files**: attachment preview decodes downscaled
  (`ResizeImage` ≤1080px, 10 MB source cap); PDFs/images never rendered
  at full res in-app; uploads stream in 64 KB chunks; downloads stream.
- **Upload memory**: bounded chunk streaming proven by test (monotonic
  progress to total); ≤25 MB single-shot bytes accepted by design.
- **Retry/backoff**: `ReadRetryPolicy` (3 attempts, exp backoff) on
  idempotent GETs where reconnect storms hurt (conversations, history);
  transport/5xx only — auth/validation never spin; writes NEVER
  auto-retry (explicit user retry everywhere). Unit-tested.
- **Token refresh/logout**: expired JWT refreshes silently on restore;
  dead refresh wipes to clean re-login; logout revokes remotely then
  ALWAYS clears locally; logout disconnects STOMP + recreates the
  service, returning to login crash-free (gate widget test).
- **Resume/background**: notifications center + chat resync on resume;
  socket reconnect path re-subscribes + cursor-resyncs.
- **Deep links**: none used — no custom scheme, no Dynamic Links; all
  navigation is in-app (notification → mark-read → role-aware tab
  routing by related-entity type; unknown types stay put, never a dead
  tap). Documented as deliberate, not missing.
- **Notification navigation**: bell badge → center → entity-aware tab
  routing (intern: task/journal/messages; supervisor: validations/
  messages/interns).
- **Text scaling/long strings**: 2x + Arabic stress green; dedicated
  150-char Arabic/French overflow gate on cards/rows/bubbles.
- **Semantics**: icon-only actions all labeled (audit clean); live
  regions for async/offline/validation states; single announcements.
- **Offline honesty**: D6 audit stands; journal last-good added in D6.
- **Error boundaries**: `runZonedGuarded` + release fallback screen
  (debug keeps red screen); no crash SDK wired (no credentials).

## Blocking issue found + fixed

Release APK failed: `file_picker` 11 ships a legacy Android module
(Kotlin 1.8) incompatible with this project's AGP 9 / Kotlin 2.4
toolchain (`FilePickerPlugin` symbol missing). Migrated both pick
call-sites to the official `file_selector` (same UX, PDF/type filters
kept) — release build green. Lesson recorded: plugin Android-module
freshness is a release-gate check.

## Release readiness

- App ids: `tn.steg.stegappe` (Android + iOS); minSdk 24.
- Signing: `android/key.properties` (git-ignored) + `.example`
  template; debug-key fallback is local-only. No secrets in repo
  (verified: no keystore, no key.properties, no tokens).
- Procedure: `docs/RELEASE.md` (defines, signing, gate commands).

## Remaining (E6 / operations)

- Intern + assigned-supervisor seed data for full live round-trips.
- On-device profiling (cold start, scroll jank, upload memory).
- Push provider credentials + backend wiring (`TODO — push provider`).
- Store listing assets, Play/App signing, tester track rollout.
