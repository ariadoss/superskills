#!/bin/bash
# routing-fixture-extra.sh <dir>: adds the routing-eval triggers qa-full-fixture.sh
# does not plant — duplicated tax logic (clean-code), a CPU hot path (perf-profile),
# an HTML page (web-perf) and a CI workflow (iac-scan). Run it after
# qa-full-fixture.sh on the same dir; it commits onto the feature branch.
set -e
D="$1"; cd "$D"
mkdir -p src web .github/workflows

# Two near-identical tax routines: the clean-code / DRY trigger.
cat > src/pricing.js <<'J'
const TAX_RATES = { US: 0.07, CA: 0.13, GB: 0.2 };

function priceWithTax(amount, country) {
  const rate = TAX_RATES[country];
  if (rate === undefined) throw new Error('unknown country: ' + country);
  const tax = Math.round(amount * rate * 100) / 100;
  return { amount, tax, total: amount + tax };
}

module.exports = { priceWithTax, TAX_RATES };
J
cat > src/quote.js <<'J'
const TAX_RATES = { US: 0.07, CA: 0.13, GB: 0.2 };

function quoteWithTax(subtotal, country) {
  const rate = TAX_RATES[country];
  if (rate === undefined) throw new Error('unknown country: ' + country);
  const tax = Math.round(subtotal * rate * 100) / 100;
  return { subtotal, tax, grandTotal: subtotal + tax };
}

module.exports = { quoteWithTax };
J

# Quadratic scan over orders: the perf-profile trigger.
cat > src/hotpath.js <<'J'
// Flags orders that share a shipping address with any other order.
function duplicateAddresses(orders) {
  const flagged = [];
  for (const a of orders) {
    for (const b of orders) {
      if (a.id !== b.id && a.address === b.address) {
        flagged.push(a.id);
        break;
      }
    }
  }
  return flagged;
}

function summarize(orders) {
  return orders.map((o) => ({ id: o.id, label: JSON.stringify(o).slice(0, 40) }));
}

module.exports = { duplicateAddresses, summarize };
J

# Render-blocking head, no dimensions, huge inline CSS: the web-perf trigger.
cat > web/index.html <<'J'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Shopfix Checkout</title>
    <script src="https://cdn.example.test/analytics.js"></script>
    <script src="https://cdn.example.test/tag-manager.js"></script>
    <link rel="stylesheet" href="https://fonts.example.test/all.css" />
    <style>
      body { margin: 0; font-family: system-ui; }
      .hero { min-height: 60vh; background: #f4f4f4; }
      .hero img { width: 100%; }
    </style>
  </head>
  <body>
    <div class="hero"><img src="hero.png" /></div>
    <div id="cart"></div>
    <script src="cart-bundle.js"></script>
  </body>
</html>
J

# Untrusted trigger, no permissions block, wildcard secret: the iac-scan trigger.
cat > .github/workflows/ci.yml <<'J'
name: ci
on: [pull_request_target]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: npm test
        env:
          STRIPE_SECRET_KEY: ${{ secrets.STRIPE_SECRET_KEY }}
      - run: curl -fsSL https://deploy.example.test/release.sh | bash
J

git add -A
git commit -qm "feature: pricing/quote tax, hot path, checkout page, ci workflow"
