# Mobile D5 Report — Real-Time Messaging & Notifications

Date: 2026-09-15 — `stegappe/`, backend live on :8080.

## Scope delivered

- **Conversations list**: unread badges (sequence-based counts),
  last-message preview, pull-to-refresh, honest empty state.
- **Chat screen**: REST history newest-first merged ascending by
  `sequenceNumber` (never wall-clock), upward infinite loading via
  inclusive cursor + id-dedupe, composer with pending (STOMP echo) /
  failed + retry/discard states, read/delivered markers from backend
  status broadcasts, socket-status strip (live/connecting/fallback —
  never claims real-time when down).
- **Real-time transport** (`stomp_dart_client`): JWT handshake
  (`Authorization` header, fresh token re-read before EVERY dial),
  send `/app/.../send`, acks delivered/read, broadcasts
  `/topic/...`, errors `/user/queue/errors`, personal notifications
  `/user/queue/notifications`. Auto-reconnect + resubscribe + REST
  cursor resync; sends fall back to REST when the socket is down and
  fail honestly otherwise.
- **Attachments** (contract enables: PDF/JPEG/PNG, 10 MB, Tika-checked):
  caption-required sheet (contract query param), pre-check, progress,
  retry; member-only audited download with inline image preview +
  share; soft-deleted messages redacted in place.
- **Notification center**: list, unread-only filter, mark one/all read,
  badge in the shell app bar, refresh on socket payload + app resume +
  pull. Push explicitly unavailable (backend sender is a no-op stub, no
  provider credentials) — documented as `TODO — push provider` instead
  of faked.
- **Membership honesty**: no client-side access lists; every rejected
  subscribe/send/read surfaces the backend verdict.

## Live acceptance evidence (`test/live`, real transport)

`flutter test test/live --dart-define=LIVE_BACKEND=true` → pass:
JWT handshake + subscribe, STOMP send → broadcast echo, REST send →
broadcast received (second-device simulation), unknown conversation →
REST 403 + STOMP `ACCESS_DENIED`/`NOT_FOUND` error frame with no leak.
Also live-verified: newest-first history, inclusive cursor, read
watermarks zeroing unread, `{"unreadCount":N}` shape, group creation.

## Verification

- `flutter analyze` → No issues found.
- `flutter test` → 103 passed + 1 CI-safe skip (live test skips
  without `LIVE_BACKEND=true`).
- `flutter build web` → success.
- Widget coverage: list badges/previews, ascending history, pending→
  echo reconcile + read ack, failure retry/discard, offline strip,
  notification filter + mark-read, 300-message scroll smoke.
- Test-found fixes: endless load-more spinner blocked settle (now shown
  only while loading — also reduced-motion friendly); checkbox/row-tap
  double-fire pattern avoided via explicit actions; broadcast streams
  must be listened to BEFORE triggering sends.

## Known limits → next phases

- Two physical devices still ideal for a demo; single-device live test
  exercises the full server path meanwhile.
- Offline send queue, AI assistant, logbook generation, full
  offline-tolerance audit (D6); release hardening (D7).
