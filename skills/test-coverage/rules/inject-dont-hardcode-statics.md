# Wrap statics and singletons behind an injectable seam

Static/global state (a singleton client, `Date.now()`, a module-level cache)
can't be swapped for a fake, so a test that depends on it either hits the
real thing (slow/flaky) or can't isolate the behavior it's checking.

**Fix:** when a coverage gap traces back to untestable statics, introduce a
small injectable seam (constructor/parameter injection) rather than reaching
for static-mocking tricks — this is SOLID-D applied to legacy code, and it's
usually a 5-line change that unlocks the whole test.

```
// Bad: hardcoded static — can't test "expires after 24h" without real waiting
function isExpired(token) {
  return Date.now() - token.issuedAt > 24 * 60 * 60 * 1000
}

// Better: inject the clock — now the test controls time
function isExpired(token, clock = Date) {
  return clock.now() - token.issuedAt > 24 * 60 * 60 * 1000
}
test('expires after 24h', () => {
  const fakeClock = { now: () => token.issuedAt + 25 * 60 * 60 * 1000 }
  expect(isExpired(token, fakeClock)).toBe(true)
})
```
