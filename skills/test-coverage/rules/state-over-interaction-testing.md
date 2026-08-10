# Prefer state testing over interaction testing

Given a choice, assert on the resulting **state** (return value, object
fields, persisted record) rather than *how* the code got there (which methods
it called, in what order). State assertions survive refactors that preserve
behavior; interaction assertions break on every internal reshuffle — that's
the definition of a change-detector test
([avoid-change-detector-tests.md](avoid-change-detector-tests.md)).

```
// Bad: interaction test — breaks if the internal call order changes
cart.addItem(item)
verify(pricingEngine, times(1)).calculateSubtotal(any())
verify(pricingEngine, times(1)).applyDiscounts(any())

// Better: state test — survives an internal refactor of how total is computed
cart.addItem(item)
expect(cart.total).toBe(19.99)
```
