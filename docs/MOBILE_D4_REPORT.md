# Mobile D4 Report — Supervisor Workspace & Evaluations

Date: 2026-09-15 — `stegappe/`, backend live on :8080.

## Scope delivered

- **Supervisor home**: queue cards (pending journal/deliverables →
  Validations tab), needs-attention intern list, full intern list.
- **Interns list + intern file**: per-intern backend progress (task
  counts, pending journal/deliverables, evaluation count); detail shows
  header, task progress, planned tasks (read-only), journals awaiting
  validation (→ review), deliverables (→ versioned detail), evaluations
  + New-evaluation entry. Planned/recorded/assessed work stay in
  distinct sections.
- **Template-driven evaluation form**: template picker (active only) →
  criteria inputs generated from backend (0..maxScore, per-criterion
  comment) → type/date → task reviews linked to REAL tasks (include,
  completed, optional score/comment) → feedback/advice field (explicitly
  separate from journal) → indicative estimate → explicit confirmation →
  sequential submit (create → scores → reviews) → SERVER detail screen
  with the authoritative total. No hard-coded criteria anywhere.
- **Estimate honesty**: mirrors the backend formula
  (Σ score/max×weight / Σweight × 20, HALF_UP 2dp, verified against
  `EvaluationService.computeWeightedTotal`), labeled indicative with a
  server-authoritative note; null when nothing scorable.
- **Intern read-only**: My Evaluations (from dashboard) + shared detail
  screen show server totals/scores/reviews/comments with zero form or
  review actions.
- **Consequential actions**: evaluation submit behind a confirmation
  dialog stating it becomes an official intern-visible record; all
  decisions show server-result snackbars.

## Live-backend findings

- Real data: 1 ACTIVE internship + placeholder template (server-marked
  TODO STEG VALIDATION) + 4 live criteria — form proven against it.
- Seed supervisor is NOT assigned to that internship: item endpoints
  403 correctly (backend ownership enforcement works; UI surfaces it).
- Scores endpoints return **500 (not 404/envelope) for unknown
  evaluations** — backend-side wart, flagged as follow-up; the app maps
  it to the generic server error honestly.
- Templates list is SUPERVISOR-visible; interns never call it (detail
  endpoints are participant-scoped).

## Verification

- `flutter analyze` → No issues found.
- `flutter test` → 85/85 passed (estimate math incl. HALF_UP case,
  payload shapes, home/list/detail rendering, template→estimate→
  confirm→server-total flow, invalid-score blocking, intern read-only).
- `flutter build web` → success.
- Test lesson re-learned: plain `ListView` builds lazily — below-fold
  assertions scroll first (also fixed one D2-adjacent assertion).

## Known limits → next phases

- Full supervisor round-trip awaits assigned-supervisor seed data (E6).
- Messaging + notification center (D5), offline queue + AI/logbook (D6).
