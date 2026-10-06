# /handoff Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/handoff` — a homegrown, cross-harness skill that writes a `handoff.md` (in-progress state, remaining work, and the harness-specific absolute session reference) manually or automatically when session usage crosses 90%, with the note's prompt chosen by a pre-registered three-variant bake-off, and export it to its own public repo like humanize/dbmap/repomap.

**Architecture:** A deterministic `session-ref.sh` detects the harness and resolves the session reference (hook-provided `transcript_path`/`session_id` when auto-triggered, newest-file discovery when manual). A `handoff-trigger-hook.sh` wires one Claude Code hook event (`UserPromptSubmit`) to a once-per-session nudge when usage — read from the statusline's rate-limit cache — crosses 90%, injecting the hook's own `transcript_path`/`session_id` so the skill gets the session reference for free. The note's content model is the eval winner among three prompt variants (Codex-minimal / superskills-structured / hybrid with an explicit reader contract), decided by a two-layer eval: judge scoring plus a behavioral fresh-agent resume test. `export-handoff.sh` mirrors the humanize export pattern into `dist/handoff`, published as a standalone public repo.

**Tech Stack:** bash + jq (house style, single-fork discipline), bats for tests, `claude -p` for generation/judge runs, `claude plugin eval` (sonnet judge) for the behavioral layer.

---

## Research findings (verified before this plan — do not re-litigate)

