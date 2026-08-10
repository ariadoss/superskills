# Limit mocks per test (1–2)

More than 1–2 mocks in a single test usually means the unit under test has
too many collaborators (a design smell — see SOLID-S in
`ENGINEERING_STANDARDS.md`) or the test is verifying implementation wiring
instead of behavior.

**When you're reaching for a third mock**, consider:
- a fake instead of another mock ([real-fake-mock-hierarchy.md](real-fake-mock-hierarchy.md)),
- an integration test instead (see `SKILL.md` Step 5's pyramid rule),
- or whether the unit itself needs splitting.

```
// Smell: 4 mocks to test one method — the method is doing too much
test('placeOrder', () => {
  const inventory = mock(InventoryService)
  const pricing = mock(PricingService)
  const payment = mock(PaymentGateway)
  const notifier = mock(NotificationService)
  // ...4 collaborators wired together in one unit test
})

// Better: extract an OrderPlacer that composes the smaller, individually
// tested units, and test each collaborator's contract in its own test file
// with at most 1-2 doubles.
```
