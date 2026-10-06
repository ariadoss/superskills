---
max_turns: 4
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [handoff, resume, C]
---

You are a fresh agent with no memory of any prior session. Below is
the handoff.md the previous session left for you. Read it and answer, in
your reply, each of these five questions with specifics:
1. What is the task's definition of done, and what proves it?
2. What is already finished (with its commit hashes / file:line)?
3. What is the single next action, as an exact command?
4. What must you NOT redo, and which known-dead approaches were tried?
5. How would you resume the original session (harness + exact command)?

--- handoff.md (verbatim) ---
# Handoff: land three independent slices (export-api, timeout-red, deps) @ 2026-10-06

## Session
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"

## Goal
Get feature/export-api, fix/timeout-red and chore/deps onto main with one merge commit per slice, all suites green, plus written release notes.

## Done
- feature/export-api: complete, 7 commits, suite green. Not merged. Commit hashes were not recorded this session; list them with `git log main..feature/export-api --oneline`.
- fix/timeout-red: 2 of the 3 tests pass. These two are the only verified results in the whole task.

## In flight
- fix/timeout-red worktree: a candidate fix is uncommitted.
  - What exists: the counter increment moved so it runs before the sleep in the retry loop.
  - Target failure: test_retries_exhausted at spec/net/client_spec.rb:88. Cause: the retry loop resets the backoff counter one iteration early.
  - What is missing: a test run with the candidate applied, then a commit.
  - Unverified: whether the fix makes test_retries_exhausted pass, and whether the 2 passing tests still pass afterward.
- feature/export-api: ready to fast-forward when it was finished, but main has since moved 2 commits ahead, so a fast-forward will now fail. Rebase vs merge is undecided.

## Next steps
1. In the fix/timeout-red worktree, run `bundle exec rspec spec/net/client_spec.rb:88`. The rspec invocation is inferred from the spec/ layout and was not confirmed this session.
2. If step 1 passes, run the full file with `bundle exec rspec spec/net/client_spec.rb` to confirm all 3 tests are green. Then commit the fix on fix/timeout-red. If step 1 fails, re-check the counter placement in the retry loop against line 88's expectation.
3. Ask the user whether feature/export-api should be rebased or merged onto main. Recommend merge: it never needs a force-push, and the user already accepted one merge commit per slice. Rebasing a branch that has been pushed would need a force-push, which the user forbids.
4. Once the user decides, run `git checkout main && git merge --no-ff feature/export-api` (or the rebase path), then re-run the export-api suite on main.
5. Run `git checkout main && git merge --no-ff fix/timeout-red`, then re-run spec/net/client_spec.rb on main.
6. Ask the user for the lockfile decision that blocks chore/deps. Do not touch the lockfile before they answer.
7. Write the release notes for the landed slices. Their location and format were not set this session, so ask or follow the repo's existing convention.

## Verify
- `bundle exec rspec spec/net/client_spec.rb` on main: 3 of 3 passing.
- The export-api suite green on main after its merge. The exact command was not recorded.
- `git log main --merges --oneline` shows one merge commit per landed slice.

## Do not redo
- Do not re-implement or re-test feature/export-api's 7 commits. That work is done and was green.
- Do not rewrite the 2 passing fix/timeout-red tests.
- Do not retry the fast-forward of feature/export-api. It fails because main is 2 commits ahead.
- Do not discard the uncommitted timeout fix in the fix worktree. Test it, don't rewrite it.

## Context
- User preferences stated this session: never force-push; one merge commit per slice is fine; ask before touching the lockfile.
- Open user decisions: rebase vs merge for feature/export-api, and the chore/deps lockfile question.
- chore/deps is untouched. Its only blocker is the lockfile decision.
- Not started: the rebase/merge decision, the merges, the release notes.
- Never use bare `git stash` in these worktrees. The stash stack is shared across worktrees.
--- end handoff.md ---