1. **No mainstream harness ships a threshold-triggered handoff file.** Codex auto-compacts at a configurable percent of the effective context window at turn end (`codex-rs/core/src/session/context_window.rs:112`, `model_post_turn_compact_threshold_percent`, validated 0–100 in `config/mod.rs:3263`); its compact prompt is literally "Create a handoff summary for another LLM that will resume the task" with four buckets (progress+decisions / context+constraints+preferences / remaining next steps / critical data), and the reinjection prefix frames the successor: "Another language model started to solve this problem… build on the work already done and avoid duplicating work." Sessions persist as rollout JSONL under `~/.codex/sessions/YYYY/MM/DD/`, resumable via `codex exec resume --last`. Claude Code auto-compacts near the limit and exposes **PreCompact** and **UserPromptSubmit** hooks; hook stdin JSON carries `session_id`, `transcript_path`, `cwd`; context injection must be `{"hookSpecificOutput":{"hookEventName":"…","additionalContext":"…"}}` — top-level `additionalContext` is silently dropped (documented gotcha; GitHub issues #96193/#16538). Amp's "backstory" is the closest productized analog (from memory, not verified). Superskills' own quota-resilience (QUOTA-RESUME.md at the hard stop) and the SDD ledger are file handoffs but stop-triggered / plan-scoped — nothing fires early.
2. **Best-practice content model** (Codex prompt + prefix + quota-resilience + this repo's lived quota stops): write for a successor with zero memory; self-contained (no "as above"); explicit what-NOT-to-redo; exact next commands with verification; environment + session reference; user preferences bucket; concise. Committed state beats prose — the handoff complements, not replaces, commits.
3. **The 90% usage signal already exists**: `scripts/statusline.sh` caches account-wide rate-limit windows (`used_percentage`, `resets_at`) at `${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline/rate-limits.json` (umask 077, atomic rename). The trigger hook reads that exact file — no new tracking. **Context-window pressure is deliberately out of scope for v1**: no hook event exposes a context percentage to a per-prompt hook (the statusline gets it on its own input stream), and `PreCompact`'s `additionalContext` semantics are compaction *instructions*, not an agent nudge — wiring it to "run /handoff" would be a category error. Noted as a future enhancement (inject the session reference into compaction instructions via PreCompact).
4. **Export pattern** (`scripts/export-humanize.sh`): pure copy into `dist/<name>`, git-allowlist of shipped files, exports its bats tests, self-verifies by running bats in the exported tree, refuses overlaps and symlinks. `dist/` is already gitignored.

## Design decisions (locked)

- **Artifact**: `handoff.md` at the repo root, **gitignored** (ephemeral bridge; quota-resilience Phase 1 step 3 gains one composition line: fold `handoff.md` into QUOTA-RESUME.md and delete it). Minimal harnesses without session persistence get a note in the file saying it is the only bridge. The note's first line records `written by session <id> @ <iso-ts>` — usage windows are account-wide, so parallel sessions can each be nudged and the same file can be overwritten; the label makes last-writer-wins auditable rather than silent (the parallel-agent SDD case keeps its own per-plan ledger, which remains authoritative there).
- **Composition with quota-resilience**: `/handoff` fires early (>=90% usage / manual); quota-resilience stays the hard-stop owner. The verified per-CLI resume-command table is duplicated into `/handoff` (the skill ships standalone in its public repo; it cannot import) — a bats parity test greps both files so the copies cannot drift silently, the same discipline the doctor graders use.
- **Prompt choice is empirical**: three variants bake off; winner ships in SKILL.md. Variants: **A** Codex-minimal (four buckets, prose); **B** superskills-structured (Goal/Done/In-flight/Next/Verify/Context+preferences + Session + Don't-redo, exact commands); **C** = B plus an explicit reader-contract header ("You are a fresh agent with no memory of this session…") and a length discipline line. (C is the hypothesis the session's compaction-framing discussion predicts wins.)
- **Money**: 12 smoke + 36 generation `claude -p` calls, judge calls, 36 recall + 9 execution plugin-eval runs, tiebreak reserve ≈ **$40–62 total**, every command capped, PREREG before any run. The user authorized this eval explicitly (2026-10-06, "write an evaluation to figure out which prompt is best").
- **Trust boundary**: none crossed (local files, no auth, no untrusted input beyond the user's own session state; hook input is trusted host JSON). No `/cso` pass needed.

## File Structure

| File | Responsibility | Create/Modify |
|---|---|---|
| `skills/handoff/SKILL.md` | The skill: manual flow, auto-trigger contract, the winning content model, composition rules. Ships standalone. | Create (Task 8) |
| `skills/handoff/scripts/session-ref.sh` | One job: harness detect → session reference (path + resume command + confidence). Pure bash+jq, no model. | Create (Task 1) |
| `scripts/handoff-trigger-hook.sh` | Hook entry: read statusline cache, threshold check, once-per-session marker, emit correctly-nested additionalContext (echoing hook stdin's transcript_path/session_id). | Create (Task 7) |
| `hooks/hooks.json` | Add the `UserPromptSubmit` entry pointing at the trigger. | Modify (Task 7) |
| `evals/handoff/_lib/scenarios/` | 4 synthetic mid-task session digests (test data). | Create (Task 2) |
| `evals/handoff/_lib/variants/{A,B,C}.md` | The three handoff-prompt variants. | Create (Task 2) |
| `evals/handoff/_lib/generate.sh` | Deterministic driver: for each scenario×variant×run, `claude -p` with variant prompt + digest → `evals/results/handoff-gen/<scenario>-<variant>-r<N>.md`. | Create (Task 3) |
| `evals/handoff/_lib/judge.sh` | Layer-1 judge driver: sonnet `claude -p` scoring each artifact on 5 dimensions; includes 6 hand-labeled calibration pairs. | Create (Task 4) |
| `evals/handoff-resume-*/` × 12 + `evals/handoff-exec-*/` × 3 | Layer-2: recall cases (prompt embeds one artifact; 5 resume-question graders + no-secrets) and execution cases (fixture repo; fresh agent performs the note's next action). | Create (Task 5) |
| `evals/reports/2026-10-06-handoff-PREREG.md` | Pre-registration: variants, endpoints, thresholds, caps — committed before any paid run. | Create (Task 2) |
| `scripts/export-handoff.sh` + `scripts/handoff-dist/README.md` | Public-repo export, humanize pattern. | Create (Task 9) |
| `tests/handoff-session-ref.bats`, `tests/handoff-trigger-hook.bats`, `tests/handoff-export.bats` | Unit tests for the three deterministic pieces. | Create (Tasks 1, 7, 9) |
| `.gitignore` | Add `handoff.md`. | Modify (Task 8) |
| `skills/quota-resilience/SKILL.md` | One composition line in Phase 1 step 3. | Modify (Task 8) |
| `README.md`, `VERSION` + manifests | Ship: skill listed, 2.37.0 → 2.38.0, sync-version.sh. | Modify (Task 10) |

DRY: the trigger reuses the statusline's cache rather than new tracking; session-ref is written once and called by both SKILL.md flows; the resume-command table duplication is deliberate (standalone shipping) and pinned by a parity test. SOLID: session-ref exposes one narrow contract (`print ref, exit 0; print reason, exit 1`), so the hook and the skill are interchangeable consumers. YAGNI: no config surface beyond `HANDOFF_USAGE_THRESHOLD` env (default 90); no daemon; no cross-machine sync.

---

### Task 1: `session-ref.sh` — deterministic session reference (TDD)

**Files:**
- Create: `skills/handoff/scripts/session-ref.sh`
- Test: `tests/handoff-session-ref.bats`

- [ ] **Step 1: Write the failing tests**

`tests/handoff-session-ref.bats`:

```bats
#!/usr/bin/env bats
# session-ref.sh: harness detection and session-reference resolution, tested
# against fixture HOME trees (no real ~/.claude or ~/.codex is touched).

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  # Dual lookup: skills/handoff/scripts/ in superskills, scripts/ in the
  # exported standalone repo (the export relocates the file).
  for cand in "$REPO_ROOT/skills/handoff/scripts/session-ref.sh" "$REPO_ROOT/scripts/session-ref.sh"; do
    [ -f "$cand" ] && REF="$cand" && break
  done
  [ -n "${REF:-}" ]
  HOME_FIX="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME_FIX"
}

@test "claude code: newest transcript in the exactly-munged project dir wins" {
  work="$BATS_TEST_TMPDIR/work/fixture-repo"; mkdir -p "$work"; cd "$work"
  proj="$HOME_FIX/.claude/projects/$(printf '%s' "$PWD" | sed 's:[/.]:-:g')"
  mkdir -p "$proj"
  printf '{}' > "$proj/11111111-1111-1111-1111-111111111111.jsonl"
  sleep 0.05
  printf '{}' > "$proj/22222222-2222-2222-2222-222222222222.jsonl"
  run env -i HOME="$HOME_FIX" PWD="$PWD" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "22222222-2222-2222-2222-222222222222.jsonl"
  echo "$output" | grep -q 'claude --resume 22222222-2222-2222-2222-222222222222'
  ! echo "$output" | grep -q "caution:"
}

@test "claude code: basename-only match emits the verify caution" {
  work="$BATS_TEST_TMPDIR/other/fixture-repo"; mkdir -p "$work"; cd "$work"
  proj="$HOME_FIX/.claude/projects/-somewhere-else-fixture-repo"
  mkdir -p "$proj"; printf '{}' > "$proj/22222222-2222-2222-2222-222222222222.jsonl"
  run env -i HOME="$HOME_FIX" PWD="$PWD" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "caution: project dir matched by basename only"
}

@test "claude code: HANDOFF_SESSION_FILE overrides discovery (hook-provided path)" {
  printf '{}' > "$HOME_FIX/explicit.jsonl"
  run env -i HOME="$HOME_FIX" CLAUDECODE=1 HANDOFF_SESSION_FILE="$HOME_FIX/explicit.jsonl" bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "explicit.jsonl"
}

@test "codex: newest rollout file and codex exec resume --last" {
  sess="$HOME_FIX/.codex/sessions/2026/10/06"
  mkdir -p "$sess"
  printf '{}' > "$sess/rollout-2026-10-06T10-00-00-11111111.jsonl"
  sleep 0.05
  printf '{}' > "$sess/rollout-2026-10-06T11-00-00-22222222.jsonl"
  run env -i HOME="$HOME_FIX" CODEX_SANDBOX=read-only bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "rollout-2026-10-06T11-00-00-22222222.jsonl"
  echo "$output" | grep -q "codex exec resume --last"
}

@test "opcode/opencode: opencode run -c with no file claim" {
  run env -i HOME="$HOME_FIX" OPENCODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "opencode run -c"
  ! echo "$output" | grep -q "session file:"
}

@test "unknown harness: prints no-resume instructions, exit 0" {
  run env -i HOME="$HOME_FIX" bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "no verified headless resume path"
}

@test "stale transcripts (older than 6h) are ignored" {
  proj="$HOME_FIX/.claude/projects/-Users-fixture-repo"
  mkdir -p "$proj"
  old="$proj/33333333-3333-3333-3333-333333333333.jsonl"
  printf '{}' > "$old"
  touch -t "$(date -v-8H +%Y%m%d%H%M)" "$old" 2>/dev/null || touch -d "8 hours ago" "$old"
  run env -i HOME="$HOME_FIX" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "claude -c"   # falls back to continue-most-recent
  ! echo "$output" | grep -q "33333333"
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats tests/handoff-session-ref.bats`
Expected: FAIL — script does not exist.

- [ ] **Step 3: Implement `skills/handoff/scripts/session-ref.sh`**

```bash
#!/usr/bin/env bash
# session-ref.sh — detect the agent harness and resolve this session's
# reference: the absolute session/transcript path (when one exists) plus the
# verified resume command. Output is prose lines the handoff note embeds
# verbatim. Exit 0 always (an unresolvable reference is information, not an
# error). Hook-provided values win: set HANDOFF_SESSION_FILE (absolute path)
# and/or HANDOFF_SESSION_ID when the caller got them from hook stdin.
#
# Detection order (env markers, gstack's proven set):
#   Claude Code: CLAUDECODE            Codex: CODEX_THREAD_ID | CODEX_SANDBOX
#   OpenCode:    OPENCODE              anything else: unknown
set -u
HOME_DIR="${HOME:-$PWD}"

emit() { printf '%s\n' "$*"; }

# --- Claude Code ---------------------------------------------------------
if [ -n "${CLAUDECODE:-}" ]; then
  file="${HANDOFF_SESSION_FILE:-}"
  if [ -z "$file" ]; then
    # Project dirs munge the cwd path (/ -> -). Find candidate dirs by
    # basename suffix, then the newest transcript modified within 6h.
    # (find | xargs ls -t: this is not a hot path — it runs once per /handoff —
    # so clarity beats the statusline's fork discipline here.)
    cwd_name="$(basename "$PWD")"
    for d in "$HOME_DIR/.claude/projects"/*"$cwd_name"; do
      [ -d "$d" ] || continue
      f="$(find "$d" -maxdepth 1 -name '*.jsonl' -mmin -360 -print 2>/dev/null           | xargs ls -t 2>/dev/null | head -1 || true)"
      if [ -n "$f" ] && { [ -z "$file" ] || [ "$f" -nt "$file" ]; }; then
        file="$f"
      fi
    done
  fi
  if [ -n "$file" ] && [ -f "$file" ]; then
    sid="$(basename "$file" .jsonl)"
    emit "session file: $file"
    emit "resume: claude --resume $sid -p \"<prompt>\"   (resumes exactly this session)"
    emit "fallback: claude -c -p \"<prompt>\"   (most recent session in this directory)"
  else
    emit "session file: not found (no transcript modified in the last 6h)"
    emit "resume: claude -c -p \"<prompt>\"   (continue the most recent session here)"
  fi
  exit 0
fi

# --- Codex ----------------------------------------------------------------
if [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ]; then
  file="${HANDOFF_SESSION_FILE:-}"
  if [ -z "$file" ]; then
    file="$(find "$HOME_DIR/.codex/sessions" -name 'rollout-*.jsonl' -mmin -360 -print 2>/dev/null \
            | sort | tail -1)"
  fi
  if [ -n "$file" ] && [ -f "$file" ]; then
    emit "session file: $file"
    [ -n "${CODEX_THREAD_ID:-}" ] \
      && emit "current thread id: $CODEX_THREAD_ID (prefer resuming this thread if your codex supports it)" \
      || emit "caution: newest rollout may belong to another thread — verify before trusting it"
  else
    emit "session file: not found (no rollout modified in the last 6h)"
  fi
  emit "resume: codex exec resume --last \"<prompt>\""
  exit 0
fi

# --- OpenCode ---------------------------------------------------------------
if [ -n "${OPENCODE:-}" ]; then
  emit "resume: opencode run -c \"<prompt>\"   (continue the most recent session)"
  emit "note: no stable on-disk session path is published; handoff.md is the bridge"
  exit 0
fi

# --- Unknown / minimal harness --------------------------------------------
emit "harness: unrecognized — no verified headless resume path (do not guess one)"
emit "handoff.md is the only bridge: the successor session must rebuild state from it and git"
exit 0
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/handoff-session-ref.bats` — Expected: 6/6 PASS. (If the `find -nt` newest-selection is flaky in the loop, replace the inner loop with `ls -t "$d"/*.jsonl | head -1` under `-mmin` pre-filtering — keep it fork-light but correct; adjust test 1's sleep if needed.)

- [ ] **Step 5: Commit**

```bash
git add skills/handoff/scripts/session-ref.sh tests/handoff-session-ref.bats
git commit -m "handoff: session-ref.sh — deterministic harness detection and session-reference resolution (claude/codex/opencode/unknown, hook-override via HANDOFF_SESSION_FILE, 6h staleness window, verified resume commands per CLI mirroring quota-resilience); 6 bats tests over fixture HOME trees"
```

---

### Task 2: Bake-off materials — scenarios, variants, PREREG (commit before any spend)

**Files:**
- Create: `evals/handoff/_lib/scenarios/{mid-refactor,mid-experiment,mid-multibranch,mid-writing}.md`
- Create: `evals/handoff/_lib/variants/{A,B,C}.md`
- Create: `evals/reports/2026-10-06-handoff-PREREG.md`

- [ ] **Step 1: Write the four session digests** (realistic mid-task state a session would hand off; each ends with the raw facts the note must organize)

`evals/handoff/_lib/scenarios/mid-refactor.md`:

```markdown
You are 40+ turns into a session. State:

Task: extract a shared `parse_duration()` helper in a Rails app; three ad-hoc
parsers to replace (app/models/video.rb:12, app/services/caption.rb:48,
lib/import/subtitles.rb:9 — each parses "90s"/"1:30"/"h:mm:ss" differently).
Done: helper written at app/utils/duration_parser.rb with unit tests (12/12
green, commit 4f21ab9); video.rb migrated (commit 8c03de1, full suite green).
In flight: caption.rb migration started — new failing test written
(spec/services/caption_spec.rb:210) but NOT yet run red; the file's edit is
half-applied in the working tree (unstaged).
Not started: subtitles.rb; the deprecation sweep (grep for old callers); the
CHANGELOG entry.
User preferences stated mid-session: no monkey-patching; prefer presenters
over helpers for anything view-facing; commits must be one logical change
each.
Verification so far: bundle exec rspec spec/services/caption_spec.rb has not
been run since the test was written.
Write the handoff note now.
```

`mid-experiment.md`: an A/B eval mid-flight (baseline run done at 0.73, intervention applied to a skill file, change run NOT started, budget $19 of which $3.20 spent, PREREG committed at SHA a1b2c3d, abort condition $2.50/run).

`mid-multibranch.md`: three worktrees live (feature/export-api green and unmerged, fix/timeout-red at 2/3 tests, chore/deps untouched); base branch moved under one of them; the fast-forward failure and the rebase decision pending.

`mid-writing.md`: a long-form docs task (migration guide, 4 of 6 sections drafted in docs/migration.md uncommitted, one section's code sample known-stale against v2.3 API, reviewer feedback from the user: "less jargon, keep the tables", target file and TOC locked).

(Write all four as complete digests of the same shape as the sample above — the raw facts are fixed inputs, not prose the generator may embellish.)

- [ ] **Step 2: Write the three variants**

`variants/A.md` (Codex-minimal, verbatim buckets from `codex-rs/prompts/templates/compact/prompt.md`; every variant opens with the same file-less generation clause so `claude -p` stdout IS the artifact and no run touches the filesystem):

```markdown
Reply with the complete contents of the handoff note you would write — do
not create, modify, or read any files. You are performing a CONTEXT
CHECKPOINT: a handoff summary for another LLM that will resume the task.

Include:
- Current progress and key decisions made
- Important context, constraints, or user preferences
- What remains to be done (clear next steps)
- Any critical data, examples, or references needed to continue

Be concise, structured, and focused on helping the next LLM seamlessly
continue the work.
```

`variants/B.md` (superskills-structured; same opening generation clause as A):

```markdown
Reply with the complete contents of handoff.md — do not create, modify, or
read any files. The note is for the agent session that resumes this work.
Use exactly these sections:

# Handoff — <task one-liner> @ <date>
## Session — the session reference block session-ref.sh prints, verbatim
## Goal — one line: the task's definition of done
## Done — bullets, each with its commit hash or file:line
## In flight — file:line, what exists, what is missing, what is unverified
## Next steps — ordered; each executable without re-deriving context (exact
commands); the first one is the single next action
## Verify — the command(s) that prove the goal is met
## Do not redo — finished work the successor must not repeat, and known-dead
approaches already tried
## Context — decisions made; user preferences stated this session; pointers

Facts only from the session state you were given. No padding. The note is
committed-quality prose but the file stays uncommitted.
```

`variants/C.md` (= B with the reader-contract header and length discipline; same opening generation clause):

```markdown
Reply with the complete contents of handoff.md — do not create, modify, or
read any files. The reader is a fresh agent with NO
memory of this session: every line must be self-contained (no "as above",
no pronouns without antecedents), must build on work already done, and must
not duplicate finished work. Target 40-80 lines; a note longer than the
session state it summarizes has failed.

Then use exactly these sections:
<the full section list from variants/B, verbatim>
```

- [ ] **Step 3: Write and commit the PREREG** (before any paid run)

`evals/reports/2026-10-06-handoff-PREREG.md`:

```markdown
# PREREG — /handoff prompt bake-off (A vs B vs C)

Registered before any generation or eval run. Question: which handoff-note
prompt produces the note that best lets a fresh agent resume the work?

## Arms
- A — Codex-minimal four buckets (source: codex-rs compact prompt @062439b)
- B — superskills-structured sections + session block + do-not-redo
- C — B plus explicit reader-contract header + 40-80 line discipline

## Method
- Generation: 4 scenarios × 3 variants × 3 runs = 36 notes, via
  `claude -p` with variant prompt + digest (in-session-quality generation is
  the blessed non-routing use; routing is not under test).
- Layer 1 (judge): sonnet judge scores each note 0/0.5/1 on five dimensions
  (self-contained; next-step actionability with exact commands; session/env
  reference present; do-not-redo present; length discipline). Judge
  calibration first: 8 hand-labeled artifacts — good examples in BOTH the A
  shape and the B shape (so calibration cannot bake in B's section list),
  and planted single-flaw failures covering every dimension (dangling
  reference; commandless next step; missing session block; no do-not-redo;
  a note 3x the digest's length; a confidently WRONG next command). Adopt
  the judge only if ≥6/8 agree with labels. The two exec-case graders get
  their own calibration: 2 hand-labeled replies (one faithful run, one
  plausible-action substitution) must be scored correctly before use.
- Layer 2 (behavioral, decisive): 12 recall cases (4 scenarios × 3
  variants), each embedding that variant's r1 note verbatim as "the prior
  session's handoff.md", asking 5 resume questions; 5 llm graders (focus
  last_message) + 1 no-secrets grader. PLUS 3 execution cases (mid-refactor
  fixture repo; the fresh agent performs the note's named next action; 2
  graders: ran-the-named-action, honest-outcome). 3 runs/case, --ablation
  none, sonnet judge; exec-case failure (< 2/3) disqualifies a variant.

## Endpoints (fixed in advance)
- **Primary:** Layer-2 mean over the 5 resume-question graders, per variant
  (each variant evaluated on its r1 notes; note-level n=1 per scenario is a
  stated limit — judge-layer replication covers within-variant generation
  variance, not between-note selection).
- **Validity gate:** a variant failing its execution case (< 2/3 mean) is
  out regardless of recall.
- **Adopt the winner** if it beats the runner-up by ≥ +0.10 with no scenario
  regressing ≥ 0.34. Gap in (0.05, 0.10): extend the top two arms by +2
  runs/case on their recall cases (≤ $8; idempotent JSON naming) and
  re-decide at ≥ +0.10. Tie within 0.05 → higher Layer-1 sum → still tied →
  the simpler variant (A < B < C by complexity). **No arm clears any gate →
  ship variant B labeled "unproven default (house shape)"** — the skill needs
  a content model; the null is recorded, not hidden.
- **Negative control:** no-secrets grader must be 3/3 in every arm (a note
  that leaks tokens/keys fails its variant outright).
- Caps: generate.sh ≤ $1.50 per invocation; each plugin-eval command
  --max-cost-usd 8; total ≤ $55. Abort + report if any command hits its cap.
- Limits: single-judge design (calibrated, not multi-judge); generation and
  judging share the Claude account's rolling limits — runs may need to
  resume across a window reset (the driver script is idempotent per file).

## Post-experiment
The winner's text (A/B/C) becomes the Content Model section of
skills/handoff/SKILL.md, with the scores cited. Losers are archived in the
report, not shipped.
```

- [ ] **Step 4: Commit**

```bash
git add evals/handoff evals/reports/2026-10-06-handoff-PREREG.md
git commit -m "evals: pre-register the /handoff prompt bake-off (4 scenarios, variants A/B/C, two-layer eval with behavioral resume test, judge calibration, caps) before any paid run"
```

---

### Task 3: Generation driver (deterministic, idempotent)

**Files:**
- Create: `evals/handoff/_lib/generate.sh`

- [ ] **Step 1: Implement**

```bash
#!/usr/bin/env bash
# generate.sh — produce handoff notes for the bake-off. Idempotent: an
# existing output file is never regenerated (delete it to redo that cell).
# Cost: one `claude -p` call per missing cell; claude -p has no spend-cap
# flag, so the PREREG's abort rule governs: check reported spend after each
# batch. Re-verify `claude --help` still shows -p before first use (house rule).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${HANDOFF_GEN_OUT:-$ROOT/evals/results/handoff-gen}"
RUNS="${HANDOFF_GEN_RUNS:-3}"
mkdir -p "$OUT"

# Fixed session reference, embedded like-for-like in every cell so variants
# are compared on content, not on discovery luck. (Command substitution, not
# read -d '': read returns 1 at heredoc EOF and would kill set -e.)
REF_BLOCK="$(cat <<'REF'
SESSION-REF OUTPUT (embed in the note under its session section):
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"
REF
)"

for scenario in mid-refactor mid-experiment mid-multibranch mid-writing; do
  for variant in A B C; do
    for r in $(seq 1 "$RUNS"); do
      out="$OUT/$scenario-$variant-r$r.md"
      [ -s "$out" ] && continue
      tmp="$(mktemp)"
      { cat "$ROOT/evals/handoff/_lib/variants/$variant.md"; printf '\n\n'; \
        cat "$ROOT/evals/handoff/_lib/scenarios/$scenario.md"; printf '\n\n'; \
        printf '%s\n' "$REF_BLOCK"; } > "$tmp.prompt"
      claude -p "$(cat "$tmp.prompt")" > "$tmp" 2>/dev/null \
        || { rm -f "$tmp" "$tmp.prompt"; echo "gen failed: $scenario-$variant-r$r" >&2; exit 1; }
      rm -f "$tmp.prompt"
      mv "$tmp" "$out"
      echo "wrote $out"
    done
  done
done
```

- [ ] **Step 2: Smoke three cells (one per variant), then run all**

Run: `HANDOFF_GEN_RUNS=1 HANDOFF_GEN_OUT=/tmp/handoff-smoke bash evals/handoff/_lib/generate.sh` — 12 cells (4×3), inspected by hand (one per variant: a complete note, no file side-effects, the session block embedded). These smoke cells are throwaway (separate OUT); the full run then produces the 36 canonical cells. Total claude -p calls: 12 + 36 + judge calls — claude -p exposes no per-call cap, which is a DISCLOSED deviation from the capped-command rule: the control is the call count (fixed by the driver's idempotent cell list) plus a spend check after each batch; abort on any anomaly. Expected: 36 files in `evals/results/handoff-gen/`.

- [ ] **Step 3: Commit (driver only; results are git-ignored)**

```bash
git add evals/handoff/_lib/generate.sh
git commit -m "handoff eval: idempotent generation driver — 4×3×3 claude -p cells, fixed session-ref block embedded like-for-like, per-cell skip on existing output"
```

---

### Task 4: Layer-1 judge + calibration

**Files:**
- Create: `evals/handoff/_lib/judge.sh`
- Create: `evals/handoff/_lib/calibration/{good1..good3,bad1..bad3}.md` + `labels.tsv`

- [ ] **Step 1: Write 6 calibration artifacts by hand** — three genuinely good notes (use the B shape over the mid-refactor digest) and three flawed ones with exactly one planted flaw each: (bad1) references "the section above" (not self-contained); (bad2) next step says "continue the migration" with no command; (bad3) omits the session reference entirely. `labels.tsv`: filename, expected per-dimension verdicts.

- [ ] **Step 2: Implement `judge.sh`** — for each input note, one sonnet `claude -p --model sonnet` call returning strict JSON `{"self_contained":0|0.5|1,"actionable":…,"session_ref":…,"no_redo":…,"discipline":…}` plus a one-line justification; `jq` validates; results append to `evals/results/handoff-judge.tsv`. Calibration mode (`--calibrate`) runs the 6 labeled artifacts and prints agreement (adopt judge at ≥5/6, else STOP and rewrite the judge prompt — the PREREG's rule).

- [ ] **Step 3: Calibrate, then judge all 36**

Run: `bash evals/handoff/_lib/judge.sh --calibrate` → expect ≥5/6. Then `bash evals/handoff/_lib/judge.sh` over the 36 generated notes; commit the driver, record the TSV path.

- [ ] **Step 4: Commit**

```bash
git add evals/handoff/_lib/judge.sh evals/handoff/_lib/calibration
git commit -m "handoff eval: layer-1 judge — 5 dimensions, strict-JSON sonnet output, 6 hand-labeled calibration pairs with ≥5/6 adoption gate"
```

---

### Task 5: Layer-2 behavioral cases (generated from template)

**Files:**
- Create: `evals/handoff/_lib/make-cases.sh`, `evals/handoff/_lib/handoff-resume-fixture.sh`
- Create (by the script): `evals/handoff-resume-{scenario}-{variant}/` × 12 recall cases + `evals/handoff-exec-{variant}/` × 3 execution cases

- [ ] **Step 1: Implement `make-cases.sh`** — for each scenario×variant, embed the **r1 artifact for every variant** (fixed in the script; using a different run-index per variant would confound variant with generation noise — r2/r3 stay as judge-scored replicas at Layer 1 only, and the note-level n=1-per-scenario limit is disclosed in the PREREG), and write a case dir with:

`prompt.md` (frontmatter `max_turns: 4`, `timeout_seconds: 300`, `allowed_tools: [Read, Glob, Grep, Write, Skill]`, tags `[handoff, resume, <variant>]`; single glob limitation means one case per command):

```
You are a fresh agent with no memory of any prior session. Below is the
handoff.md the previous session left for you. Read it and answer, in your
reply, each of these five questions with specifics:
1. What is the task's definition of done, and what proves it?
2. What is already finished (with its commit hashes / file:line)?
3. What is the single next action, as an exact command?
4. What must you NOT redo, and which known-dead approaches were tried?
5. How would you resume the original session (harness + exact command)?

--- handoff.md (verbatim) ---
<the generated note's full text>
--- end handoff.md ---
```

`graders/` — five llm graders (`focus: last_message`, `arm: both`), one per question, each PASS iff the answer is specific and correct **and derived from the note** (question 3 requires an exact runnable command present in or faithful to the note; question 5 requires the claude --resume line with the fixture session id); plus `no-secrets.md` (PASS iff no token/key/credential appears in the reply or is asked for) and `skill-fired` is deliberately absent (no skill should fire; routing is not under test).

- [ ] **Step 2: Generate the 12 recall case dirs, spot-check one, commit**

Run: `bash evals/handoff/_lib/make-cases.sh` → 12 dirs. Read one prompt end-to-end (the embedded note must be intact, fences escaped if the note contains ``` — the script replaces ``` inside the artifact with ~~~ before embedding and the graders are told nothing about it).

```bash
git add evals/handoff/_lib/make-cases.sh evals/handoff-resume-*
git commit -m "handoff eval: 12 recall cases + 3 execution cases generated from the baked-off notes — 5 resume-question graders + no-secrets control; every variant evaluated on its r1 note (no run-index confound)"
```

- [ ] **Step 3: The execution cases (validity core — recall alone cannot crown a winner)** — `handoff-resume-fixture.sh` builds a fixture repo matching the mid-refactor digest exactly (app/utils/duration_parser.rb + migrated video.rb committed; caption.rb half-edited unstaged; the new failing caption spec present; subtitles.rb untouched), each `handoff-exec-<variant>` case wires it via `case.yaml` + `fixture.sh` (the doctor convention), the prompt embeds the variant's r1 note verbatim plus: "You are the fresh agent this note was written for. Execute the single next action it names, then report exactly what happened." Graders: `ran-the-named-action` (llm: the reply shows evidence of running/attempting the exact command the note named — not a different plausible action) and `honest-outcome` (llm: the report states the actual observed result, including failure, rather than claiming success). 3 runs × 3 variants = 9 runs, `--scaffold --allow-tools Bash`, cap $8 per command. **A variant whose exec-case mean is < 2/3 cannot be adopted regardless of its recall score** — that is the preregistered validity gate.

- [ ] **Step 4: Run Layer 2** — 15 commands (one per case; single-glob limitation), each:

```bash
claude plugin eval . --case handoff-resume-<scenario>-<variant> --runs 3 --ablation none \
  --trust-plugin --no-publish --allow-tools Bash --judge-model sonnet \
  --max-cost-usd 8 --json evals/results/handoff-l2-<scenario>-<variant>.json
```

(Recall cases need no fixture repo — omit `--scaffold` for those; the three exec cases use `--scaffold`.)

---

### Task 6: Analysis, winner adoption, report

- [ ] **Step 1: Compute per-variant Layer-2 means** (5 graders × 3 runs × 4 scenarios, per-grader pass-rate then averaged, the Experiment-A arithmetic), Layer-1 sums, and the no-secrets control; apply the PREREG decision rule verbatim; write `evals/reports/2026-10-06-handoff-bakeoff.md` with the full table, the decision, and both layers' evidence.
- [ ] **Step 2: Commit**

```bash
git add evals/reports/2026-10-06-handoff-bakeoff.md
git commit -m "evals: /handoff prompt bake-off results — <WINNER: variant X, primary Δ +Y.YYY over runner-up, no-secrets 3/3 all arms>; losers archived in-report; winner's text ships as the skill's content model"
```

---

### Task 7: Auto-trigger hook (TDD)

**Files:**
- Create: `scripts/handoff-trigger-hook.sh`
- Modify: `hooks/hooks.json`
- Test: `tests/handoff-trigger-hook.bats`

- [ ] **Step 1: Write the failing tests** — fixture stdin JSON `{"hook_event_name":"UserPromptSubmit","session_id":"abc","transcript_path":"/t/p.jsonl","cwd":"/r"}` and a fixture `XDG_CACHE_HOME` cache at the REAL persisted shape `{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":"2026-10-06T20:00:00Z"},"seven_day":{"used_percentage":41,"resets_at":"2026-10-09T12:00:00Z"}}}` (the statusline's second jq record — windows nest under `rate_limits`, and `used_percentage` may be fractional):
  (a) expect exit 0 and stdout JSON where `.hookSpecificOutput.hookEventName == "UserPromptSubmit"` and `.hookSpecificOutput.additionalContext` contains "/handoff", "p.jsonl", and "abc";
  (b) all windows below threshold (62/41) → empty stdout;
  (c) 93 but marker file `handoff-notified-abc` containing `2026-10-06T20:00:00Z` (same window) → empty stdout;
  (d) marker contains a DIFFERENT resets_at (new window) → fires again and rewrites the marker;
  (e) fractional percentage 92.7 ≥ 90 → fires;
  (f) unreadable/garbage/missing cache → exit 0, no output (never break the prompt path);
  (g) `HANDOFF_USAGE_THRESHOLD=95` at 93 → no output; (h) empty stdin → exit 0, no output.

- [ ] **Step 2: Run to verify they fail** — `bats tests/handoff-trigger-hook.bats` → FAIL (no script).

- [ ] **Step 3: Implement** `scripts/handoff-trigger-hook.sh`:

```bash
#!/usr/bin/env bash
# handoff-trigger-hook.sh — Claude Code hook (UserPromptSubmit). Emits ONE
# additionalContext nudge to run /handoff when account usage (the statusline's
# rate-limit cache) crosses HANDOFF_USAGE_THRESHOLD (default 90). Re-arms once
# per new rate-limit window (the marker stores the firing window's resets_at).
# Never fails the prompt path: any parse problem → silent exit 0.
set -u
input="$(cat 2>/dev/null || true)"
[ -n "$input" ] || exit 0
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
[ -n "$session_id" ] || exit 0

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
CACHE="$CACHE_DIR/rate-limits.json"
MARKER="$CACHE_DIR/handoff-notified-$session_id"

# Cache shape (statusline.sh, second jq record):
#   {"rate_limits":{"five_hour":{"used_percentage":N,"resets_at":ISO},...}}
# Highest pressure across live windows wins; jq does the float-safe compare
# and returns the firing window's resets_at for the marker.
verdict="$(jq -r --arg t "${HANDOFF_USAGE_THRESHOLD:-90}" '
  [.rate_limits[]?.used_percentage // 0] as $p
  | if ($p | max) >= ($t | tonumber)
    then "1 " + ([.rate_limits[]? | select(.used_percentage == ($p | max))
                  | (.resets_at // "")][0] // "")
    else "0 " end' "$CACHE" 2>/dev/null || echo '0 ')"
fire="${verdict%% *}"
resets_at="${verdict#* }"
[ "$fire" = "1" ] || exit 0
[ -e "$MARKER" ] && [ "$(cat "$MARKER" 2>/dev/null)" = "$resets_at" ] && exit 0

jq -n --arg ctx "Session usage is at or above ${HANDOFF_USAGE_THRESHOLD:-90}%. Run the /handoff skill NOW, before doing anything else: it writes handoff.md (in-progress state, exact next steps, and this session's reference) so a fresh session can resume cheaply. Session reference for the note: transcript_path=${transcript}; session_id=${session_id}. After /handoff completes, continue the user's task." \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
printf '%s' "$resets_at" > "$MARKER" 2>/dev/null || true
exit 0
```

- [ ] **Step 4: Wire `hooks/hooks.json`** — add to the `hooks` object:

```json
"UserPromptSubmit": [
  { "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/handoff-trigger-hook.sh\"" } ] }
]
```

- [ ] **Step 5: Run tests** — `bats tests/handoff-trigger-hook.bats` → 6/6 PASS; full `./tests/run.sh` green.
- [ ] **Step 6: Commit**

```bash
git add scripts/handoff-trigger-hook.sh hooks/hooks.json tests/handoff-trigger-hook.bats
git commit -m "handoff: auto-trigger hook — UserPromptSubmit reads the statusline's rate-limit cache (no new tracking) and nudges /handoff once per session at >=90% (HANDOFF_USAGE_THRESHOLD overridable); additionalContext correctly nested with hookEventName (top-level is silently dropped by the host); any parse failure degrades to silent exit 0; PreCompact deliberately unwired (its additionalContext is compaction instructions, not an agent nudge)"
```

---

### Task 8: The skill itself + composition

**Files:**
- Create: `skills/handoff/SKILL.md`
- Modify: `skills/quota-resilience/SKILL.md` (one line), `.gitignore`

- [ ] **Step 1: Write `skills/handoff/SKILL.md`** — frontmatter (`name: handoff`, `version: 1.0.0`, description for triggering: manual invocation, high-usage/pre-compaction moments, "write a handoff", "session limit", "context almost full", "before compaction"; allowed-tools Read/Glob/Grep/Bash/Write). Body sections:
  1. **When**: manual; or after the auto-trigger nudge.
  2. **Gather the session reference**: run `bash skills/handoff/scripts/session-ref.sh` (path is `${CLAUDE_PLUGIN_ROOT}/skills/handoff/scripts/session-ref.sh` in plugin installs — the skill says: run the session-ref script from this skill's directory); if the nudge provided transcript_path/session_id, export them as `HANDOFF_SESSION_FILE`/`HANDOFF_SESSION_ID` first so they win over discovery.
  3. **Content model** — the eval-winning variant's text, verbatim, in a fenced block, prefaced by "This shape won the 2026-10-06 bake-off (evals/reports/2026-10-06-handoff-bakeoff.md); edit deliberately."
  4. **Write** `handoff.md` at the repo root. Uncommitted by design (gitignored).
  5. **Composition**: on the quota hard stop, `/quota-resilience` folds handoff.md into QUOTA-RESUME.md and deletes it; do not leave both.
  6. **Portability note**: the six-token host-neutral rule applies; the skill names no host-exclusive tools (verified by the existing lint).
- [ ] **Step 2: Composition line in quota-resilience** — in Phase 1 step 3, after "Write the resume note": "If `handoff.md` exists (written by `/handoff` before the stop), fold its content into this note and delete the file — one bridge, not two."
- [ ] **Step 3: `.gitignore`** — append `handoff.md` with a comment line.
- [ ] **Step 4: Parity + lint checks** — `bats tests/skills-host-neutral.bats` (new skill body is token-clean); assert the skill and quota-resilience both contain `claude --resume` and `codex exec resume --last` — add `tests/handoff-parity.bats` with exactly that grep pair.

- [ ] **Step 5: Live smoke** — invoke `/handoff` once in this repo (manually, in-session): it must produce a repo-root `handoff.md` whose Session section carries a real transcript path and resume command (or the honest not-found fallback). Inspect the file; delete it after. This is the critical-path verification the Test Plan requires.

- [ ] **Step 6: Commit**

```bash
git add skills/handoff/SKILL.md skills/quota-resilience/SKILL.md .gitignore tests/handoff-parity.bats
git commit -m "handoff: /handoff skill 1.0.0 — manual + auto-triggered handoff.md with eval-winning content model (<variant>, primary <Δ>), session-ref embedding, quota-resilience composition rule (fold-and-delete), host-neutral body"
```

---

### Task 9: Public repo export (humanize pattern)

**Files:**
- Create: `scripts/export-handoff.sh`, `scripts/handoff-dist/README.md`, `scripts/handoff-dist/.gitignore`
- Test: `tests/handoff-export.bats`

- [ ] **Step 1: Write `scripts/handoff-dist/README.md`** — standalone-repo README: what /handoff is, install (copy SKILL.md + scripts/ into a skills dir; or the superskills plugin), the two trigger modes INCLUDING the auto-trigger's prerequisites and wiring for standalone users (copy `hooks/handoff-trigger-hook.sh`, add the UserPromptSubmit entry to settings/hooks config, and note it reads the statusline cache — without superskills' statusline installed there is no cache and the auto-trigger is inert; manual /handoff always works), the harness support matrix, provenance ("canonical in ariadoss/superskills; exported — file issues there"), license note pointing at NOTICE.
- [ ] **Step 2: Write `export-handoff.sh`** — mirror `export-humanize.sh` in structure: SRC `skills/handoff`, OUT `dist/handoff` (refuse overlap via `export-lib.sh`), copy `SKILL.md`; relocate `skills/handoff/scripts/session-ref.sh` → `scripts/session-ref.sh` in OUT; also ship `hooks/handoff-trigger-hook.sh` (copied from `scripts/`, unchanged — the dual-path bats lookup covers both layouts); copy `tests/handoff-session-ref.bats` → `tests/`, `LICENSE`, a `NOTICE.md` (one provenance line), README/.gitignore from `scripts/handoff-dist/`; allowlist + refuse symlinks + warn on untracked, exactly the humanize rules; then self-verify: `bats "$OUT/tests/handoff-session-ref.bats"` must pass or the export refuses to declare itself publishable.
- [ ] **Step 3: `tests/handoff-export.bats`** — run the export into `$BATS_TEST_TMPDIR`, assert SKILL.md/session-ref/README/LICENSE exist, assert the self-test ran (grep the script's success line), assert a planted untracked file in the skill dir does NOT ship.
- [ ] **Step 4: Verify the export and create the public repo (push deferred to Task 10)**

```bash
bash scripts/export-handoff.sh /tmp/handoff-export-check   # self-verifies incl. bats
gh repo create ariadoss/handoff --public --description "Cross-harness /handoff skill: session-limit-aware handoff.md for coding agents" 2>&1 | tail -1
```

(If `gh` is unauthenticated, stop and report — repo creation is the one step needing the user. The first push happens in Task 10 Step 3, AFTER final validation: publish nothing the suite has not blessed.)

- [ ] **Step 5: Commit**

```bash
git add scripts/export-handoff.sh scripts/handoff-dist tests/handoff-export.bats
git commit -m "handoff: public-repo export — humanize pattern (pure copy, git allowlist, self-verifying bats in the exported tree); ariadoss/handoff is the publish target, superskills stays canonical"
```

---

### Task 10: Ship

- [ ] **Step 1**: `./tests/run.sh` green on final HEAD; `claude plugin validate .` (non-strict, accepted-warning contract) passes; `./setup` re-run (new skill must link).
- [ ] **Step 2**: VERSION 2.37.0 → 2.38.0; `./scripts/sync-version.sh`; README skills list gains `/handoff` (one line in the skills table, matching humanize's row shape); one release commit.

- [ ] **Step 3: Publish the public repo (validation green)**

```bash
bash scripts/export-handoff.sh
git -C dist/handoff init -q 2>/dev/null || true
git -C dist/handoff add -A
git -C dist/handoff commit -qm "handoff 1.0.0 — exported from ariadoss/superskills (canonical)"
git -C dist/handoff remote add origin git@github.com:ariadoss/handoff.git 2>/dev/null || true
git -C dist/handoff branch -M main
git -C dist/handoff push -u origin main
```

- [ ] **Step 4: Push superskills main.**

```bash
git add VERSION README.md .claude-plugin .codex-plugin .cursor-plugin
git commit -m "release 2.38.0 — /handoff: cross-harness session handoff (manual + >=90% usage auto-trigger via the statusline cache), eval-winning note prompt (<variant>, <Δ>), session-ref detection for claude/codex/opencode/unknown, quota-resilience composition, exported to ariadoss/handoff"
```

---

## Test Plan & Verification

**Coverage target:** 100% of new deterministic code paths bats-tested — session-ref (6 tests: claude newest/override/stale, codex, opencode, unknown), trigger hook (7 tests: fire/nested-shape, below-threshold, marker suppression, per-window marker expiry, garbage-cache degradation, threshold override, empty stdin), export (4 assertions incl. untracked-refusal), parity (resume-command grep pair). Every behavioral claim (which prompt wins, no-secrets) backed by the PREREG'd two-layer eval with pre-registered gates actually executed.

**Critical paths (must pass before ship):**
- Manual flow: `/handoff` → session-ref resolves → handoff.md written with the reference block → verified by Layer-2 eval design + a live smoke (run /handoff once in this repo; inspect the file).
- Auto flow: fixture cache ≥90% → hook emits correctly-nested additionalContext once → suppressed thereafter → bats tests 7a-c.
- Export: `bash scripts/export-handoff.sh` self-verifies in a clean tree → bats green inside `dist/handoff`.

**Edge cases & error paths:** garbage/missing rate-limit cache → silent exit 0 (hook never breaks the prompt); unknown harness → informative no-resume instructions, exit 0; stale transcripts (>6h) ignored → fallback `claude -c`; handoff.md already exists → the skill overwrites it (it is a snapshot, not an archive); note containing triple backticks → escaped as ~~~ on embed.

**Regression guards:** quota-resilience behavior unchanged except the one composition line (its eval cases still pass); skills-host-neutral lint covers the new SKILL.md; full suite green at every task boundary.

**Verification commands:** `bats tests/handoff-session-ref.bats tests/handoff-trigger-hook.bats tests/handoff-export.bats tests/handoff-parity.bats` — all pass; `./tests/run.sh` — all pass; Layer-2 eval commands as in Task 5 with per-command `--max-cost-usd 8`.

**Acceptance criteria (from spec):**
- [ ] "Evaluation to figure out which prompt is best" → Tasks 2–6, pre-registered, winner cited in the skill
- [ ] "Auto trigger above 90%" → Task 7 (statusline cache reuse, threshold env)
- [ ] "Manual trigger" → Task 8 (skill invocation)
- [ ] "Own public repo like humanize" → Task 9 (ariadoss/handoff, self-verifying export)
- [ ] "Session limits tracked by statusline code" → Task 7 reads `claude-statusline/rate-limits.json`, no new tracking

## GSTACK REVIEW REPORT

Target: docs/superpowers/plans/2026-10-06-handoff-skill.md (plan review, /write-plan chain)
Date: 2026-10-06 · Reviewer: ZCode session (claude-family) + codex adversarial pass · Scope Challenge: complexity gate tripped (~20 files); structure kept at original arrangement — the user's request fixes the scope (skill + eval + hook + export are one vertical slice; the export is inert until Task 10 blesses it).

| Review | Trigger | Why | Runs | Status | Findings |
|---|---|---|---|---|---|
| Self-review | plan completeness | placeholders, consistency | 2 passes | FOLDED | generate.sh placeholder call + set -e heredoc bug fixed; Layer-2 run-index confound fixed (fixed r1 per variant); session-ref newest-file precedence bug fixed; live-smoke step added |
| Scope/Architecture | hook + eval + export design | boundaries, sequencing | read-only | FOLDED | PreCompact removed everywhere (its additionalContext is compaction instructions, not an agent nudge — category error); publication moved after final validation |
| Test review | bats + eval soundness | coverage, validity | read-only | FOLDED | Task-1 tests fixed to match the discovery algorithm (cd into matching dir; override file must exist); dual-path script lookup for the exported layout; 8-artifact cross-shape judge calibration; exec-case grader calibration |
| codex adversarial | independent second opinion | attack validity | 1 (read-only) | COMPLETED — 9 findings, all verified against tree and folded | cache-shape blocker (rate_limits.five_hour/… nesting) fixed in hook + tests; marker now per-window (resets_at-stored, re-arms on new window); account-wide multi-session collision documented via written-by header; session-ref binds the exact munged cwd with basename-fallback caution + codex thread caution; execution cases added as the validity gate (recall alone cannot crown); gate-gap rule + no-winner default (B labeled unproven) added; generation made file-less (stdout IS the artifact, no filesystem side-effects; smoke cells disclosed as separate OUT); export ships hook + NOTICE, relocates script with dual-path tests, push deferred to post-validation |

VERDICT: PASS AFTER REVISION — plan is executable as written; the bake-off carries a preregistered validity gate (execution cases) in addition to its adopt gates; deterministic pieces (session-ref, hook, export) are TDD'd; total planned spend $40–62 with disclosed deviations (claude -p call-count control) recorded in the PREREG.

OUTSIDE COVERAGE: codex (read-only sandbox, full plan reviewed).

NO UNRESOLVED DECISIONS
