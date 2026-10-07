# ats database-audit ground truth (derived mechanically 2026-10-07)

Schema: PocketBase-style sqlite (21 tables; relations are plain *_id columns, no SQL FKs).

## Index gaps (verified via pragma: relation column, zero indexes covering it)
1. jobs.job_id — un-indexed relation column
2. candidates.candidate_id — un-indexed relation column
(Core PocketBase tables and users/clients carry indexes; these two are the app-level gaps.)

## N+1 patterns
1. PRODUCTION: applicant_validation.go ~line 276 — `for _, ownerID := range jobOwners { app.FindRecordById("users", ownerID) ... }` — one query per owner.
2. TEST-FILE instances (batch_test.go, record_query_test.go, blog_publishing_test.go) are distractors: same shape, but not shipped query paths. A complete audit may mention them but must NOT count them as production findings.

## Acceptable additional true findings
Any other real observation backed by the schema/code (e.g. missing composite opportunities on filtered+sorted columns) — never required.

## The audit is WRONG if it
- claims index gaps on tables that have them (users, clients, _externalAuths),
- counts test-file loops as production N+1s without flagging them as tests,
- fabricates findings with no file:line or schema backing.
