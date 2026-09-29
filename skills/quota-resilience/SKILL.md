---
name: quota-resilience
version: 1.0.0
description: |
  Salvage and resume when the session hits its own usage limit / quota hard
  stop: commit complete work, leave a clean tree, write a committed resume
  note, report exact state, and offer one bounded auto-restart where the host
  can schedule one. Use when the agent's own usage limit, quota, or rate
  budget is exhausted mid-task, or when picking up work a session left when
  it died that way. Not for HTTP 429s / rate limits the user's application
  receives — that is application behavior (/debug, /qa), not agent state.
triggers:
  - hit my usage limit
  - usage limit hit
  - quota exhausted
  - quota hard stop
  - session died mid-task
  - resume after the limit resets
allowed-tools:
  - Bash
  - Read
  - Write
---

# /quota-resilience

A usage-limit hard stop is a shutdown, not an obstacle to route around.
Retrying the blocked call, downgrading the approach, or improvising "one
more push" spends the remaining window and makes the resume expensive. This
skill spends that window making the resume cheap instead: committed work,
clean tree, a note that carries the state, and one bounded restart where the
host can schedule one.

## Phase 1 — on the limit error (stop)

Hard rules, in order:

1. **Stop initiating work.** No retries of the blocked call, no new
   subagents, no reduced-effort substitutes for the blocked task. Every
   further call either fails identically or steals the window the shutdown
   needs.
2. **Salvage.** Split the working tree:
   - *Complete* — passes its own check (tests, lint, build) or stands alone
     (docs, config): commit with an honest message.
   - *Incomplete* — never left dangling. Commit as a clearly labeled `wip:`
     checkpoint if it is a useful base, or revert it if it is noise. Either
     way `git status` ends **clean**: the next session starts from committed
     state, never from a diff it has to reverse-engineer.
   - Do not start new work to "round out" a commit.
3. **Write the resume note** — `QUOTA-RESUME.md` at the repo root, committed
   with the salvage. Required sections:
   - **Goal** — one line: the task's definition of done.
   - **Done** — bullets with commit hashes.
   - **In flight** — file:line, what exists, what is missing.
   - **Next steps** — ordered, each executable without re-deriving context
     (exact commands, paths).
   - **Verify** — the command(s) that prove the goal is met.
   - **Context** — decisions already made; pointers to plan/spec/task list.
4. **Report exact state.** The final message states what is committed
   (hashes), what is NOT done, where the note is, and how to resume. Never
   a formulation that reads as completion.
5. **Offer one bounded restart.** The reset time is plan-specific and
   unknowable from inside the session, so schedule conservatively and treat
   the scheduled run itself as the probe: if it executes, the limit is gone;
   if it cannot, nothing happens.
   - Host with a scheduler: create **one one-shot** automation (never
     recurring; it may chain at most one follow-up if that run hits the
     limit again — two hops total). Its prompt: read `QUOTA-RESUME.md` in
     this repo, run the Verify step, continue the Next steps in order, and
     follow this skill if the limit hits again.
   - ZCode: prefer the off-peak queue (no plan-quota cost) when the work
     can wait; otherwise a one-shot scheduled automation a conservative
     delay out.
   - Host without a scheduler (Claude Code, Codex, Cursor): print the exact
     resume command for the user (e.g. `claude --resume`, or "resume per
     QUOTA-RESUME.md in <repo>").
   - **Consent:** scheduling unattended model work is a spending decision.
     Propose it — what will run, when, what it costs — and create it only
     after an explicit yes. The zero-cost off-peak path is the exception.

## Phase 2 — resuming after the stop

1. Read `QUOTA-RESUME.md` first, before exploring the repo or re-deriving
   state. It is the authority on where the last session stopped.
2. Re-verify the cheapest way: run the note's Verify command before
   building on the claimed state.
3. Work the Next steps in order. On goal met + verification passing:
   **delete the note** (its existence means "interrupted") and commit the
   deletion.
4. A new limit hit mid-resume → Phase 1 again, updating the existing note
   rather than adding a second.

## Boundaries

- This skill is about the **agent's own** compute budget (usage limit,
  quota exhaustion, hard stop). HTTP 429 / rate limiting **received by the
  user's application** is application behavior: `/debug` or `/qa`, not this
  skill.
- Beyond the salvage commits above it mutates nothing, and it never pushes.
