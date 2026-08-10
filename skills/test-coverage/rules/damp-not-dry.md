# DAMP, not DRY, in test code

Production code should be DRY; test code should be **D**escriptive **A**nd
**M**eaningful **P**hrases, even at the cost of some duplication. A shared
`setupComplexFixture()` that five tests call, each asserting something
different, forces a reader to open that helper to understand any single test.

**Fix:** inline the values that matter to *this* test's assertion; extract
only truly-identical boilerplate (e.g. a DB connection, not fixture data the
assertion depends on).

```
// Bad: DRY'd fixture hides what actually matters to this test
function setupOrder() {
  return buildOrder({ status: 'pending', total: 42, items: 3, discount: 0.1 })
}
test('applies discount', () => {
  const order = setupOrder()
  expect(order.total).toBe(42)   // reader must open setupOrder() to know why 42
})

// Better: DAMP — the values this test cares about are visible in the test
test('applies 10% discount to a $50 order', () => {
  const order = buildOrder({ subtotal: 50, discount: 0.1 })
  expect(order.total).toBe(45)
})
```
