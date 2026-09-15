# Mobile Foundation Report (Phase D0)

Date: 2026-09-15 — `stegappe/` (Flutter 3.47.2 / Dart 3.13.2).
Baseline was the default counter template; no project recreation occurred.

## Decisions (see `docs/DECISIONS.md`)

Single state-management solution: **Riverpod 2.x**, used consistently
(providers, StateNotifier controllers, connectivity stream).

## What was built

- Clean Architecture per feature: `domain/` (pure Dart entities +
  repository contracts) ← `data/` (OpenAPI-typed models, datasources,
  repository impls) ← `presentation/` (Riverpod providers, screens).
- Central typed `ApiClient` (base URL via `--dart-define=API_BASE_URL`,
  Bearer injection, timeouts) with centralized `ApiException` mapping of
  the STEG error envelope + Spring ProblemDetail + transport failures.
  `Endpoints` mirrors `steg-backend/docs/openapi.json` paths.
- `SecureTokenStorage` (`flutter_secure_storage`, encrypted prefs on
  Android) for JWT/refresh. `SharedPreferences` holds only locale/theme.
- Design system: STEG tokens (#0B61A0, #D32325, #B02927, #042843),
  light/dark themes, `StegButton` (48px, loading), `StegCard`,
  `StegStatusChip` (text+icon, never color-only), confirm dialog +
  bottom sheet, `StegLoading`/`StegErrorView` (traceId, retry)/
  `StegEmptyView`, labeled `StegTextField`, `BidiText` for LTR values.
- Role-aware navigation: `AuthGate` → login → `InternShell`
  (Home/Tasks/Journal/Messages/More) / `SupervisorShell`
  (Home/Interns/Validations/Messages/More) / access-denied screen for
  non-mobile backend roles. Client routing is UX only; backend
  re-authorizes everything.
- fr (default) / en / ar localization with persisted choice; genuine RTL
  (directional widgets, mirrored nav, bidi-safe technical values).
- `ConnectivityBanner` (online/offline, live-region announced) on every
  shell; offline content is labeled stale.
- Accessibility: 48px targets, single-announcement semantics
  (`excludeSemantics` where label duplicates text), text scaling honored
  (no fixed heights), `disableAnimations` respected.
- CI: `.github/workflows/mobile-ci.yml` runs
  `flutter analyze` + `flutter test` on `stegappe/**` changes.

## Verification evidence

- `flutter analyze` → **No issues found!**
- `flutter test` → **All 20 tests passed** (error-envelope mapping,
  l10n key completeness fr/en/ar, auth repo token handling + role
  routing, both shells render, unsupported-role denial, login when
  logged out, real RTL Directionality + Arabic labels, 48px touch
  target, chip text+icon, offline announcement).
- Screens use only shared primitives — no feature-local buttons/cards.

## Acceptance

Authenticated shells for INTERN and SUPERVISOR render correctly and the
design system is reusable across all features. Real backend data wiring
is Phase D1+ scope (D0 tabs are navigable placeholders with proper
empty states).
