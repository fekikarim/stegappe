# Mobile QA Report (Phase D6 — STEG Internship Companion)

Date: 2026-09-16 — `stegappe/` (Flutter 3.47.2 / Dart 3.13.2).
Covers D0–D6. Companion reports: `docs/MOBILE_D0_REPORT.md` …
`docs/MOBILE_D5_REPORT.md`. Decisions: `docs/DECISIONS.md`.

## 1. Verification summary

- `flutter analyze` → **No issues found!**
- `flutter test` → **111 passed + 1 skip** (live STOMP round-trip skips
  without `--dart-define=LIVE_BACKEND=true`, so CI stays green).
- `flutter build web` → success.
- Live backend probes (auth, CRUD, STOMP handshake/subscribe/send/
  broadcast, 403 envelopes, rate-limit paths) all green; see phase
  reports for transcripts.

## 2. Integration journey (task 9)

Provider-driven end-to-end test (`test/journey_test.dart`) with fakes
behind the REAL providers: login → session → internship resolution →
dashboard (today's tasks) → task create → complete → journal create →
submit → supervisor validate → deliverable create → submit → STOMP
message send → evaluation create + scores + task review (server total
asserted) → logbook draft (CIN-excluded asserted). Passes.
Supervisor-only transitions are additionally covered by widget tests;
the live backend enforces `isSupervisorOf` per request (403-probed).

## 3. Offline-tolerance audit (task 7)

| Surface | Offline behavior | Verdict |
|---|---|---|
| Login | error banner, values preserved, retry | OK |
| Dashboard / tasks / journal / deliverables lists | last-good snapshot + stale notice; else error + retry | OK (journal last-good added in D6) |
| Timeline / progress / evaluations / intern file | error + retry | OK |
| Task create/edit/status, journal create/submit | inline errors, forms stay open; toggle rolls back | OK |
| Journal/deliverable validate/reject, evaluation submit | dialogs stay open on failure; offline visibly fails | OK |
| Chat | init error + retry; socket strip; failed bubbles + retry/discard | OK |
| Uploads/downloads | progress + failure + retry; share errors snackbared | OK |
| Notifications mark-read | failure snackbar, no state change | OK |
| 409 conflicts | envelope message surfaced; forms stay open for explicit retry | OK (documented; no silent overwrite anywhere) |

No path shows unconfirmed success. No offline mutation queue exists
yet by design (explicit D6+ scope): failures are immediate + retriable.

## 4. i18n / RTL / accessibility audit (task 8)

- **Locales**: fr (default) / en / ar complete — unit test asserts every
  key in all three. Fixed in D6: password show/hide tooltips, week
  arrows (were glyph/English-only).
- **RTL**: directional widgets only (verified: full-padding audit finds
  only vertical `EdgeInsets.only`); mirrored nav, chevrons, drawer-side
  patterns; bidi-safe technical values (`BidiText`, trace/counter LTR);
  widget tests assert real `TextDirection.rtl` + Arabic labels.
- **Touch targets**: 48px buttons/fields/checkbox rows; ChoiceChips use
  padded (48px) tap targets per Material default.
- **Text scaling**: 2x + Arabic stress tests on dashboard, progress,
  chat. Found + fixed a REAL overflow (`LabeledProgress` counter row →
  Wrap; task chip wrapped Flexible).
- **Reduced motion**: shell transitions + chat auto-scroll honor
  `disableAnimations`; no information is motion-only.
- **Semantics**: single-announcement labels (`excludeSemantics` where
  label duplicates text — fixed double-announce in D0), live regions
  for loading/error/offline/validation, labeled icon-only actions.
- **Contrast**: navy/primary on light surfaces, brightened primary on
  deep-navy dark surfaces; status never color-only (icon + text).

## 5. AI safety posture (tasks 1–5)

- Only participant-authorized endpoint is used (logbook draft);
  assistant Q&A is CANDIDATE-role-only (403-probed) and therefore NOT
  shipped — documented as backend follow-up instead of faked.
- Advisory labeling everywhere; draft is review-only editable text,
  never auto-submitted; no approve/finance/status capability exists.
- Client sends only the internship id (CIN structurally unreachable);
  `cinExcluded` flag displayed from the server response.
- Outage/rate-limit/timeout → retry card; core flows verified intact
  while AI fails (widget test).
- Mobile is fully useful without AI (acceptance holds).

## 6. Performance notes (task 11 + D5)

- Paginated lists (20–50/page) with `+N more` honesty; 300-message
  scroll smoke passes; reversed chat builds visible window only;
  uploads stream in 64 KB chunks; downloads stream to bytes.
- No measured jank in tests; on-device profiling remains D7 scope.

## 7. Fixed during D6

1. LabeledProgress counter overflow at 2x Arabic (Row → Wrap).
2. Task-row status chip inflexible at large text (Flexible).
3. Hard-coded Show/Hide + week-arrow tooltips → localized.
4. Journal list lacked stale snapshot (added last-good).
5. Chat auto-scroll ignored reduced-motion (jump instead).
6. Logbook header missed the AI badge text in review branch.

## 8. Remaining TODOs (honest, by owner)

- **Backend follow-ups**: `GET /api/internships/mine` (mobile currently
  discovers via assignment threads); intern-assistant Q&A for
  INTERN/SUPERVISOR roles (currently CANDIDATE-only); scores endpoints
  return 500 instead of 404 for unknown evaluations.
- **Seed data**: intern + assigned-supervisor accounts for full live
  round-trips (E6 demo data).
- **D7**: on-device profiling, release build config, notification
  navigation depth, offline mutation queue, push provider credentials.
- **STEG validation**: official evaluation criteria, certificate/receipt
  wording, retention policy (unchanged; templates carry the markers).
