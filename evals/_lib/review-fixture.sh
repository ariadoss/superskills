#!/usr/bin/env bash
# review_fixture <dir> <bait|benign|conventions|guided-violation|guided-clean>: builds the review-eval fixture repo.
#   bait:    diff introduces one real bug, one speculative-risk change, one
#            pure-style change; the repo holds one PRE-EXISTING bug outside
#            the diff (the trap).
#   benign:  diff extracts an intermediate local + tweaks a comment; no
#            behavior change, nothing is wrong.
# Idempotent: wipes <dir> first, so repeated scaffolds are safe. The body
# runs in a subshell so the caller's cwd is never touched (the convention
# evals/_lib/doctor-fixture.sh set).
review_fixture() {
  local dir="$1" mode="$2"
  [ -n "$dir" ] && [ -n "$mode" ] || { echo "usage: review_fixture <dir> <bait|benign|conventions|guided-violation|guided-clean>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"
  cd "$dir" || exit 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture

  cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    return {"items": qty, "charged": charge(total)}
EOF

  cat > README.md <<'EOF'
# orders
`submit("5", 19.99)` returns the item ids and the amount charged.
EOF

  git add -A && git commit -qm "base: orders helpers"

  if [ "$mode" = "bait" ]; then
    cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream."""
    # cents must survive the integer-division path downstream
    return int(total * 100) / 1000


def submit(raw, total, attempts=3):
    for _ in range(attempts):
        try:
            qty = parse_qty(raw)
            value = charge(total)
            return {"items": qty, "charged": value}
        except ValueError:
            continue
    raise ValueError("unparseable")
EOF
  elif [ "$mode" = "benign" ]; then
    cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream (rounded)."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    value = charge(total)
    return {"items": qty, "charged": value}
EOF
  elif [ "$mode" = "conventions" ]; then
    cat > CONVENTIONS.md <<'EOF'
# orders — house rules

1. Money math is integer cents. Never compute amounts as float fractions;
   percentages are basis-point integers (8500 = 85%).
2. Public functions keep a docstring stating their units.
EOF
    git add -A && git commit -qm "docs: house rules"
    cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream (rounded)."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    value = charge(total)
    return {"items": qty, "charged": value}


def refund(total, pct_bp=8500):
    """Total in dollars; returns the refunded amount in dollars."""
    return round(total * (pct_bp / 10000), 2)
EOF
  elif [ "$mode" = "guided-violation" ] || [ "$mode" = "guided-clean" ]; then
    cat > REVIEW_GUIDELINES.yaml <<'EOF'
areas:
  - id: money-cents
    globs: ["app.py"]
    rules:
      - "Monetary math is integer cents. Never compute amounts as float
         fractions; percentages are basis-point integers (8500 = 85%)."
  - id: readme-voice
    globs: ["README.md"]
    rules:
      - "README examples always show full argument lists, never bare
         placeholders."
EOF
    git add -A && git commit -qm "docs: review guidelines"
    if [ "$mode" = "guided-violation" ]; then
      cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream (rounded)."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    value = charge(total)
    return {"items": qty, "charged": value}


def refund(total, pct_bp=8500):
    """Total in dollars; returns the refunded amount in dollars."""
    return round(total * (pct_bp / 10000), 2)
EOF
    else
      cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream (rounded)."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    value = charge(total)
    return {"items": qty, "charged": value}


def refund_cents(total_cents, pct_bp=8500):
    """Amount in integer cents; pct_bp is basis points; returns integer cents."""
    return total_cents * pct_bp // 10000
EOF
    fi
  else
    echo "unknown mode: $mode" >&2; exit 2
  fi
  )
}
