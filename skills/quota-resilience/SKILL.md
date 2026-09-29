---
name: quota-resilience
version: 1.1.0
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
   - **Host-native scheduler first.** ZCode: prefer the off-peak queue (no
     plan-quota cost) when the work can wait; otherwise one one-shot
     scheduled automation.
   - **Otherwise, the OS scheduler driving the CLI's headless mode.** The
     coding CLIs can continue a session non-interactively, so a local
     one-shot cron/launchd/systemd entry works. Verified resume commands
     (re-check `<cli> --help` before relying on a flag; they move between
     versions):
     - Claude Code: `claude -c -p "<prompt>"` (most recent session in this
       directory) or `claude --resume <session-id> -p "<prompt>"`. Pass an
       unattended permission set — `--permission-mode acceptEdits` plus a
       narrow `--allowedTools` — never a blanket permission skip.
     - Codex: `codex exec resume --last "<prompt>"`.
     - OpenCode: `opencode run -c "<prompt>"`.
     - Cursor / Augment / Continue: no verified headless-resume path —
       print exact resume instructions for the user instead of guessing.
     Wrap the command in a small script kept **outside the repo** (e.g.
     `"${TMPDIR:-/tmp}/quota-resume-<repo>.sh"`, so the tree stays clean)
     that `cd`s into the repo and appends output to a log next to itself.
     Register exactly **one** shot:
     - Linux: `systemd-run --user --on-active=<delay> --unit=quota-resume
       <script>` — a transient timer, nothing to clean up.
     - macOS: a LaunchAgent plist under `~/Library/LaunchAgents` with
       `StartCalendarInterval` set `<delay>` ahead; the resumed run
       unloads and deletes it (`launchctl unload` + `rm`) during note
       cleanup. Do not rely on `at` — it is disabled by default on macOS.
     - Last resort: a crontab line tagged `# superskills-quota-resume`
       that the resumed run strips from the crontab.
   - **Consent:** a scheduled run is unattended model work — a spending
     decision. Propose what will run, when, and roughly what it costs;
     create it only after an explicit yes. The zero-cost off-peak path is
     the exception.
   - **Bounded:** one shot, never recurring. The scheduled prompt must
     say: follow `/quota-resilience` — read `QUOTA-RESUME.md`, run the
     Verify step, continue the Next steps in order, and if the limit hits
     again, schedule at most one more hop. Two hops total, then it waits
     for the user.

## Phase 2 — resuming after the stop

1. Read `QUOTA-RESUME.md` first, before exploring the repo or re-deriving
   state. It is the authority on where the last session stopped.
2. Re-verify the cheapest way: run the note's Verify command before
   building on the claimed state.
3. Work the Next steps in order. On goal met + verification passing:
   **delete the note** (its existence means "interrupted"), commit the
   deletion, and remove any resume-scheduler artifacts you or the previous
   session created (LaunchAgent plist, systemd unit, crontab line, wrapper
   script and log).
4. A new limit hit mid-resume → Phase 1 again, updating the existing note
   rather than adding a second.

## Boundaries

- This skill is about the **agent's own** compute budget (usage limit,
  quota exhaustion, hard stop). HTTP 429 / rate limiting **received by the
  user's application** is application behavior: `/debug` or `/qa`, not this
  skill.
- Beyond the salvage commits above it mutates nothing, and it never pushes.
