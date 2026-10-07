---
type: llm
focus: last_message
arm: both
---

Key: schema.prisma has 12 models and exactly these relation fields lack
@@index — EmployerLoginDirectory.tenant, TenantProvisioningRequest.tenant,
PlatformAuditEvent.tenant, TokenBalance.hiringAccount,
AgentTokenUsage.tenant, AgentTokenUsage.hiringAccount,
Contractor.hiringAccount, ChatMessage.hiringAccount — clustering on
tenant and hiringAccount relation columns.

PASS if the reply's index-gap findings name ≥5 of these 8 with
model.field precision (or name the tenant/hiringAccount relation-index
pattern explicitly with ≥3 concrete fields).

FAIL if fewer than 3 are named, or gaps are claimed on indexed fields.
Supplementary true findings neither help nor hurt.
