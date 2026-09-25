#!/bin/bash
# qa-full-fixture.sh <dir>: builds the Node repo used by evals/reports/2026-09-24-qa-full-skill-invocation.md.
# Its feature branch plants one trigger per qa-full check (failing test, secret, SQL injection,
# N+1, inaccessible form, root Dockerfile); a local bare origin makes gstack preflights work.
set -e
D="$1"; rm -rf "$D"; mkdir -p "$D"; cd "$D"
KEY="sk_$(printf live)_51FakeFixtureKeyDoNotUse0000000000"  # assembled so the literal never sits in this repo
git init -q -b main; git config user.email qa@example.test; git config user.name "QA Fixture"
mkdir -p src tests
cat > package.json <<'J'
{ "name": "shopfix", "version": "1.0.0", "private": true, "type": "commonjs",
  "scripts": { "test": "node --test" } }
J
cat > CLAUDE.md <<'M'
# shopfix

Plain Node (no dependencies, no build step). Tests use the built-in runner.

## qa-full

- Test/build: `npm test` (there is no build step)
- Dev URL: none. There is no dev server for this project.
- Codex passes: do not use Codex for this project.
- /pentest: not authorized for this project.
M
cat > src/cart.js <<'J'
function cartTotal(items) {
  return items.reduce((sum, i) => sum + i.price * i.qty, 0);
}
module.exports = { cartTotal };
J
cat > tests/cart.test.js <<'J'
const test = require('node:test');
const assert = require('node:assert');
const { cartTotal } = require('../src/cart');
test('sums price times quantity', () => {
  assert.strictEqual(cartTotal([{ price: 2, qty: 3 }, { price: 5, qty: 1 }]), 11);
});
J
printf 'node_modules\n' > .gitignore
# FIXTURE_BASE_AGE_DAYS backdates the base commit (daily-qa-fixture.sh uses it to keep it out of a 24h window).
BASE_DATE="$(( $(date +%s) - ${FIXTURE_BASE_AGE_DAYS:-0} * 86400 )) +0000"
git add -A; GIT_AUTHOR_DATE="$BASE_DATE" GIT_COMMITTER_DATE="$BASE_DATE" git commit -qm "base: cart total"
git switch -qc feature/checkout
mkdir -p models web
cat > src/discount.js <<'J'
// Apply a percentage discount code to a cart total.
function applyDiscount(total, percent) {
  if (percent < 0) throw new Error('negative discount');
  return total - total * percent;   // percent is given as a whole number, e.g. 10 for 10%
}
function shippingFor(total, country) {
  if (country === 'US') return total > 50 ? 0 : 5;
  if (country === 'CA') return total > 75 ? 0 : 8;
  return 15;
}
module.exports = { applyDiscount, shippingFor };
J
cat > tests/discount.test.js <<'J'
const test = require('node:test');
const assert = require('node:assert');
const { applyDiscount } = require('../src/discount');
test('10 percent off 200 is 180', () => {
  assert.strictEqual(applyDiscount(200, 10), 180);
});
J
cat > src/payments.js <<J
const STRIPE_SECRET_KEY = '$KEY';
function chargeHeaders() {
  return { Authorization: \`Bearer \${STRIPE_SECRET_KEY}\` };
}
module.exports = { chargeHeaders };
J
cat > models/orderRepository.js <<'J'
// db.query(sql, params?) returns rows.
async function findCustomerByEmail(db, email) {
  return db.query("SELECT * FROM customers WHERE email = '" + email + "'");
}
async function ordersWithItems(db) {
  const orders = await db.query('SELECT * FROM orders');
  for (const order of orders) {
    order.items = await db.query('SELECT * FROM order_items WHERE order_id = ?', [order.id]);
  }
  return orders;
}
module.exports = { findCustomerByEmail, ordersWithItems };
J
cat > web/CheckoutForm.tsx <<'J'
export function CheckoutForm({ onPay }: { onPay: () => void }) {
  return (
    <form>
      <input type="email" placeholder="Email" />
      <input type="text" placeholder="Card number" />
      <div className="pay-button" onClick={onPay} style={{ color: '#aaa', background: '#bbb' }}>Pay now</div>
    </form>
  );
}
J
cat > Dockerfile <<J
FROM node:20
WORKDIR /app
COPY . .
ENV STRIPE_SECRET_KEY=$KEY
EXPOSE 3000
CMD ["node", "src/cart.js"]
J
git add -A; git commit -qm "feature: checkout (discounts, payments, orders, form, container)"
# A local bare origin so gstack's `git fetch origin <base>` preflights work; main is pushed, the feature branch is not.
rm -rf "$D.origin.git"; git init -q --bare "$D.origin.git"
git remote add origin "$D.origin.git"; git push -q origin main
git fetch -q origin; git remote set-head origin main >/dev/null 2>&1 || true
