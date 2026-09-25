#!/bin/bash
# daily-qa-fixture.sh <dir>: the qa-full fixture reshaped for /daily-qa, which scans
# recent commits on the current branch. The base commit is backdated ten days and the
# planted commit (failing test, secret, SQL injection, N+1, inaccessible form, root
# Dockerfile) is fast-forwarded onto main, so only it falls inside a 24h window.
set -e
D="$1"
FIXTURE_BASE_AGE_DAYS=10 bash "$(dirname "$0")/qa-full-fixture.sh" "$D"
cd "$D"
git switch -q main
git merge -q --ff-only feature/checkout
git branch -q -D feature/checkout
git push -q origin main
