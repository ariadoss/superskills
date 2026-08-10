# Descriptive names, cleanly created test data

Test names state the behavior and condition
(`rejectsTransfer_whenBalanceInsufficient`), not `test1`/`testEdgeCase` — a
failing test name should tell you what broke without opening the file.

Build test data with a builder/factory that defaults every field to something
valid and lets the test override only what it cares about — not a
copy-pasted 20-field literal per test.

```
// Bad: unclear name, and a giant literal where only one field matters
test('test2', () => {
  const user = { id: 1, name: 'Ada', email: 'a@x.com', role: 'admin',
                 createdAt: '2020-01-01', active: true, balance: -50, ... }
  expect(canWithdraw(user, 100)).toBe(false)
})

// Better: descriptive name, builder overrides only what's relevant
test('rejectsWithdrawal_whenBalanceInsufficient', () => {
  const user = buildUser({ balance: -50 })
  expect(canWithdraw(user, 100)).toBe(false)
})
```
