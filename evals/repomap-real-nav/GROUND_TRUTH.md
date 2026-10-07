# payroll-next navigation ground truth (CORRECTED after pilot calibration 2026-10-07)

The first draft of this key was prisma-centric and WRONG: notifications in
this repo are owned by the Frappe backend — the app reads them via
frappeFetch (notifications-service.ts), prisma/schema.prisma has NO
Notification model, and the preference toggles are stubbed TODOs. The
pilot's cold run found the true architecture; the instrument, not the run,
was broken. Repair registered before any arm.

## Core set (all four areas required)
1. app/app/(private)/(dashboard)/settings/_components/settings-page-client.tsx
   — NOTIFICATION_GROUPS (line ~347) + the stubbed prefs save (TODO ~425).
2. app/app/(private)/(dashboard)/notifications/_schemas/notification-schemas.ts
   — the NotificationRecord shape a new type must satisfy.
3. app/app/(private)/(dashboard)/notifications/_services/notifications-service.ts
   (+ notifications-realtime.ts) — the frappeFetch read/mark path.
4. app/lib/frappe.ts (and/or _services/api.ts frappeFetch) — allowed-methods
   list for new notification/preference endpoints.

## The architectural point a great answer makes
The notification is CREATED and emailed by the Frappe backend, outside this
repo — noting that the backend side lives there (not here) is a correctness
signal, not scope-dodging.

## Optional extras
NotificationsProvider.tsx, use-notifications-page.ts, a new
api/profile/notifications route, lib/types.ts union.

## WRONG if
- the reply claims prisma/schema.prisma carries the Notification model or
  that the preference persists in Prisma (it doesn't — the save is a stub
  and the backend owns it),
- an existing email-sender file is invented in this repo,
- none of the notifications _schemas/_services files is identified.
