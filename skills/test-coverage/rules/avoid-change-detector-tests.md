# Avoid change-detector tests

A test that fails whenever the implementation changes, even when behavior is
identical, is testing the implementation, not the contract.

**Symptom:** the test mirrors the production code's structure line-for-line
— same branches, same call sequence asserted via mocks. When you touch the
production code, you have to touch the test too, even though nothing a user
would observe changed.

**Fix:** assert on observable inputs/outputs, not internal call sequences —
this is what [verify-state-changes-only.md](verify-state-changes-only.md) and
[state-over-interaction-testing.md](state-over-interaction-testing.md) are for.

```
// Bad: re-implements the branching logic to predict the mock calls
function computeExpectedCalls(status) {
  if (status === 'pending') return ['validate', 'queue']
  if (status === 'active') return ['validate', 'process', 'notify']
}
verify(pipeline).calledInOrder(computeExpectedCalls(order.status))

// Better: assert on the actual observable outcome
const result = pipeline.run(order)
expect(result.status).toBe('processed')
expect(result.notified).toBe(true)
```
