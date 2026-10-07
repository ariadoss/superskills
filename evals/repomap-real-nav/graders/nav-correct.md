---
type: llm
focus: last_message
arm: both
---

Architecture key: notifications are owned by a Frappe backend; this Next.js
repo consumes them via frappeFetch. The true change set: settings-page-client.tsx
(NOTIFICATION_GROUPS ~347 + the stubbed prefs-save TODO ~425),
notifications/_schemas/notification-schemas.ts (NotificationRecord),
notifications/_services/notifications-service.ts (+notifications-realtime.ts,
the frappeFetch path), and lib/frappe.ts / _services/api.ts (allowed-methods
for new endpoints). schema.prisma has NO Notification model.

PASS if the reply identifies the settings component AND a notifications
_schemas or _services file AND the frappe client surface (lib/frappe.ts or
api.ts), each with a plausible why — and does NOT claim prisma owns the
notification model. Noting that creation/emailing happens in the Frappe
backend (outside this repo) is a positive signal.

FAIL if prisma/schema.prisma is presented as the notification store, an
email sender is invented in this repo, or none of the notifications
client files appear.
