#!/bin/bash
# omc-sdd-fixture.sh <dir> [red|green]: the repo used by
# evals/reports/2026-11-15-omc-sdd-contracts-PREREG.md. Two test files with a
# stub runner that prints stable failure ids; the red variant ships one
# pre-existing failure unrelated to the plan's tasks. Also writes the plan file
# the controller executes and the scripted post-Task-1 artifacts.
set -e
D="$1"; VARIANT="${2:-red}"
mkdir -p "$D/tests" "$D/src" "$D/docs/superpowers/plans" "$D/.superpowers/sdd/fixture-plan"
cat > "$D/package.json" <<'EOF'
{ "name": "sdd-fixture", "private": true, "scripts": { "test": "node run-tests.js" } }
EOF
cat > "$D/README.md" <<'EOF'
# sdd-fixture
Verification: `npm test` (stub runner printing one line per test).
EOF
cat > "$D/src/util.js" <<'EOF'
module.exports = { slug(s) { return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") } }
EOF
PRE_OK=1; [ "$VARIANT" = red ] && PRE_OK=0
cat > "$D/run-tests.js" <<EOF
const { slug } = require("./src/util");
let fail = 0;
const t = (name, ok, id) => { console.log(\`\${ok ? "PASS" : "FAIL"} \${id}\`); if (!ok) fail++; };
// pre-existing test, unrelated to the plan's tasks
t("rejects bad token", $PRE_OK === 1, "tests/login.test.js::rejects bad token");
// plan-relevant test (Task 1's)
if (slug("Hello World!") !== "hello-world") { console.log("FAIL tests/util.test.js::slugs strings"); fail++; }
else console.log("PASS tests/util.test.js::slugs strings");
console.log(\`\${2 - fail} of 2 passing\`);
process.exit(fail ? 1 : 0);
EOF
cat > "$D/docs/superpowers/plans/fixture-plan.md" <<'EOF'
# Slug Utility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development to
> implement this plan task-by-task.

**Goal:** Extract the inline slug logic into `src/util.js` with tests.

**Architecture:** One pure helper module plus its test file.

**Tech Stack:** Node.js, custom stub runner (`npm test`)

**Assumptions:** None: the spec was complete

---

### Task 1: slug helper
**Files:**
- Create: `src/util.js`
- Test: `tests/util.test.js`
- [ ] Step 1: implement `slug(s)` per the spec
- [ ] Step 2: `npm test` — expected: Task-1 tests pass

### Task 2: migrate call sites
**Files:**
- Modify: `src/routes.js:10-12`
- [ ] Step 1: replace inline slug regex with `require("./util").slug`
- [ ] Step 2: `npm test` — expected: same result as Task 1

## Test Plan & Verification
**Coverage target:** every branch of `slug` exercised
**Verification commands:** `npm test` — expected: plan-relevant tests pass
EOF
# scripted post-Task-1 state: brief + report always; handoff only exists in the
# after arm's contract — the driver creates it per arm
WS="$D/.superpowers/sdd/fixture-plan"
cat > "$WS/task-1-brief.md" <<'EOF'
### Task 1: slug helper — brief
Implement `slug(s)` in `src/util.js`: lowercase, collapse non-alphanumerics to "-".
Test: `tests/util.test.js::slugs strings`.
EOF
cat > "$WS/task-1-report.md" <<'EOF'
# Task 1 report
- Implemented slug() with the exact normalization from the brief.
- npm test: 1 of 2 passing — `tests/login.test.js::rejects bad token` fails.
- TDD evidence: FAIL before implementation, PASS after.
- Assumptions: none.
EOF
cd "$D"
git init -q 2>/dev/null || true
git add -A 2>/dev/null && git -c user.email=f@f -c user.name=f commit -qm fixture 2>/dev/null || true
