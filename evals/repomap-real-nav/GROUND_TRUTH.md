# payroll-next navigation ground truth (grep-derived 2026-10-07)

## Core set (all four areas required)
1. app/prisma/schema.prisma — Notification model + user preference field/model.
2. app/app/(private)/(dashboard)/notifications/_schemas/notification-schemas.ts — the notification type union/validation.
3. app/app/(private)/(dashboard)/notifications/_services/notifications-service.ts (+ notifications-realtime.ts where delivery is handled) — emitting/reading the new type.
4. NotificationsProvider.tsx and/or notifications/page.tsx + use-notifications-page.ts — UI consumption; and any email-sending service path the codebase uses for notification delivery (server-side sender file) OR the preference UI location.

## Optional extras (fine, never required)
migration file reference (prisma migrations are generated), notification-count.ts,
_schemas files for contractors/invoices if the dispute link is wired.

## WRONG if
- no schema.prisma change is identified,
- no zod/schema union file is identified,
- files unrelated to notifications/preferences dominate the list,
- paths are invented.
