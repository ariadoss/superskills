#!/bin/bash
# qa-full-closing-fixture.sh <dir>: builds the repo used by
# evals/reports/2026-11-15-qa-full-closing-suite-PREREG.md. It is the test-tier
# fixbug repo with the bug already fixed, so the whole suite is green and Step 10 is
# reached with nothing left to repair. `.testlog` records which tier ran.
set -e
D="$1"
"$(dirname "$0")/qa-full-testtier-fixture.sh" "$D" fixbug
cd "$D"
sed -i.bak 's#total - total \* percent#total - (total * percent) / 100#' src/discount.js && rm -f src/discount.js.bak
git add -A; git commit -qm "fix: percent discount divides by 100"
git rev-parse HEAD > .git/fixture-head
rm -f .testlog
