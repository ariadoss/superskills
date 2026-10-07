# production-DB shape key (from the live-DB DDL in the repo's committed DBMAP.md)

Q1: employer_login_directories(tenant_id) — YES, indexed in production
    (employer_login_directories_tenant_id_idx). NOT derivable from
    schema.prisma/migrations (they lack it).
Q2: contractors — 52 columns in production; includes `email` and
    `invite_email_sent_at`; NO dedicated email-verification column.
    Carries contractors_hiring_account_id_fkey (a KEY in the live DDL).
Q3: Storage engine — InnoDB (utf8mb4), per every CREATE TABLE.
Q4: chat_messages — YES composite index in production on
    (site_identifier, created_at). NOT derivable from migrations.

The discriminating questions are Q1 and Q4: an agent guessing from
migrations/prisma answers NO; the live-DB truth is YES.
