# Know your test doubles, use the narrowest one

- **Dummy** — passed but never used (satisfies a required parameter).
- **Stub** — returns canned answers, no behavior.
- **Fake** — a working lightweight implementation (in-memory DB).
- **Mock** — verifies it was *called* a certain way.
- **Spy** — a real object wrapped to record calls, otherwise delegates.

Pick the weakest double that makes the test pass for the right reason. A mock
where a stub would do is over-specification — it asserts something the test
doesn't actually care about.

```
// Over-specified: a mock where a stub would do
const clock = mock(Clock)
when(clock.now()).thenReturn(FIXED_TIME)
service.processOrder(order)
verify(clock, times(1)).now()   // <- nobody cares HOW MANY times now() was called

// Right-sized: a stub — provides the value, asserts nothing about call count
const clock = stub(Clock, { now: () => FIXED_TIME })
service.processOrder(order)
expect(order.processedAt).toBe(FIXED_TIME)
```
