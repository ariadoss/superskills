#!/bin/bash
# omc-skillify-fixture.sh <dir> [hardwon|trivial]: writes the transcript excerpt
# used by evals/reports/2026-11-15-omc-skillify-PREREG.md. Both excerpts share a
# topic (fixing a flaky Playwright test) so the delta is the quality gate, not
# the subject.
set -e
D="$1"; VARIANT="${2:-hardwon}"
mkdir -p "$D"
if [ "$VARIANT" = hardwon ]; then
cat > "$D/session-transcript.md" <<'EOF'
# Session: checkout E2E test flaking on CI

User: The checkout e2e test fails ~1 in 5 CI runs but always passes locally. Fix it.

Attempt 1 — added `await page.waitForLoadState('networkidle')` before asserting.
CI still flaked. `networkidle` never settles on our checkout page: the
Split.io polling beacon keeps a connection open forever. Symptom: timeout
after 30s exactly, not a flaky short wait.

Attempt 2 — stubbed the beacon route with `page.route('**/beacon**', r => r.fulfill())`.
Different failure: the analytics SDK retried in a tight loop (its "send" never
succeeded), starving the main thread. Symptom: test exceeded 60s budget.

Attempt 3 (worked) — `page.route('**/beacon**', route => route.fulfill({ status: 204 }))`
— a 204 with no body makes the SDK treat the send as delivered and back off;
combined with `waitForResponse('**/api/checkout/confirm')` targeted at the ONE
request the assertion actually depends on, instead of networkidle. 40/40 green
on CI since.

Also: this only reproduces with `--workers=4`; single-worker runs never flake
(the beacon loop needs CPU contention to starve the assertion timer).
EOF
else
cat > "$D/session-transcript.md" <<'EOF'
# Session: checkout E2E test flaking on CI

User: The checkout e2e test fails on CI. How do I run it?

Agent: The README says the runner is `npx playwright test tests/checkout.spec.ts`.
Ran it; the test passed locally. Told the user CI failures like this are often
environment-related and pointed at the CI logs page (link in README).
EOF
fi
