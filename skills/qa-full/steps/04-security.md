## Step 4: Security pipeline — `/defense`, `/iac-scan`, `/pentest`, `/fuzz`

**`/defense` (always).**
1. **Audit:** run `/defense` scoped to the changed files (OWASP Top 10 /
   secrets / auth / crypto / data-protection).
2. **Fix:** remediate every CRITICAL/HIGH (and cheap MEDIUMs): remove or
   rotate-and-externalize hardcoded secrets, add the missing authz check,
   parameterize the query, escape the output, switch the weak primitive, add
   the validation. Each fix gets a regression test where a test can express it
   (e.g. "unauthenticated request to X returns 401"). Commit atomically.
3. **Verify:** re-run `/defense` on the same files; the finding must be gone.

**`/iac-scan` (when infra/deploy config changed).** Trigger on `Dockerfile`,
`docker-compose*`, `*.tf`/`*.tfvars`, k8s/Helm manifests, `.github/workflows/**`,
`.gitlab-ci.yml`, `Jenkinsfile`, nginx/cloud config (see `/iac-scan`'s trigger
section for the authoritative list). Audit with the local static linters, **fix**
CRITICAL/HIGH misconfigs (root container → non-root user, `0.0.0.0/0` ingress →
scoped CIDR, wildcard IAM → least privilege, privileged pod → dropped, untrusted
CI trigger → pinned/guarded, baked-in secret → injected), re-scan to verify.

**`/pentest` (triggered when `/defense` found CRITICAL/HIGH, or the diff touches
auth/crypto/session/token/deserialization/file-upload paths).** Its default mode
hunts in this harness — the session's own model reads the code and reports
findings with evidence levels; no external scanner, no spend beyond the
session. **Authorization was settled in Step 1** (the user's yes there, or
their `CLAUDE.md`); do not ask again mid-run. Run it; the in-harness hunt is
the check, not a stand-in.
Fix CRITICAL/HIGH it surfaces, re-run to verify. clearwing appears only
behind its ask-first gate: the user names it, asks for a network probe, or
wants SARIF/CI output — and its pipeline can run agent-driven on this session
via the bundled bridge (no provider, no spend) instead of provider-driven.
Provider-driven runs configure their own LLM provider and bill it per run —
declining clearwing means run the in-harness mode, not skip the check.
If the user declines the check itself (no authorization) ⇒ SKIPPED(reason). If
`CLAUDE.md` marks `/pentest` MANDATORY, SKIPPED is a blocker.

**`/fuzz` (triggered when the diff adds or changes endpoints, input parsing,
file-upload handling, or deserialization).** Needs a running target: find the dev
URL with the target-resolution flow, then run `/fuzz` against the new surface;
**fix** crashes, injections, and auth bypasses it surfaces (with a regression
test); re-fuzz to verify. If no target is possible after that flow ⇒
SKIPPED(reason). If `CLAUDE.md` marks `/fuzz` MANDATORY, SKIPPED is a blocker.

**`/cso` backstop.** If the diff crosses a *new* trust boundary (new auth
path/endpoint/external input/deserialization) and there's no evidence a threat
model was done at plan time, run `/cso` on that boundary and fold any
CRITICAL/HIGH into the `/defense` fix round. Threat modeling belongs in
`/write-plan`; this is the late catch, not a substitute.
