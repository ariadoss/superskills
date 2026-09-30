#!/bin/bash
# Shared scaffold for the evals/quota-* and evals/rate-limit-429 cases: a
# small but real repo (Python shipping calculator, dependency-free tests)
# with one complete verified change and one half-finished change. The eval
# harness runs the fixture with --scaffold in an empty workspace (cwd).
#
#   quota_fixture <stop|resume>
#     stop    dirty tree: flat tier landed, express tier stubbed with a
#             failing test — the moment the usage limit hit
#     resume  clean tree on feature/express: the stop-phase salvage already
#             happened and a committed QUOTA-RESUME.md carries the state
set -e
quota_fixture() {
  local mode="$1" R="$PWD/fixture-repo"
  mkdir -p "$R/src" "$R/tests"
  (
    cd "$R"
    git init -q
    git config user.email "fixture-agent@example.com"
    git config user.name "Fixture Agent"
    printf 'FLAT_RATE = 4.99\n\ndef flat_shipping(items: int) -> float:\n    return 0.0 if items == 0 else FLAT_RATE\n' > src/shipping.py
    printf 'import sys, os\nsys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))\nfrom src.shipping import flat_shipping\n\nassert flat_shipping(0) == 0.0\nassert flat_shipping(3) == 4.99\nprint("flat ok")\n' > tests/test_shipping.py
    # -B: no __pycache__ — the flat-rate commit must not track build artifacts
    # (both eval agents burned a fix cycle on a tracked .pyc before this).
    PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_shipping.py >/dev/null
    git add -A && git commit -qm "shipping: flat rate"
    [ "$mode" = resume ] && git checkout -qb feature/express
    printf '\ndef express_shipping(items: int) -> float:\n    # TODO: flat + 8.00 surcharge per order; more than 10 items ships free\n    raise NotImplementedError\n' >> src/shipping.py
    printf '\nfrom src.shipping import express_shipping\n\nassert express_shipping(2) == 12.99\nassert express_shipping(12) == 0.0\nprint("express ok")\n' >> tests/test_shipping.py
    if [ "$mode" = resume ]; then
      cat > QUOTA-RESUME.md <<'NOTE'
# Quota resume note

Goal: ship the express shipping tier on feature/express.

Done:
- flat_shipping landed and verified (commit "shipping: flat rate" on main).

In flight:
- src/shipping.py express_shipping: stub raising NotImplementedError.
- tests/test_shipping.py: express asserts added, currently failing.

Next steps:
1. Implement express_shipping: flat rate + 8.00 surcharge per order;
   orders with more than 10 items ship free.
2. Run: python3 tests/test_shipping.py  (must print "flat ok" and "express ok")
3. Commit src/ + tests/ as one unit, delete this file, commit the deletion.

Verify: python3 tests/test_shipping.py prints both ok lines.

Context: the spec is the test asserts; no other files are involved.
NOTE
      git add -A && git commit -qm "wip: express tier stub + quota resume note"
    fi
  )
}
