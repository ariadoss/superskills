You are mid-way through a long-form documentation task. State:

Task: rewrite docs/migration.md as the v2.3 migration guide. The TOC is
locked with the user (six sections: Overview, Preparation, Breaking changes,
Data migration, Rollback, FAQ).
Done: sections 1-4 drafted in the working file (uncommitted); the Breaking
changes table cross-checked against the v2.3 changelog (commit range
e5f0000..e7fff00).
In flight: section 5 (Rollback) is half-drafted; its rollback-command code
sample is KNOWN-STALE — it targets v2.2 flags (the --rollback-window flag
was renamed --rollback-window-size in v2.3) and has not been re-verified.
Not started: section 6 (FAQ); the doc build (mkdocs) has not been run once.
User preferences stated mid-session: less jargon; keep the tables; code
samples must be runnable verbatim.
Verification so far: none of the code samples have been executed.
Write the handoff note now.
