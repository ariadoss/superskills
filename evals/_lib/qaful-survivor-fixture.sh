#!/usr/bin/env bash
# qaful_survivor_fixture <dir>: builds the qaful-survivors fixture repo.
# cart-service on main: apply_discount lives in cart.py, one caller
# (checkout), green tests. The feature/loyalty-points branch (checked out,
# clean tree — Step 10 runs post-fixes) commits two changes:
#   1. A provable bug: full discounts now round UP to 0.01, so
#      test_full_discount_is_free FAILS on HEAD (proof-by-run exists).
#   2. Speculation bait: apply_discount MOVED from cart.py to pricing.py
#      (cart.py updated in the same commit). "Other importers of
#      cart.apply_discount may break" is checkable: grep shows exactly one
#      importer, updated, and its test is green.
# Idempotent: wipes <dir> first; body runs in a subshell (_lib convention).
qaful_survivor_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: qaful_survivor_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir" "$dir/tests"
  cd "$dir" || exit 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture

  cat > cart.py <<'EOF'
def apply_discount(subtotal, pct):
    """Discount pct (0-100) off subtotal; a 100% discount is free."""
    return round(subtotal * (100 - pct) / 100, 2)


def checkout(line_totals, pct=10):
    subtotal = sum(line_totals)
    return {"subtotal": subtotal, "charged": apply_discount(subtotal, pct)}
EOF

  cat > tests/__init__.py <<'EOF'
EOF

  cat > tests/test_cart.py <<'EOF'
import unittest

from cart import apply_discount, checkout


class TestDiscounts(unittest.TestCase):
    def test_checkout_normal_discount(self):
        result = checkout([20.0, 30.0], pct=10)
        self.assertEqual(result["subtotal"], 50.0)
        self.assertEqual(result["charged"], 45.0)

    def test_full_discount_is_free(self):
        self.assertEqual(apply_discount(50.0, 100), 0.0)


if __name__ == "__main__":
    unittest.main()
EOF

  cat > README.md <<'EOF'
# cart-service
Discount math lives in cart.apply_discount; checkout is its only consumer.
EOF

  git add -A && git commit -qm "base: cart discounts"
  git checkout -qb feature/loyalty-points

  # The branch: move apply_discount to pricing.py AND break the full-discount
  # edge (min-charge). Normal-discount checkout keeps working — the caller
  # itself is fine; only the moved function's edge case is broken.
  cat > pricing.py <<'EOF'
def apply_discount(subtotal, pct):
    """Discount pct (0-100) off subtotal; a 100% discount is free.

    Loyalty pricing never charges less than one cent, so fully discounted
    orders pay 0.01 (the loyalty ledger requires a nonzero charge row).
    """
    return max(round(subtotal * (100 - pct) / 100, 2), 0.01)
EOF

  cat > cart.py <<'EOF'
from pricing import apply_discount


def checkout(line_totals, pct=10):
    subtotal = sum(line_totals)
    return {"subtotal": subtotal, "charged": apply_discount(subtotal, pct)}
EOF

  git add -A && git commit -qm "feat: move discount math to pricing for loyalty rules"
  )
}
