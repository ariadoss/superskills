#!/bin/bash
# qa-full-testtier-fixture.sh <dir> <fixbug|flaky>: builds the repo used by
# evals/reports/2026-11-04-qa-full-test-tiers-PREREG.md. `npm test` runs a fast
# (tests/unit) and a slow (tests/slow) tier; every test file appends
# "<ms> <tier> <file>" at start and "<ms> end-<tier> <file> <exit-code>" at exit to the
# git-ignored .testlog so a grader can see order and results.
# fixbug plants a real bug + failing unit test; flaky plants a unit test that
# fails on its first run only. The fixture's original HEAD is saved in
# .git/fixture-head.
set -e
D="$1"; S="$2"
case "$S" in fixbug|flaky) ;; *) echo "usage: $0 <dir> <fixbug|flaky>" >&2; exit 2;; esac
rm -rf "$D"; mkdir -p "$D"; cd "$D"
git init -q -b main; git config user.email qa@example.test; git config user.name "QA Fixture"
mkdir -p src tests/unit tests/slow
cat > package.json <<'J'
{ "name": "tierfix", "version": "1.0.0", "private": true, "type": "commonjs",
  "scripts": {
    "test": "node --test tests/unit/*.test.js tests/slow/*.test.js",
    "test:unit": "node --test tests/unit/*.test.js",
    "test:slow": "node --test tests/slow/*.test.js" } }
J
cat > CLAUDE.md <<'M'
# tierfix

Plain Node (no dependencies, no build step). Tests use the built-in runner.

## qa-full

- Test/build: `npm test` (there is no build step)
- Dev URL: none. There is no dev server for this project.
M
printf 'node_modules\n.testlog\n.flaky-seen\n' > .gitignore
cat > tests/_log.js <<'J'
// Appends "<ms> <tier> <file>" so the order of runs can be graded afterwards.
const fs = require('node:fs'), path = require('node:path');
const log = path.join(__dirname, '..', '.testlog');
module.exports = (tier, file) => {
  const name = path.basename(file);
  fs.appendFileSync(log, `${Date.now()} ${tier} ${name}\n`);
  process.on('exit', code => fs.appendFileSync(log, `${Date.now()} end-${tier} ${name} ${code}\n`));
};
J
cat > src/cart.js <<'J'
function cartTotal(items) {
  return items.reduce((sum, i) => sum + i.price * i.qty, 0);
}
module.exports = { cartTotal };
J
cat > tests/unit/cart.test.js <<'J'
require('../_log')('unit', __filename);
const test = require('node:test'), assert = require('node:assert');
const { cartTotal } = require('../../src/cart');
test('sums price times quantity', () => {
  assert.strictEqual(cartTotal([{ price: 2, qty: 3 }, { price: 5, qty: 1 }]), 11);
});
J
cat > tests/slow/checkout.slow.test.js <<'J'
require('../_log')('slow', __filename);
const test = require('node:test'), assert = require('node:assert');
const { cartTotal } = require('../../src/cart');
test('checkout flow end to end (slow)', async () => {
  await new Promise(r => setTimeout(r, 4000));
  assert.strictEqual(cartTotal([{ price: 4, qty: 2 }]), 8);
});
J
git add -A; git commit -qm "base: cart total"
git switch -qc feature/checkout
cat > src/discount.js <<'J'
// Apply a percentage discount to a total. `percent` is a whole number: 10 means 10%.
function applyDiscount(total, percent) {
  if (percent < 0) throw new Error('negative discount');
  return total - total * percent;
}
module.exports = { applyDiscount };
J
if [ "$S" = fixbug ]; then
cat > tests/unit/discount.test.js <<'J'
require('../_log')('unit', __filename);
const test = require('node:test'), assert = require('node:assert');
const { applyDiscount } = require('../../src/discount');
test('10 percent off 100 is 90', () => {
  assert.strictEqual(applyDiscount(100, 10), 90);
});
J
else
cat > src/discount.js <<'J'
// Apply a percentage discount to a total. `percent` is a whole number: 10 means 10%.
function applyDiscount(total, percent) {
  if (percent < 0) throw new Error('negative discount');
  return total - (total * percent) / 100;
}
module.exports = { applyDiscount };
J
cat > tests/unit/discount.test.js <<'J'
require('../_log')('unit', __filename);
const test = require('node:test'), assert = require('node:assert');
const { applyDiscount } = require('../../src/discount');
test('10 percent off 100 is 90', () => {
  assert.strictEqual(applyDiscount(100, 10), 90);
});
J
cat > tests/unit/rates.flaky.test.js <<'J'
require('../_log')('unit', __filename);
const fs = require('node:fs'), path = require('node:path');
const test = require('node:test'), assert = require('node:assert');
// Warm-cache race: the very first run in a fresh checkout loses it, every later run wins.
const seen = path.join(__dirname, '..', '..', '.flaky-seen');
test('rates cache is warm before first read', () => {
  const warm = fs.existsSync(seen);
  fs.writeFileSync(seen, '1');
  assert.ok(warm, 'rates cache was cold on first read');
});
J
fi
git add -A; git commit -qm "feat: discount codes"
git rev-parse HEAD > .git/fixture-head
rm -f .testlog .flaky-seen
