# Mobile D3 Report — Deliverables & Review

Date: 2026-09-15 — `stegappe/`, backend live on :8080.

## Scope delivered

- **Creation + version upload**: file-picker PDFs, title/description,
  exact backend-confirmed limits shown (PDF only · 25 MB max), real
  chunked-stream progress, retry without losing the form, server
  field-errors mapped inline.
- **Version history**: every version listed newest-first with number,
  filename, size, uploader, change note and date; new uploads append
  (`currentVersion` bumped server-side) — never overwrite; VALIDATED
  deliverables explicitly block new versions with an explanation.
- **Review loop**: intern submit (DRAFT/REJECTED), supervisor
  validate/reject with comments (correction requires explanation),
  all server-confirmed; feedback comments visible in detail.
- **Checklist**: actuals grouped by state (to-finalize / awaiting
  validation / validated) with counts — no backend "expected
  deliverables" template exists, so nothing is invented.
- **Secure download**: Bearer-only endpoint bytes → temp file → platform
  share sheet; per-version download; no public URLs, no storage keys.
- **Supervisor queue**: validations screen gains a deliverables section
  (SUBMITTED across supervised internships) with reference labels.

## Backend-confirmed constraints (code + live probes)

- Deliverable bytes validate as `STEG_INTERNSHIP_REPORT` (Tika):
  **PDF-only, 25 MB**. Client pre-check mirrors exactly; backend is
  authoritative. No camera/gallery path: images would be server-rejected;
  the optional live-demo image belongs to the Finance dossier
  (back-office scope), not mobile deliverable endpoints.
- Transitions: submit DRAFT/REJECTED→SUBMITTED; validate/reject
  SUBMITTED-only + `isSupervisorOf`; new version forbidden once VALIDATED.
- All six touched endpoints live-probed (multipart create/version +
  submit/validate/versions/download): envelope errors + 403 enforcement.

## Verification

- `flutter analyze` → No issues found.
- `flutter test` → 70/70 passed (file-rule matrix, checklist grouping,
  version order + immutability, endpoint download recording, creation
  gating, supervisor review decisions).
- `flutter build web` → success.
- Test-found fixes: upload button disabled without file; share layer
  injectable (`path_provider` pends forever in widget tests).

## Known limits → next phases

- Full intern round-trip still awaits intern demo seed data (E6).
- Supervisor workspace + evaluations (D4), messaging + notification
  center (D5), offline upload queue (D6).
