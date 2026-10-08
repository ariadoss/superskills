#!/bin/bash
# qaful_synthesis_fixture <dir>: builds the Node repo for the qa-full
# synthesis eval. Feature branch adds src/invoice.js whose lineTotal()
# duplicates cart.js's per-item math but floors per line — a divergence
# invisible to single-item tests (suite green), flagged by /review (or
# /basic-review) as correctness and by /clean-code as DRY: one root cause,
# two check surfaces. No secrets, no SQL, no browser, no DB triggers.
set -e
D="$1"; rm -rf "$D"; mkdir -p "$D"; cd "$D"
git init -q -b main; git config user.email qa@example.test; git config user.name "QA Fixture"
cat > package.json <<'J'
{ "name": "invoicefix", "version": "1.0.0", "private": true, "type": "commonjs",
  "scripts": { "test": "node --test" } }
J
cat > CLAUDE.md <<'M'
# invoicefix

Plain Node (no dependencies, no build step). Tests use the built-in runner.

## qa-full

- Test/build: `npm test` (there is no build step)
- Dev URL: none. There is no dev server for this project.
- Codex passes: do not use Codex for this project.
- /pentest: not authorized for this project.
M
mkdir -p src tests
cat > src/cart.js <<'J'
// Money math for carts. Prices are dollars; totals are exact sums.
function itemTotal(item) {
  return item.price * item.qty;
}
function cartTotal(items) {
  return items.reduce((sum, i) => sum + itemTotal(i), 0);
}
module.exports = { itemTotal, cartTotal };
J
cat > tests/cart.test.js <<'J'
const test = require('node:test');
const assert = require('node:assert');
const { cartTotal, itemTotal } = require('../src/cart');
test('sums price times quantity', () => {
  assert.strictEqual(cartTotal([{ price: 2, qty: 3 }, { price: 5, qty: 1 }]), 11);
});
test('item total is exact', () => {
  assert.strictEqual(itemTotal({ price: 19.99, qty: 3 }), 59.97);
});
J
printf 'node_modules\n' > .gitignore
git add -A; git commit -qm "base: cart totals"
git switch -qc feature/invoice
cat > src/invoice.js <<'J'
const { itemTotal } = require('./cart');

// Per-line totals for invoices. Floors each line to whole cents.
function lineTotal(item) {
  return Math.floor(item.price * item.qty * 100) / 100;
}
function invoiceTotal(items) {
  return items.reduce((sum, i) => sum + lineTotal(i), 0);
}
function renderInvoice(items) {
  return items.map(i => `- ${i.qty} x ${i.price} = ${lineTotal(i)}`).join("\n");
}
module.exports = { lineTotal, invoiceTotal, renderInvoice };
J
cat > tests/invoice.test.js <<'J'
const test = require('node:test');
const assert = require('node:assert');
const { invoiceTotal } = require('../src/invoice');
test('single item invoice matches cart math on integers', () => {
  assert.strictEqual(invoiceTotal([{ price: 2, qty: 3 }]), 6);
});
J
git add -A; git commit -qm "feature: invoice rendering with per-line flooring"
