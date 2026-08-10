# Prefer real objects; fake before you mock, mock last

**Hierarchy: real > fake > stub > mock.** Reach for the real dependency first
(a real in-memory DB, a real small object). If it's too slow/flaky/costly, use
a **fake** — a lightweight working implementation (in-memory DB, fake clock).
Only mock when neither is feasible, and even then keep it to interaction
verification of *your own* seams ([dont-mock-types-you-dont-own.md](dont-mock-types-you-dont-own.md),
[verify-state-changes-only.md](verify-state-changes-only.md)).

**Why:** mocking everything gives tests that pass against a broken
implementation and fail against a correct one that happens to call things in
a different order — the mock encodes your assumptions about the dependency,
not its real behavior.

```
// Bad: mocks the DB entirely — never proves the query is even valid SQL
const db = mock(Database)
when(db.query(any())).thenReturn([{id: 1}])
expect(userService.getUser(1)).toEqual({id: 1})

// Better: real in-memory/test DB — proves the query actually works
const db = new SqliteDb(':memory:')
db.exec(SCHEMA)
db.exec("INSERT INTO users VALUES (1, 'a')")
expect(userService.getUser(1)).toEqual({id: 1, name: 'a'})
```
