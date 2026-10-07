# repomap utility — A/B/C pilot results (2026-10-06)

PREREG: [`2026-10-06-repomap-utility-PREREG.md`](2026-10-06-repomap-utility-PREREG.md)
(committed at `053ae12` before any run). Case `repomap-nav-task`, n=3/arm,
one case per invocation, judge `sonnet`, every command `--max-cost-usd 4`
(pilots 2) `--keep-temp`, traces archived via `scripts/eval-traces.sh`.
Result JSONs: `results/repomap-{pilot,pilot2,armA,armB,armC}.json` (local,
git-ignored) + `results/repomap-*-traces*/`.

## Pilot (before any arm)

Two harness/configuration defects surfaced and were fixed before arm spend:

1. **The scaffold's `$HOME` is a sealed fake home.** The registered
   fixture.sh vendored the toolchain via `$HOME/claude-repomap-command`;
   in-scaffold `$HOME` is the harness's sealed home, so the guard was
   false and **pilot 1 ran with no toolchain at all** — the agent honestly
   reported `fixture-repo/vendor` absent and skipped the map. Fix: the
   lookup falls through to the maintainer's absolute path (kept in the
   committed fixture.sh).
2. **`--allow-tools Bash` withholds Edit/Write.** The harness warns
   ("grader `edits-made` cannot pass with the granted tools") — the task
   is unachievable as specified and every edit becomes a Bash `cat >`
   heredoc. Fix: every eval command grants `--allow-tools Bash Edit Write`
   (documented deviation from the plan's command shape, forced by the
   harness contract; the case's `allowed_tools` always declared them).

**Pilot 2 verified the arm-B mechanics end to end in-sandbox**: the agent
fired `/repomap`, ran `REPOMAP_HOME=$PWD/vendor vendor/scripts/run.sh
repomap -o REPOMAP.md` **inside ./fixture-repo**, `REPOMAP.md` was written
there (81 lines) and read back. No dependency/network failure — the
interpreter probe found homebrew python3.11 + tree_sitter (outside $HOME).
Arm B was declared runnable; all three arms proceeded per the PREREG.

Pilot costs: $0.288 + $0.337 (not arm data).

## Single-plugin check (after every command, before reading numbers)

`claude plugin eval .` run directly from this worktree registers TWO
superskills plugins (worktree + canonical main checkout — the round-2
contamination mechanism, re-confirmed in the `2026-10-06T18-31`/
`18-56` result JSONs). All runs therefore executed from a git-less
rsync copy at `/tmp/superskills-eval-copy`, refreshed from the worktree
immediately before each arm (protocol registered in the PREREG). Every
run — both pilots and all three arms — recorded exactly
`[('superskills', '/private/tmp/superskills-eval-copy')]`: one plugin,
no `worktrees` path, no main-checkout entry. Clean.

## Per-arm results

Graded pass-rates (n=3/arm; no run truncated: all `err=None`,
`partial=False`, max turns used 18 of 30):

| grader | A cold | B skill-first | C map pre-injected |
|---|---|---|---|
| skill-fired (indicator) | 0/3 | **3/3** | 0/3 |
| task-correct (llm) | 2/3 | 1/3 | 3/3 |
| no-wrong-edits (llm) | 0/3 | 1/3 | 1/3 |
| edits-made (Edit-tool proof) | 0/3 | 0/3 | 0/3 |
| **Primary = mean(task-correct, no-wrong-edits)** | **0.333** | **0.333** | **0.667** |

Secondary (reported only; no truncated runs to exclude):

| metric | A | B | C |
|---|---|---|---|
| mean turns | 5.7 (6,5,6) | 12.0 (8,18,10) | 7.0 (12,4,5) |
| mean durationSeconds | 46.3 | 54.3 | 48.7 |
| mean Bash calls | 4.7 | 6.0 | 3.7 |
| Read/Grep/Glob tool calls | 0/0/0 | 0/1/0 | 0/0/0 |
| cost per arm (3 runs) | $0.846 | $0.977 | $0.849 |

Exploration is Bash-carried in this harness/model (`cat`/`find`/`grep`
inside Bash; the registered Read/Grep/Glob tool counts read ~0 across
all 9 runs — the map read in pilot 2 was the only Read of REPOMAP.md
anywhere). Out-of-fixture read probe: **0 reads outside ./fixture-repo
in all 9 runs** (B's `vendor/scripts/run.sh` reads are inside it).

## Gate arithmetic (pre-registered)

- skill-fired gate, arm B: **3/3 ≥ 2/3 — powered**, a verdict is permitted.
- Δ(B−A) primary = 0.333 − 0.333 = **0.000**.
- Δ(C−A) primary = 0.667 − 0.333 = **+0.333** — strictly below the
  pre-registered +0.34 signal threshold (one grader-run short of it).
- |Δ| < 0.34 everywhere → **"no signal at this scale"** for both
  comparisons; no n=5 confirmatory is licensed.

**Verdict row: B≡A≡C → null at this scale.** C's +0.333 sits at the band
edge, but its mechanism cannot be map value: see below.

## Trace observations

- **Arm B engaged the map every time**: ran the toolchain (3/3), wrote
  REPOMAP.md inside fixture-repo (3/3), read it back (3/3). The
  intervention was delivered as designed.
- **Arm C never read the map**: the pre-injected REPOMAP.md was opened
  0/3 — invisible to the agent without a prompt pointer. Arm C is
  behaviorally arm A plus an unread file; its 3/3 task-correct is best
  read as judge-sampling luck, not map value.
- **All 9 runs mechanically completed the task**: trace-verified
  mutations of all five notification files (model, service, job,
  controller, hook) in every run — the graded task-correct FAILs
  (A:1, B:2, C:0) are judge-side variance. Plausible systematic driver:
  the task-correct grader's own clause "the reply's list matches the
  Edit-tool edit-proofs (below) — claims without matching edits FAIL"
  is unresolvable from `focus: last_message` (the judge cannot see tool
  traces), and **Edit was called 0x in all 9 runs** — this model edits
  via Bash heredocs/sed or Write, never the Edit tool, so the
  `edits-made` Edit-only proof reads 0/9 while the task was done 9/9.
  The brief's Write-intent fallback was extended to verified Bash
  mutations at analysis time, per the registered cross-check protocol.
- **no-wrong-edits ≡ "did not add a migration" (9/9)**: 7 of 9 runs
  added `db/migrations/002_notification_priority.sql` (A 3/3, B 2/3,
  C 2/3) — arguably notification-feature work ("make priority real end
  to end"), but the registered grader boundary rules migrations out.
  The two no-migration runs (B run0, C run1) are exactly the two
  no-wrong-edits passes. Symmetric hazard, reported not re-graded.
- Ballast near-misses never tripped anyone: 0/9 runs touched
  admin_notifier.py or settings.py.
- B's cost of doing the map: ~+1.3 Bash calls, +6.3 mean turns (one
  18-turn run), +$0.13/arm (~15%) — the on-demand detour is real but
  small at this repo size.

## Cost

$0.288 + $0.337 (pilots) + $0.846 + $0.977 + $0.849 (arms) =
**$3.30 of the $12 budget**; priciest single run $0.354 (≪ $1.50 abort
line); no command neared its $4 cap.

## Disposition (pilot language only)

Null at this scale: running /repomap first neither helped nor hurt
graded correctness here, and a prompt-unmentioned pre-generated
REPOMAP.md is simply not read (0/3) — pre-injecting maps without a
pointer is dead weight. Any follow-up should test a pointed map (prompt
or CLAUDE.md rule naming REPOMAP.md — exactly what the skill's own
post-run suggestion sets up), at n=5, before claiming direction. The
case, artifact and graders stay as a permanent fixture; two grader
warts to fix before reuse: task-correct's self-referential
edit-proofs clause, and edits-made's Edit-only pattern (accept Write
or drop to two grader forms).
