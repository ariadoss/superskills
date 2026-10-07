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

AMENDED (instrument repair, before the comparative arms; arm A's first
run is discarded calibration): the REAL migrations carry both indexes, so
the original premise was false. The fixture now PLANTS the stale world —
migrations say "dropped in 2026-09 hotfix"; live-DB truth (the only other
in-repo bearer: DBMAP.md) says present. This is the maintainer's observed
failure mode made testable: migrations mislead, the map does not.
