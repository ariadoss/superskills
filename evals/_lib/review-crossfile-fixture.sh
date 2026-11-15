#!/usr/bin/env bash
# review_crossfile_fixture <dir>: builds the review-crossfile fixture repo.
# Two modules: warehouse.py owns get_sku(); orders.py imports it and pins an
# exact order-id format in its own test. The UNCOMMITTED diff changes
# get_sku()'s output without touching orders.py — a genuine cross-file break
# the review must KEEP (positive control for evidence grading: the finding is
# provable by running orders.py's failing test or reading orders.py).
# Idempotent: wipes <dir> first; body runs in a subshell (the _lib convention).
review_crossfile_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: review_crossfile_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir" "$dir/tests"
  cd "$dir" || exit 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture

  cat > warehouse.py <<'EOF'
_SKUS = {
    "widget": "WGT-001",
    "gadget": "GDT-002",
    "sprocket": "SPR-003",
}


def get_sku(product_name):
    """Return the canonical SKU for a product name, e.g. "widget" -> WGT-001."""
    return _SKUS[product_name]
EOF

  cat > orders.py <<'EOF'
from warehouse import get_sku


def order_reference(product_name, seq):
    """Order refs are "<SKU>-<seq>", e.g. order_reference("widget", 7) == "WGT-001-7"."""
    return f"{get_sku(product_name)}-{seq}"
EOF

  cat > tests/__init__.py <<'EOF'
EOF

  cat > tests/test_orders.py <<'EOF'
import unittest

from orders import order_reference


class TestOrderReference(unittest.TestCase):
    def test_format_is_sku_seq(self):
        self.assertEqual(order_reference("widget", 7), "WGT-001-7")


if __name__ == "__main__":
    unittest.main()
EOF

  cat > README.md <<'EOF'
# order-desk
`warehouse.get_sku` maps names to SKUs; `orders.order_reference` builds refs.
EOF

  git add -A && git commit -qm "base: order-desk with sku mapping"

  # Pending (uncommitted) change: SKUs get a locale suffix — orders.py pins the
  # old format in its own test, so this genuinely breaks the caller.
  cat > warehouse.py <<'EOF'
_SKUS = {
    "widget": "WGT-001",
    "gadget": "GDT-002",
    "sprocket": "SPR-003",
}


def get_sku(product_name, region="EU"):
    """Return the canonical SKU for a product name, region-suffixed for
    display, e.g. "widget" -> WGT-001-EU."""
    return f"{_SKUS[product_name]}-{region}"
EOF
  )
}
