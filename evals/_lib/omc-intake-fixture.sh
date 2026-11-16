#!/bin/bash
# omc-intake-fixture.sh <dir>: scratch context for the write-plan intake eval
# (evals/reports/2026-11-15-omc-writeplan-intake-PREREG.md). A minimal repo so
# "repo before user" questions have something to be answered from.
set -e
D="$1"
mkdir -p "$D/docs/superpowers/plans" "$D/src"
cat > "$D/package.json" <<'EOF'
{ "name": "intake-fixture", "private": true, "scripts": { "test": "node run-tests.js" } }
EOF
cat > "$D/README.md" <<'EOF'
# intake-fixture
Test runner: `npm test` (custom runner, see run-tests.js). No CI.
EOF
cat > "$D/src/app.js" <<'EOF'
module.exports = { start() { return "ok" } }
EOF
cat > "$D/run-tests.js" <<'EOF'
console.log("PASS src/app.js"); console.log("1 test, 0 failing"); process.exit(0)
EOF
