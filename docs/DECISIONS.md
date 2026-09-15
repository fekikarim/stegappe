# Mobile Foundation Decisions (Phase D0)

State management, architecture, and cross-cutting choices for `stegappe`.
Rule: one solution per concern, used consistently across all features.

## 1. State management — Riverpod 2.x (`flutter_riverpod`)

Chosen over Bloc and GetX/Provider:

- Compile-safe providers with straightforward unit/widget testing
  (override any provider; no BuildContext-dependent setup).
- Fits Clean Architecture: `data → repository → StateNotifier/Notifier → UI`.
- No event/state boilerplate per screen (Bloc) and no service-locator
  anti-patterns (GetX).
- `StateNotifierProvider` for `AuthController`, `LocaleController`,
  `ThemeModeController`; `StreamProvider`/`Provider` for connectivity.
- Async UI states reuse `StegLoading` / `StegErrorView` / `StegEmptyView`.

## 2. Clean Architecture per feature

```text
lib/features/<feature>/
  domain/        pure Dart: entities + repository contracts (no Flutter)
  data/          models (OpenAPI-typed) + datasources + repository impls
  presentation/  providers + screens + widgets
lib/core/        config, network, storage, l10n, theme, widgets, connectivity
```

Dependency rule: `presentation → domain ← data`. Features never import
each other's `data/` layers. Business rules stay on the backend; the app
only displays backend-computed values (internship type, payment amounts).

## 3. Typed API client from OpenAPI

- `lib/core/network/api_client.dart`: single HTTP entry point (base URL,
  Bearer injection, timeout, 401 refresh hook, error mapping).
- `lib/core/network/api_exception.dart`: maps the STEG error envelope
  `{timestamp,status,error,message,path,traceId,fieldErrors[]}` and Spring
  ProblemDetail, plus transport failures → `ApiErrorKind.network`.
- `lib/core/network/endpoints.dart`: path constants from
  `steg-backend/docs/openapi.json`. Full OpenAPI codegen (e.g.
  `openapi-generator-dart`) is deferred until contract freeze (Phase E0);
  until then, hand-written DTOs mirror schema names (`AuthResponse`, …).
- No feature-level `http.*` calls allowed.

## 4. Secure token storage

- `TokenStorage` → `SecureTokenStorage` (`flutter_secure_storage` with
  encrypted prefs on Android). `InMemoryTokenStorage` for tests only.
- `SharedPreferences` (`PrefsStore`) holds ONLY locale/theme — never tokens.
- Logout always clears local tokens even if remote revocation fails.
- JWT claims are decoded for routing convenience only; the backend
  re-authorizes every request (never trust client roles).

## 5. Localization — fr/en/ar, genuine RTL

- Hand-rolled `AppLocalizations` tables (no codegen yet) with a unit test
  asserting every key exists in fr+en+ar.
- French default; persisted choice; system fallback → French.
- RTL: `MaterialApp` + `Global*Localizations` delegates; widgets use
  directional APIs (`NavigationBar`, `EdgeInsetsDirectional`,
  `AlignmentDirectional`); technical values (email, traceId, references)
  wrapped in `Directionality(ltr)` (`BidiText`). Widget test pumps the
  `ar` locale and asserts `TextDirection.rtl`.
- Arabic font: system stack with `Noto Sans Arabic` fallback, line height
  ≥ 1.4; no fixed-width containers for labels.

## 6. Connectivity

- `connectivity_plus` → `isOnlineProvider`; `ConnectivityBanner` on every
  shell. Offline content is labeled stale; pending mutations retry
  explicitly (full offline queue is Phase D6 scope).

## 7. Accessibility

- 48px minimum touch targets (`StegButton`, icon buttons via theme).
- `Semantics` on buttons, chips, banners, states, nav; `liveRegion` on
  loading/error/offline announcements.
- Text scaling honored (no fixed heights, `Flexible`/`Wrap` in chips/cards).
- Reduced motion: `MediaQuery.disableAnimations` disables shell
  `AnimatedSwitcher`; no information conveyed by motion alone.

## 8. Auth & roles (mobile scope: INTERN + SUPERVISOR)

- `AuthGate`: splash → login → `InternShell` / `SupervisorShell` /
  `UnsupportedRoleScreen` (other backend roles get explicit denial).
- Shells: intern (Home/Tasks/Journal/Messages/More), supervisor
  (Home/Interns/Validations/Messages/More). D0 tabs are placeholders with
  real navigation + empty states; D1+ wires backend data.
- Live JWTs carry `ROLE_*`-prefixed authorities — stripped before matching.

## 9. Internship-id resolution (D1, backend has no `/mine` endpoint)

`InternshipRepository.resolveMyInternshipId`: cached id → verify via GET
detail → else PRIVATE conversation `internshipId` (auto-created on
assignment) → verify + cache → else null (honest empty state). 403/404
invalidates the cache; network errors rethrow so the UI renders stale
cache instead of wiping. `TODO — backend phase`: a dedicated
`GET /api/internships/mine` would replace conversation-based discovery.

## 10. Daily-loop policies (D2)

- Optimistic UI ONLY for reversible actions (task completion toggle,
  with rollback + error message). Supervisor validate/reject and all
  creates/submits are server-confirmed; offline failures are shown, never
  implied as done.
- Journal autosave is a pre-creation LOCAL draft (SharedPreferences,
  per internship + day, cleared on server create). Server-created entries
  are immutable — the backend exposes no update endpoint, so the app
  offers no edit UI for them (submit-only transitions).
- Task ≠ Journal is structural: separate tabs, endpoints, entities, and
  composer microcopy; the app never derives journal content from tasks.

## 11. Deliverable policies (D3)

- Files validate as `STEG_INTERNSHIP_REPORT` (backend Tika): PDF-only,
  25 MB. The app shows these exact limits, pre-checks client-side, and
  never offers camera/gallery (images would be server-rejected; the demo
  image belongs to the Finance dossier, not mobile endpoints).
- Versions are append-only history (backend bumps `currentVersion`);
  VALIDATED deliverables refuse new versions — surfaced explicitly.
- No "expected deliverables" template exists in the contract, so the
  checklist groups actuals by state instead of inventing requirements.
- Downloads are Bearer-only endpoint bytes → temp file → share sheet;
  share is provider-injected because path_provider pends in widget tests.

## 12. Supervisor evaluation policies (D4)

- Evaluation forms are generated from backend templates + criteria;
  official criteria are never hard-coded (seeded placeholder is
  server-marked TODO STEG VALIDATION REQUIRED).
- Live estimate mirrors the backend weighted formula for UX only and is
  labeled indicative; the displayed total always comes from the server
  response afterwards.
- Task reviews link evaluations to real tasks (same-internship enforced
  server-side); feedback/advice lives on the evaluation, never mixed
  into journal text. Interns see evaluations strictly read-only.
- "Supervised" lists derive from assignment-created PRIVATE
  conversations; every mutation is still server-authorized per request.
