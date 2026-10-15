#!/bin/bash
# handoff-rewrite fixture: a repo mid-task whose session ALREADY wrote a
# handoff note once; state has since moved past that note (one In-flight
# item landed and was committed AFTER the note; Context lists a read of a
# file whose content was rewritten by that commit). The measured thing is
# the UPDATED note: flat (rewritten in place, not nested/appended) and
# current (superseded state dropped).
set -e
handoff_rewrite_fixture() {
  local R="$PWD/fixture-repo"
  rm -rf "$R"
  mkdir -p "$R/src" "$R/tests"
  (
  cd "$R"
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture

  # commit 1: calculator, flat tier only (tests are plain-runnable — no
  # pytest dependency, quota-fixture precedent)
  cat > src/calc.py <<'PY'
def shipping(items):
    """Flat shipping: one rate for every order."""
    return 4.99
PY
  cat > tests/test_calc.py <<'PY'
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.calc import shipping

def test_flat():
    assert shipping([1]) == 4.99

if __name__ == "__main__":
    test_flat()
    print("flat ok")
PY
  git add -A
  git commit -qm "flat tier"

  # the note THIS session wrote earlier (current-at-the-time):
  #   In flight: express tier (uncommitted then)
  #   Context: records reading src/calc.py in its flat-only shape
  cat > handoff-7c1d2f.md <<'MD'
# Handoff — free-shipping threshold @ 2026-10-14
written by session 7c1d2f @ 2026-10-14T10:04:00+02:00

## Goal
Free shipping over 10 items; express surcharge documented.

## Done
- tests/test_calc.py::test_flat passing at commit 1

## In flight
- express tier: src/calc.py returns 0.00 for >10 items — edit not started

## Next steps
1. edit src/calc.py: return 0.00 when len(items) > 10
2. add test_express to tests/test_calc.py
3. python3 tests/test_calc.py

## Verify
python3 tests/test_calc.py

## Context
- read src/calc.py (flat-only version) before planning the edit
- user wants no new dependencies
MD

  # commit 2 (AFTER the note was written): the express tier landed
  cat > src/calc.py <<'PY'
def shipping(items):
    """Free shipping over 10 items; flat rate otherwise."""
    return 0.00 if len(items) > 10 else 4.99
PY
  cat > tests/test_calc.py <<'PY'
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.calc import shipping

def test_flat():
    assert shipping([1]) == 4.99

def test_express():
    assert shipping([1] * 11) == 0.00

if __name__ == "__main__":
    test_flat()
    test_express()
    print("flat ok")
    print("express ok")
PY
  # Stage only the code: the handoff note stays UNTRACKED, exactly as a
  # real session's note would be (the skill's own contract: "uncommitted
  # by design"), and rates.py below lands as unstaged half-work.
  git add src/calc.py tests/test_calc.py
  git commit -qm "express tier: free over 10 items"

  # unstaged half-work: still genuinely in flight
  cat > src/rates.py <<'PY'
def bulk_rate(items):
    """Stub: per-item bulk discount not applied yet."""
    return 2.50
PY
  )
}
handoff_rewrite_fixture
