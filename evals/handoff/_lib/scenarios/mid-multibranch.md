You are managing three parallel worktrees. State:

Task: land three independent slices. feature/export-api: complete, suite
green, 7 commits, NOT merged (fast-forward ready). fix/timeout-red: 2 of 3
tests passing; the failing one is test_retries_exhausted at
spec/net/client_spec.rb:88 — the retry loop resets the backoff counter one
iteration early; a candidate fix (moving the counter increment before the
sleep) is written but unverified. chore/deps: untouched, blocked on a
lockfile decision the user has not made.
Complication: main moved two commits ahead while you worked; the
feature/export-api fast-forward will now fail; rebase vs merge is undecided.
Done: as above per branch. In flight: the timeout fix candidate (uncommitted
in the fix worktree). Not started: the rebase decision, the two merges, the
release notes.
User preferences stated mid-session: never force-push; one merge commit per
slice is fine; ask before touching the lockfile.
Verification so far: only fix/timeout-red's two passing tests are verified.
Write the handoff note now.
