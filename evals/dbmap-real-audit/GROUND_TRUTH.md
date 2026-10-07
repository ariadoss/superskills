# payroll-next audit ground truth (derived from schema.prisma 2026-10-07)

## Relation fields WITHOUT @@index (the schema's index gaps — 8 total)
EmployerLoginDirectory.tenant · TenantProvisioningRequest.tenant ·
PlatformAuditEvent.tenant · TokenBalance.hiringAccount ·
AgentTokenUsage.tenant · AgentTokenUsage.hiringAccount ·
Contractor.hiringAccount · ChatMessage.hiringAccount
(Any subset naming ≥5 with model.field precision counts as finding the gap
class; naming the tenant/hiringAccount pattern explicitly is the core.)

## Supplementary (never required)
Prisma query patterns in _services (findMany in loops, missing take/skip),
audit-event tables without retention bounds.

## WRONG if
- the audit claims indexed relations are un-indexed (any field carrying @@index),
- "findings" lack model.field or file:line anchors,
- the Prisma layer is confused for raw SQL it cannot see.
