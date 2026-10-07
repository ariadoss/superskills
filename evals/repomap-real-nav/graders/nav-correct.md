---
type: llm
focus: last_message
arm: both
---

Key: the notification system lives in app/prisma/schema.prisma (models),
app/app/(private)/(dashboard)/notifications/ (_schemas/notification-schemas.ts
for the type union, _services/notifications-service.ts and
notifications-realtime.ts for delivery, page.tsx + use-notifications-page.ts
for UI), and _components/NotificationsProvider.tsx for consumption. A
per-user preference needs schema.prisma plus a preferences/settings
surface if one exists.

PASS if the reply identifies schema.prisma AND the notifications
_schemas file AND at least one _services file AND a UI file
(Provider/page/hook), each with a plausible why.

FAIL if schema.prisma or the type-union file is missing, or the list is
dominated by unrelated files. Invented paths also fail (see sibling
grader).
