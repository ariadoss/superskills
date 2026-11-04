#!/bin/bash
# qa-full-light-fixture.sh <dir>: the QA fixture repo with a docs-only feature branch, so
# the diff triggers almost none of /qa-full's conditional checks. Reuses qa-full-fixture.sh.
set -e
D="$1"
bash "$(dirname "$0")/qa-full-fixture.sh" "$D"
cd "$D"
git switch -q main
git switch -qc feature/docs-note
printf '# shopfix\n\nA small cart-total library.\n' > README.md
git add README.md
git commit -q -m "docs: add readme"
