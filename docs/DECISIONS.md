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
