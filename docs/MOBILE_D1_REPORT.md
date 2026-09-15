# Mobile D1 Report — Intern Daily Workspace

Date: 2026-09-15 — `stegappe/` (Flutter 3.47.2 / Dart 3.13.2), backend live on :8080.

## Scope delivered

- **Home dashboard**: identity header (reference, backend-computed type,
  status, department/supervisor), task progress + timeline progress,
  Today's priorities (overdue + due-today), current-week tasks, pending
  journal, open deliverables, latest evaluation (backend `totalScore`),
  recent notifications + unread counts + mark-all-read.
- **Timeline screen**: start/end dates, current phase
  (not-started/in-progress/finished from backend status + dates),
  milestones strictly from backend data (period bounds, assignment
  history, received evaluations).
- **Task list**: backend `?status=` filters (All/To do/In progress/Done),
  due dates, overdue highlighting, completion checkbox + detail sheet
  with server-confirmed transitions (start/complete/reopen), "+N more"
  honesty when collections exceed the page.
- **Journal tab**: read-only list with validation states (write flows: D2).
- **Refresh + stale**: pull-to-refresh everywhere; offline renders the
  last-good snapshot under an explicit stale notice, never blank/silent.
- **States**: loading / error + retry / empty / no-linked-internship on
  every async surface, all from shared D0 primitives.

## Planning-model separation (enforced)

`Task` (planned) / `JournalEntry` (actually happened) / `Evaluation`
(assessment) are distinct entities, fetched from distinct endpoints,
aggregated by a pure, unit-tested `buildDashboard` — no invented scores.
Progress = backend task counts (`totalElements`) + date-fraction from
backend dates only.

## Live-backend findings (verified, not assumed)

- JWT roles are `ROLE_*`-prefixed → fixed `userRoleFromBackend`
  (previously denied every real user). Regression-tested.
- Bad login returns **422** envelope → mapped to validation.
- Real page shape is `{content, page:{totalElements,…}}`, NOT the flat
  OpenAPI shape → `Paged.fromJson` handles both (live-verified on
  `/api/notifications`; tasks/journal/deliverables share Spring Pageable).
- Error envelope matches `ApiException` mapping exactly (403/422 probes).
- PATCH task-status + journal endpoints exist per contract.
- **Gap (backend follow-up, non-blocking)**: no `GET /api/internships/mine`;
  the app resolves the internship via cached id → verify, else PRIVATE
  conversation `internshipId` → verify + cache, else honest empty state.
  A dedicated endpoint would be cleaner (`TODO — backend phase`).

## Verification

- `flutter analyze` → No issues found.
- `flutter test` → 44/44 passed (dashboard split logic, Paged shapes,
  resolver paths, ROLE_/422 regressions, dashboard/timeline/tasks/journal
  widgets, RTL Arabic, stale rendering, no-internship state).
- `flutter build web` → success.
- Live probes: login, conversations `[]`, notifications page shape,
  403/422 envelopes, PATCH + journal-list paths.

## Known limits → next phases

- No intern seed account exists yet: full intern round-trip awaits demo
  data (Phase E6); dashboard proven with fixtures + live contract probes.
- Journal creation/submission (D2), deliverable upload/versioning (D3),
  supervisor workspace (D4), messaging + notification center (D5).
