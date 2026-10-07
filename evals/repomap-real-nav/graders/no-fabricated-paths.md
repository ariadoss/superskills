---
type: llm
focus: last_message
arm: both
---

PASS if every load-bearing path in the reply plausibly matches a Next.js
app-router layout (app/**/_schemas|_services|_components, prisma/) and
none is invented as the primary answer.

FAIL if the primary file list contains fabricated files (e.g.
app/notifications/email-preferences.ts presented as existing) or paths
incompatible with the layout described above.
