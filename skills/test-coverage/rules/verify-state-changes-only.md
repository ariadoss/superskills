# Only verify state-changing calls, never query/getter calls

`verify(x, times(1)).getUser()` tests nothing useful — call the getter and
assert on its **return value** instead. Reserve `verify()`/interaction
assertions for calls with a **side effect** (`save()`, `send()`, `delete()`)
where the effect itself isn't otherwise observable.

**Why:** verifying a query call couples the test to *how* the code fetches
data, not *what* it does with it — a refactor that calls `getUser()` twice
instead of once breaks the test for no behavioral reason.

```
// Bad: verifies a pure query was called
verify(userRepo, times(1)).findById(42)

// Better: assert on the value actually used
const result = service.getDisplayName(42)
expect(result).toBe('Ada Lovelace')

// Good use of verify(): a real side effect with no other observable trace
service.deactivateUser(42)
verify(emailSender, times(1)).send('user-deactivated@ada@example.com', ...)
```
