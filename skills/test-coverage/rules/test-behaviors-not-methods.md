# Test behaviors, not methods; one behavior per test

Name and structure tests around a **behavior**
(`returns zero for empty cart`), not a method (`test_calculateTotal`). A
method with 5 branches needs 5+ behavior tests, not one test asserting all 5
outputs.

Each test asserts one behavior — if its description needs "and" to stay
accurate, split it.

```
// Bad: one test, one method, five unrelated assertions bundled together
test('calculateTotal', () => {
  expect(calculateTotal([])).toBe(0)
  expect(calculateTotal([item])).toBe(10)
  expect(calculateTotal([item], { discount: 0.5 })).toBe(5)
  expect(calculateTotal([item, item2])).toBe(25)
})

// Better: one behavior per test — each can fail independently with a clear name
test('returns zero for an empty cart', () => {
  expect(calculateTotal([])).toBe(0)
})
test('applies a percentage discount to the subtotal', () => {
  expect(calculateTotal([item], { discount: 0.5 })).toBe(5)
})
```
