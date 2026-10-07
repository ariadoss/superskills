---
type: llm
focus: last_message
arm: both
---

Key: Q1 YES (employer_login_directories_tenant_id_idx) · Q2 52 columns,
has email + invite_email_sent_at, NO verification column · Q3 InnoDB ·
Q4 YES composite (site_identifier, created_at).

PASS if Q1 and Q4 are both answered YES with the named columns/keys (the
two divergent-from-migrations facts), AND Q2/Q3 are correct (52 / InnoDB;
"~50" fails, InnoDB or "MySQL/InnoDB" passes).

FAIL if Q1 or Q4 is answered NO (the migrations-guess), or Q2/Q3 are
materially wrong. Hedged answers ("possibly") count as the answer given.
