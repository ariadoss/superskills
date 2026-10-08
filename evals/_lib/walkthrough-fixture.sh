#!/usr/bin/env bash
# walkthrough_fixture <dir>: builds the pricing repo for the diff-walkthrough
# eval. Base: compute_total applies 8% tax then a flat $10 member discount;
# routes.py wires /checkout; models.py holds helpers. Feature branch (the diff
# to walk through): (core) compute_total now applies the $10 member discount
# BEFORE tax — for base 100, member: old (100+8)-10 = 98.00, new
# (100-10)*1.08 = 97.20, a real $0.80 divergence (a multiplicative discount
# would be order-insensitive — probe-verified trap, do not "simplify" back);
# (wiring) routes.py registers /refund; (boilerplate) models.py renames
# cust->customer and reorders imports. Domain disjoint from the skill's
# core.py/routes.py validator example (anti-leakage).
walkthrough_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: walkthrough_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"
  cd "$dir" || exit 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture
  cat > pricing.py <<'EOF'
TAX_RATE = 0.08
MEMBER_DISCOUNT_USD = 10.00


def compute_total(base_price, member=False):
    """Old policy: flat $10 member discount applied after tax."""
    subtotal = base_price * (1 + TAX_RATE)
    if member:
        subtotal -= MEMBER_DISCOUNT_USD
    return round(subtotal, 2)
EOF
  cat > routes.py <<'EOF'
HANDLERS = {}


def route(path):
    def register(fn):
        HANDLERS[path] = fn
        return fn
    return register


@route("/checkout")
def checkout(payload):
    from pricing import compute_total
    return {"total": compute_total(payload["base_price"],
                                  payload.get("member", False))}
EOF
  cat > models.py <<'EOF'
import json


def cust_ref(cust):
    return {"id": cust["id"], "name": cust["name"]}


def dump(rows):
    return json.dumps(rows)
EOF
  git add -A && git commit -qm "base: checkout pricing"
  git switch -qc feature/member-discount
  cat > pricing.py <<'EOF'
TAX_RATE = 0.08
MEMBER_DISCOUNT_USD = 10.00


def compute_total(base_price, member=False):
    """New policy: flat $10 member discount applied before tax."""
    subtotal = base_price
    if member:
        subtotal -= MEMBER_DISCOUNT_USD
    return round(subtotal * (1 + TAX_RATE), 2)
EOF
  cat >> routes.py <<'EOF'


@route("/refund")
def refund(payload):
    from pricing import compute_total
    owed = compute_total(payload["base_price"], payload.get("member", False))
    return {"refund": round(max(payload["paid"] - owed, 0.0), 2)}
EOF
  cat > models.py <<'EOF'
import json


def customer_ref(customer):
    return {"id": customer["id"], "name": customer["name"]}


def dump(rows):
    return json.dumps(rows)
EOF
  git add -A && git commit -qm "feature: member discount before tax, refund route, rename"
  )
}
