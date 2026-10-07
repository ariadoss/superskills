# Context-Map Skill Utility — Eval-Gated Measurement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure whether running `/repomap` and `/dbmap` before a task — or merely having their map artifacts present — measurably improves agent task performance (correct files touched, fewer exploration turns) over a cold start, under `claude plugin eval` with pre-registered arms and adopt/reject thresholds.

**Architecture:** Two independent single-intervention experiments (repomap, then dbmap), each a three-arm A/B/C on a purpose-built navigation-bound fixture: A = cold task, B = "run the skill first, then the task" (the real-world question), C = same map artifact pre-generated in the fixture, no skill call (isolates the map's content value from skill-call overhead). No skill bodies change; this plan produces measurements, PREREGs, and verdicts. graphify is scoped out (its flagship output is human-facing HTML; no agent-side consumer exists — YAGNI).

**Tech Stack:** `claude plugin eval` (sonnet judge), sqlite3 + python3 stdlib fixtures, bats, the already-installed `~/claude-repomap-command` toolchain + `tbls`.

---

## Research grounding (done before this plan — do not re-derive)

- **No prior evidence exists.** `grep -rln 'repomap\|dbmap\|graphify' evals/` finds only a 2026-09-16 manifest fix and the claw-code rejection row. Nobody has measured utility; this plan is the first.
- **dbmap mechanics** (`skills/dbmap/SKILL.md`): shells out to `<REPOMAP_DIR>/scripts/run.sh dbmap --dsn … -o DBMAP.md` (tbls underneath), detects DSNs from `.env` etc., **asks the user which connection** — headless eval runs must steer past that with a prompt line naming the single connection. Writes DBMAP.md + an agent-authored `## Index Analysis` section.
- **repomap mechanics** (`skills/repomap/SKILL.md`): `<REPOMAP_DIR>/scripts/run.sh repomap -o REPOMAP.md`; non-interactive; tree-sitter based.
- **Toolchain verified installed 2026-10-06**: `~/claude-repomap-command/scripts/run.sh` exists, `tbls` at `/opt/homebrew/bin/tbls`, `sqlite3` and `python3` on PATH. If any is missing at execution time, the missing piece is the blocker to report, not to silently work around.
- **Contamination lesson (2026-10-06, round 2)**: a sibling worktree registered as a second superskills plugin made the `--case` glob run BOTH roots' copies and corrupted attribution. **Every run command in this plan is preceded by a single-plugin check** (Step: parse `suite.plugins` from the produced JSON; exactly one entry, path == this repo, before any number is read). If two roots appear, STOP and report — the numbers are unreadable until the second registration is removed.
- **Harness facts**: `--case` takes ONE name glob (a second `--case` overrides the first); run records carry `turns` and `durationSeconds` (the exploration-cost metrics — parsed from JSON, no grader needed); llm graders score `last_message`; `--ablation none` means with-plugin only, NOT plugin-less.
- **Cost model**: task runs are read-heavy small-edit runs, measured $0.3–1.0 each in this suite; judges add ~30%. Caps sized so each experiment's worst case ≈ $12.

## The measurement design (identical skeleton for both experiments)

**Arms** (tree states differ only as stated; same day, sequential A → B → C per experiment):

- **A (cold):** fixture + plain task prompt.
- **B (skill-first):** fixture + task prompt preceded by one instruction line: `Start by running /<skill> to orient yourself, then do the task below.` — the intervention is the skill invocation itself.
- **C (map pre-injected):** fixture + the map artifact (REPOMAP.md / DBMAP.md) already committed in the fixture repo + the SAME plain prompt as A. The artifact is generated once by the executor before any run (deterministic content for every C run). No instruction mentions it — the agent must discover it, which is exactly the "would this file help if it existed" question.

**Readings (plan-eng-review findings 6+9):** primary = mean of the case's task-correctness llm graders CROSS-CHECKED against the tool_used edit-proof graders (a claim without its edit-proof fails; an edit the reply omits fails no-wrong-edits only if unrelated); secondary (reported, descriptive, never gated) = per-arm `turns` and `durationSeconds` means PLUS exploration-action counts (Read/Grep/Glob calls) from the archived traces, with per-arm truncation accounting (runs at `partial: true`, non-null `error`, or turns == max_turns are reported as truncated and excluded from secondary means, never silently dropped); indicator = skill-fired (arm B only). Every run command carries `--keep-temp`, and after each command run `scripts/eval-traces.sh` to archive transcripts next to the results before the temp dir evaporates. Traces also carry the leakage probe: any Read/Glob of paths OUTSIDE ./fixture-repo (e.g. ../.. reaching the case dir's committed map or graders) is reported per arm as contamination.

**Verdicts the design can separate (fixed in both PREREGs):**

| Outcome | Reading |
|---|---|
| B > A and C ≈ B | skill-first helps; the map is the active ingredient → "run it first" guidance is justified |
| C > A but B ≈ A | the map content helps but the skill call's overhead eats it → prefer pre-generated maps (e.g. the CLAUDE.md rule dbmap already offers), not on-demand runs |
| B > A and B > C | freshness/authoring matters beyond the artifact (unlikely here) |
| B ≡ A ≡ C | no measurable utility at this fixture scale — a real null |

**Gates (pilot framing — plan-eng-review finding 8):** n=3 × 2 binary graders means one changed vote moves the primary by 0.167, so this is a PILOT, not a rate estimate. |Δ| < 0.34 on the primary = "no signal at this scale" (never worded as a proven null); Δ ≥ +0.34 with no grader regressing ≥ 0.34 = signal, which licenses ONE optional confirmatory n=5 re-run of the winning comparison before any guidance sentence is written; skill-fired ≥ 2/3 in arm B else arm B is under-powered (A/C readings still report). Nothing ships into skill bodies regardless — outcomes are guidance (reports + documented follow-ups), so no VERSION bump rides this plan. METHODOLOGY.md's small-count caveat is cited in both reports.

**Cost governance (plan-eng-review finding 11):** per-command cap `--max-cost-usd 4` (six commands ⇒ hard ceiling $24 ≤ the $25 plan total); per-experiment budget $12 enforced CUMULATIVELY — before each command, sum `costUsd` across that experiment's existing result JSONs and skip to the report if the budget is spent; a limit-error mid-experiment halts that experiment (runs already paid for are analyzed; missing arms are reported as such, never imputed). The Task-0 Step-4 pilot is the single-run calibration: if it exceeds $2, arm B's economics are the finding.

---

## File Structure

| File | Responsibility | Create/Modify |
|---|---|---|
| `evals/_lib/nav-fixture.sh` | Builds the repomap experiment's multi-module fixture repo (30 files, cross-module references, a deliberately scattered feature). One function, subshell-isolated (the review-fixture convention). | Create |
| `evals/_lib/db-fixture.sh` | Builds the dbmap experiment's fixture: sqlite DB (8 tables, FKs, one un-indexed FK, a query-pattern trap) + a small raw-SQL python app + `.env` with the DSN. | Create |
| `tests/nav-fixture.bats`, `tests/db-fixture.bats` | Unit tests: fixtures build, expected files/tables exist, idempotent, cwd-isolated (the `review-fixture.bats` pattern). | Create |
| `evals/repomap-nav-task/`, `evals/dbmap-schema-task/` | The two cases: `prompt.md` + `graders/` (+ `case.yaml`/`fixture.sh` wiring for dbmap's scaffold; repomap's case needs no scaffold beyond the fixture build — same wiring, simplest uniform). | Create |
| `evals/reports/$(date +%F)-repomap-utility-PREREG.md`, `…-dbmap-utility-PREREG.md` | Pre-registrations, committed before any run of their cases. | Create |
| `evals/reports/$(date +%F)-repomap-utility.md`, `…-dbmap-utility.md` | Results + verdict tables. | Create |
| `evals/reports/$(date +%F)-context-maps-consolidated.md` | Both verdicts + the graphify scope-out note + follow-up candidates. | Create |

DRY: both experiments share the arm structure, gates, single-plugin check, and analysis recipe (one documented skeleton, repeated PREREG-by-PREREG — deliberate: PREREGs are self-contained legal documents, precedent from the codex-adoption plan); fixture libs reuse the `*_fixture` subshell convention from `evals/_lib/review-fixture.sh` rather than inventing a new shape.
SOLID: each fixture lib has one responsibility (build one repo shape); the analysis is a pure JSON→table step with no fixture knowledge.
YAGNI: no new harness code, no graphify consumer, no CLAUDE.md auto-rule task (that is a *candidate follow-up* the verdicts may justify, not this plan).

**Security & threat model:** crosses no trust boundary — fixtures are local synthetic repos, a local sqlite file, and the already-installed local toolchain; the DSN is a fixture path, not a credential. No `/cso` pass needed (stated per the plan checklist).

---

## Context for executors (zero-context assumption)

- This repo IS superskills (markdown skills + bash/bats + evals). Read `evals/README.md` before running anything paid. Suite: `./tests/run.sh` (662 tests at plan time). Judge model stays `sonnet`. Never push mid-experiment; commits land per task.
- Eval command shape (ONE case per invocation — the second `--case` overrides the first):
  `claude plugin eval . --case <name> --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 4 --keep-temp --json evals/results/<out>.json && scripts/eval-traces.sh`
- **Single-plugin check (mandatory before reading any number):**
  `python3 -c "import json;d=json.load(open('<out>.json'));ps=[(p['name'],p['path']) for p in d['suite']['plugins']];print(ps);assert len(ps)==1 and ps[0][1].endswith('/superskills') and 'worktrees' not in ps[0][1], 'CONTAMINATED — stop'"`
- Arm B and C differ by tree state AND (B only) one prompt line — that is the intervention, not a confound; both PREREGs state it (and B−A is a POLICY effect — "told to run the skill first" — while C−A is an ambient-file effect; the verdict table's claims are narrowed accordingly, per plan-eng-review finding 5).
- **Leakage boundary (plan-eng-review finding 2):** the C artifact and the graders live in the case dir inside the plugin repo, and a determined agent reading ../../ could reach them. The prompt anchors all work to ./fixture-repo, and the traces probe reports any out-of-fixture read per arm; a C or A run that reads the case dir's map is contamination and its arm's reading is flagged. This is the harness's structural limit (the doctor cases accept the same), disclosed in both reports rather than solved.
- `evals/results/` is git-ignored by design; numbers get committed inside the reports.

---

### Task 0: Pre-flight (verification only, zero spend)

**Files:** none created; produces evidence recorded in Task 1/2 PREREGs.

- [ ] **Step 1: Verify the toolchain**

Run: `ls ~/claude-repomap-command/scripts/run.sh && which tbls && which sqlite3`
Expected: all three present (verified 2026-10-06). Any miss = BLOCKED, report; do not invent substitutes.

- [ ] **Step 2: Pre-spend contamination check (FREE — before any paid run)**

Run: `claude plugin list`
Expected: exactly ONE superskills entry, pointing at this repo (not a worktree). If two appear, the sibling registration is still live — STOP and report; every number this plan would produce is unreadable until it is removed. Repeat this check before each experiment's first paid command; after each run, also assert `suite.plugins` in the produced JSON (the executor-context snippet).

- [ ] **Step 3: Host-side toolchain smoke**

```bash
T=$(mktemp -d) && cd "$T" && git init -q .
printf 'def add(a, b):\n    return a + b\n' > calc.py
printf 'import calc\nprint(calc.add(1, 2))\n' > main.py
git add -A && git commit -qm init
~/claude-repomap-command/scripts/run.sh repomap -o REPOMAP.md && head -5 REPOMAP.md
printf 'CREATE TABLE t (id INTEGER PRIMARY KEY, u INTEGER REFERENCES users(id));\n' | sqlite3 app.db
printf 'DATABASE_URL=sqlite://%s/app.db\n' "$PWD" > .env
~/claude-repomap-command/scripts/run.sh dbmap --list && tbls doc sqlite://"$PWD"/app.db -f && ls dbdoc/
cd / && rm -rf "$T"
```
Expected: REPOMAP.md lists calc.py/main.py; dbmap `--list` prints the sqlite DSN; `tbls doc` emits schema docs. Record output tails in the eventual reports. If `dbmap --list` needs a different env key, adapt the fixture's `.env` to whatever it detects (say so in the report).

- [ ] **Step 4: IN-HARNESS toolchain pilot (the $HOME problem — plan-eng-review finding 1)**

`evals/RUBRIC.md` Known limits: sandboxed runs cannot read `$HOME`, and both skills search `$HOME` paths for the toolchain — arm B as originally designed would die on toolchain lookup. Both skills honor `$REPOMAP_HOME` FIRST, so the scaffold vendors the toolchain into the workspace: each fixture's `fixture.sh` additionally runs `cp -R ~/claude-repomap-command ./toolchain` (size-check first: `du -sh`; if the copy is over ~200MB, copy only `scripts/` + `pyproject`/lockfile and note the delta), and the arm-B prompt line names it: `REPOMAP_HOME=$PWD/toolchain`. Verify with ONE cheapest-possible in-harness run (1 run, `--max-cost-usd 2`, arm-B prompt, repomap case skeleton with the real fixture): the run's trace must show `scripts/run.sh` executing INSIDE ./fixture-repo and REPOMAP.md written there. If the toolchain cannot run in-sandbox (dependency install needs network the sandbox blocks), arm B is structurally impossible — record that as the experiment's headline finding (headless-sandbox infeasibility) and run arms A/C only, narrowing every verdict claim accordingly.

---

### Task 1: repomap utility experiment

**Files:**
- Create: `evals/_lib/nav-fixture.sh`, `tests/nav-fixture.bats`
- Create: `evals/repomap-nav-task/{case.yaml,fixture.sh,prompt.md}`, `evals/repomap-nav-task/graders/{skill-fired,task-correct,no-wrong-edits}.md`
- Create: `evals/reports/$(date +%F)-repomap-utility-PREREG.md`, then `…-repomap-utility.md`

- [ ] **Step 1: Write the failing fixture test**

`tests/nav-fixture.bats`:

```bats
#!/usr/bin/env bats
# Unit tests for evals/_lib/nav-fixture.sh — the repomap experiment's fixture.

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  source "$REPO_ROOT/evals/_lib/nav-fixture.sh"
  FIX="$BATS_TEST_TMPDIR/repo"
}

@test "fixture builds the scattered notifications feature" {
  nav_fixture "$FIX"
  for f in app/services/notification_service.py app/models/notification.py \
            app/controllers/notification_controller.py app/jobs/digest_job.py \
            app/services/user_service.py web/hooks/notification_hook.py; do
    [ -f "$FIX/$f" ] || { echo "missing $f"; return 1; }
  done
  # the two consumers the task must update, verifiable by content
  grep -q "notification_service.send" "$FIX/app/jobs/digest_job.py"
  grep -q "Notification(" "$FIX/web/hooks/notification_hook.py"
}

@test "nav_fixture is idempotent and leaves cwd alone" {
  start_dir="$PWD"
  nav_fixture "$FIX"
  nav_fixture "$FIX"
  [ "$PWD" = "$start_dir" ]
  git -C "$FIX" rev-parse HEAD >/dev/null
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/nav-fixture.bats`
Expected: FAIL — `evals/_lib/nav-fixture.sh` does not exist.

- [ ] **Step 3: Write the fixture lib**

`evals/_lib/nav-fixture.sh` — one function, subshell-isolated, ~20 small files across 6 modules with the notification feature deliberately split between a service, a model, a controller, a background job, and a web hook (only the job and the hook CONSUME the service; the rest is realistic ballast):

```bash
#!/usr/bin/env bash
# nav_fixture <dir>: builds the repomap experiment's fixture repo — a small
# multi-module app whose "notification priority" feature is split across six
# directories, with two real consumers of the service and realistic ballast.
nav_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: nav_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"/{app/{models,services,controllers,jobs,mailers,helpers},web/hooks,db/migrations,tests,config,docs}
  cd "$dir" || exit 1
  git init -q && git config user.email fixture@example.com && git config user.name fixture

  cat > app/models/notification.py <<'EOF'
class Notification:
    """A queued outbound message. priority: 0=low 1=normal 2=urgent (UNUSED today)."""
    def __init__(self, user_id, subject, body, channel="email"):
        self.user_id, self.subject, self.body, self.channel = user_id, subject, body, channel
        self.priority = 1
EOF
  cat > app/services/notification_service.py <<'EOF'
from app.models.notification import Notification

def send(notification):
    """Delivers via the channel. Returns a receipt id."""
    return f"rcpt-{notification.user_id}-{notification.channel}"

def send_digest(user_id, items):
    n = Notification(user_id, "Your digest", "\n".join(items))
    return send(n)
EOF
  cat > app/controllers/notification_controller.py <<'EOF'
from app.services.notification_service import send_digest

def create(user_id, items):
    return {"receipt": send_digest(user_id, items)}
EOF
  cat > app/jobs/digest_job.py <<'EOF'
from app.services.notification_service import send_digest

def run_nightly(users, catalog):
    receipts = {}
    for uid in users:
        items = [t for t in catalog if t["owner"] == uid]
        receipts[uid] = send_digest(uid, items)
    return receipts
EOF
  cat > web/hooks/notification_hook.py <<'EOF'
import json
from app.models.notification import Notification

def handle(payload):
    n = Notification(payload["user"], payload["subject"], payload["body"], channel=payload.get("channel", "email"))
    return json.dumps({"ok": True})
EOF
  cat > app/services/user_service.py <<'EOF'
def find(user_id):
    return {"id": user_id, "email": f"user{user_id}@example.com"}

def mute(user_id):
    return {"id": user_id, "muted": True}
EOF
  cat > app/mailers/template_renderer.py <<'EOF'
def render(subject, body):
    return f"<h1>{subject}</h1><p>{body}</p>"
EOF
  cat > app/helpers/slug.py <<'EOF'
def slugify(text):
    return "-".join(text.lower().split())
EOF
  printf 'CREATE TABLE notifications (\n  id INTEGER PRIMARY KEY,\n  user_id INTEGER NOT NULL,\n  subject TEXT,\n  body TEXT,\n  channel TEXT DEFAULT '"'"'email'"'"'\n);\n' > db/migrations/001_notifications.sql
  printf 'import unittest\nfrom app.services.notification_service import send_digest\n\nclass T(unittest.TestCase):\n    def test_digest(self):\n        self.assertTrue(send_digest(1, ["a"]).startswith("rcpt-"))\n\nif __name__ == "__main__":\n    unittest.main()\n' > tests/test_digest.py
  printf 'DEBUG=1\nSECRET_KEY=fixture-not-a-secret\n' > .env.example
  printf '# fixture app\nRun tests: python3 -m unittest discover tests\n' > README.md
  # ballast: near-miss names that a naive search would trip on
  printf 'def notify_admin(msg):\n    print("admin:", msg)\n' > app/helpers/admin_notifier.py
  printf 'class NotificationSettings:\n    frequency = "weekly"\n' > app/models/settings.py
  printf 'from app.helpers.slug import slugify\n\ndef subject_for(post):\n    return slugify(post["title"])\n' > app/controllers/blog_controller.py
  git add -A && git commit -qm "fixture: multi-module app with scattered notification feature"
  )
}
```

(Note the deliberate near-misses: `app/helpers/admin_notifier.py` and `app/models/settings.py::NotificationSettings` — files a keyword search hits that are NOT the feature. The task's correctness depends on finding the real consumers, which is what a repo map should accelerate.)

- [ ] **Step 4: Verify green, wire the case, write graders**

Run: `bats tests/nav-fixture.bats` → both PASS. Then:

`evals/repomap-nav-task/case.yaml`:
```yaml
schema_version: "1.1"
name: repomap-nav-task
context:
  scaffold_script: fixture.sh
```
`evals/repomap-nav-task/fixture.sh`:
```bash
#!/bin/bash
. "$(dirname "$0")/../_lib/nav-fixture.sh"
nav_fixture ./fixture-repo
```
(chmod +x both — the suite convention.)

`evals/repomap-nav-task/prompt.md` (arm A/C shape):
```
---
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
tags: [repomap, nav-task, maintainer]
---

The repo at ./fixture-repo has a notifications feature with a priority
concept that is currently dead weight: Notification.priority is set to 1
and never read. Make priority real end to end: callers must be able to
pass an urgent priority, and EVERY place that currently creates or sends
a Notification must carry it through. Don't touch anything unrelated.
Reply with the files you changed and one line each on what changed.
```

Arm B's prompt is identical except one line inserted before the task paragraph:
`Start by running /repomap to orient yourself (write REPOMAP.md), then do the task below.`

`graders/skill-fired.md`:
```
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?repomap"'
---
```
`graders/task-correct.md`:
```
---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: the fixture's notification feature lives in
app/models/notification.py (the Notification class with the priority field)
and app/services/notification_service.py (send/send_digest). The TWO real
consumers that send through the service are app/jobs/digest_job.py (calls
send_digest) and web/hooks/notification_hook.py (constructs Notification —
the task's "both places that send" means these two). app/controllers/
notification_controller.py calls send_digest too but only via the job-facing
helper — accepting it as a third edit is fine, never required.

Ground truth (corrected — plan-eng-review finding 3): the service-CALLERS
are app/jobs/digest_job.py and app/controllers/notification_controller.py
(both call send_digest); web/hooks/notification_hook.py CONSTRUCTS a
Notification (a priority-carrier site, not a sender).

PASS if: the model or service is updated to accept priority AND all three
carrier sites (job, controller, hook) forward/accept it, AND the reply's
list matches the Edit-tool edit-proofs (below) — claims without matching
edits FAIL.

FAIL if any carrier site is missing, priority is settable nowhere, or the
reply claims edits the edit-proof graders did not observe. Vocabulary
irrelevant.
```
`graders/no-wrong-edits.md`:
```
---
type: llm
focus: last_message
arm: both
---

Boundary ruling (plan-eng-review finding 6): the map artifacts (REPOMAP.md,
DBMAP.md) are workflow outputs, never wrong edits — arm B listing them is
fine.

PASS if the changed-files list touches only notification-feature files
(model, service, job, controller, hook, tests) — in particular NOT
app/helpers/admin_notifier.py or app/models/settings.py (near-miss ballast)
and not unrelated modules (blog controller, slug helper, migrations).

FAIL if any ballast or unrelated file is claimed as changed.
```

Edit-proof graders (plan-eng-review finding 6 — mechanical proof the edits
happened; claims alone never pass task-correct). `graders/edits-made.md`:
```
---
type: tool_used
tool: Edit
input_match: '"file_path"\s*:\s*"[^"]*(digest_job|notification_controller|notification_hook)"'
min: 3
---
```
(A Write to the same paths also satisfies the intent; if the harness
input_match cannot express alternation cleanly at execution time, split
into three single-pattern tool_used graders, `min: 1` each — same
commit.)

- [ ] **Step 5: Generate arm C's artifact**

```bash
T=$(mktemp -d) && bash -c 'source evals/_lib/nav-fixture.sh; nav_fixture '"$T"'/r'
cd "$T/r" && ~/claude-repomap-command/scripts/run.sh repomap -o REPOMAP.md && wc -l REPOMAP.md
cp REPOMAP.md /tmp/repomap-artifact.md
```
The executor appends a Task-1 fixture step: arm C's `fixture.sh` also copies `/tmp/repomap-artifact.md` to `./fixture-repo/REPOMAP.md` after `nav_fixture` (ship the artifact INSIDE the case's fixture script via a committed `evals/repomap-nav-task/REPOMAP.md` copy instead of /tmp — commit the generated file into the case dir and `cp` it in the scaffold; deterministic, self-contained).

- [ ] **Step 6: Write and commit the PREREG before any run**

`evals/reports/$(date +%F)-repomap-utility-PREREG.md`:
```markdown
# PREREG — repomap utility (does the map help the agent?)

Registered before any run of `repomap-nav-task`. Question: does running
/repomap first (arm B), or merely having REPOMAP.md present (arm C),
improve task correctness or exploration cost over cold start (arm A)?

## Arms
A cold · B skill-first (one extra prompt line — the intervention) ·
C map pre-injected (same map file for every C run, generated once from
the fixture by the executor; prompt identical to A).

## Fairness
Graders grade claimed file changes vs the fixture's ground truth, never
vocabulary; the map artifact is committed in the case dir so C runs are
byte-identical; single-plugin check mandatory before reading numbers.

## Endpoints
- Primary: mean(task-correct, no-wrong-edits) per arm; adopt a positive
  verdict if the best arm beats A by ≥ +0.10 and no grader regresses ≥ 0.34.
- Secondary (reported only): mean turns + durationSeconds per arm.
- skill-fired ≥ 2/3 in arm B else under-powered → no verdict.
- Budget $12; cap $8/command; abort if one run > $1.50.

## Verdict table (fixed in advance)
B>A ∧ C≈B → "run it first" justified · C>A ∧ B≈A → prefer pre-generated
maps over on-demand runs · B≡A≡C → null at this scale.
```

Commit: fixture lib + bats + case + graders + the committed REPOMAP.md artifact + PREREG, one commit, message `evals: pre-register the repomap utility A/B/C (fixture, case, artifact, PREREG) before any run`.

- [ ] **Step 7: Run arm A → single-plugin check → parse**

```bash
claude plugin eval . --case repomap-nav-task --runs 3 --ablation none --trust-plugin \
  --no-publish --scaffold --allow-tools Bash --judge-model sonnet \
  --max-cost-usd 8 --json evals/results/repomap-armA.json
```
Then the mandatory single-plugin check (the Context-for-executors snippet) against `repomap-armA.json`. Arms A → B (swap prompt.md to the B shape, commit nothing — tree-state change between arms is the experiment) → C (restore A's prompt, add the artifact copy to fixture.sh) same command with `-armB`/`-armC` outputs.

- [ ] **Step 8: Analyze, write `…-repomap-utility.md`, commit**

Per-arm grader pass-rates, turns/duration means, the verdict-table row that matches, cost. Commit with the verdict in the message.

---

### Task 2: dbmap utility experiment

**Files:**
- Create: `evals/_lib/db-fixture.sh`, `tests/db-fixture.bats`
- Create: `evals/dbmap-schema-task/{case.yaml,fixture.sh,prompt.md}`, `graders/{skill-fired,task-correct,no-wrong-edits}.md`
- Create: `evals/reports/$(date +%F)-dbmap-utility-PREREG.md`, then `…-dbmap-utility.md`

- [ ] **Step 1: Failing test** — `tests/db-fixture.bats` (same pattern as Task 1):

```bats
#!/usr/bin/env bats
setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  source "$REPO_ROOT/evals/_lib/db-fixture.sh"
  FIX="$BATS_TEST_TMPDIR/repo"
}

@test "fixture builds the schema with the un-indexed FK trap" {
  db_fixture "$FIX"
  [ -f "$FIX/app.db" ] && [ -f "$FIX/.env" ]
  tables="$(sqlite3 "$FIX/app.db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")"
  [ "$tables" -ge 8 ]
  # orders.user_id is deliberately un-indexed; users.id is the PK
  idx="$(sqlite3 "$FIX/app.db" "SELECT COUNT(*) FROM pragma_index_list('orders');")"
  [ "$idx" -eq 0 ] || false
  grep -q "orders" "$FIX/app/queries/orders_by_user.py"
}

@test "db_fixture is idempotent and leaves cwd alone" {
  start_dir="$PWD"
  db_fixture "$FIX" && db_fixture "$FIX"
  [ "$PWD" = "$start_dir" ]
}
```

- [ ] **Step 2: FAIL check** — `bats tests/db-fixture.bats` → lib missing.

- [ ] **Step 3: The fixture lib**

`evals/_lib/db-fixture.sh` (sqlite via stdlib python3 to keep it deterministic; 8 tables — users, orders, order_items, products, addresses, payments, events, audit_logs — with FKs indexed EXCEPT orders.user_id, plus a raw-SQL python app whose two query files filter orders by user_id):

```bash
#!/usr/bin/env bash
# db_fixture <dir>: sqlite-backed fixture for the dbmap utility experiment.
db_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: db_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"/{app/queries,app/models,scripts,tests}
  cd "$dir" || exit 1
  git init -q && git config user.email fixture@example.com && git config user.name fixture
  python3 - <<'PY'
import sqlite3
c = sqlite3.connect("app.db")
c.executescript("""
CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL UNIQUE, created_at TEXT);
CREATE TABLE addresses (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), line1 TEXT, city TEXT, country TEXT);
CREATE INDEX idx_addresses_user ON addresses(user_id);
CREATE TABLE products (id INTEGER PRIMARY KEY, sku TEXT NOT NULL, title TEXT, price_cents INTEGER NOT NULL);
CREATE TABLE orders (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), status TEXT NOT NULL DEFAULT 'new', placed_at TEXT NOT NULL);
CREATE TABLE order_items (id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL REFERENCES orders(id), product_id INTEGER NOT NULL REFERENCES products(id), qty INTEGER NOT NULL DEFAULT 1);
CREATE INDEX idx_items_order ON order_items(order_id);
CREATE INDEX idx_items_product ON order_items(product_id);
CREATE TABLE payments (id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL REFERENCES orders(id), amount_cents INTEGER NOT NULL, provider TEXT, created_at TEXT);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE TABLE events (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), kind TEXT NOT NULL, occurred_at TEXT NOT NULL);
CREATE INDEX idx_events_occurred ON events(occurred_at);
CREATE INDEX idx_events_user ON events(user_id);
CREATE TABLE audit_logs (id INTEGER PRIMARY KEY, actor TEXT, action TEXT, at TEXT);
""")
for i in range(1, 21):
    c.execute("INSERT INTO users VALUES (?,?,datetime('now'))", (i, f"user{i}@example.com"))
    c.execute("INSERT INTO orders(user_id,status,placed_at) VALUES (?,?,datetime('now'))", (i, "new" if i % 2 else "shipped"))
c.commit()
PY
  cat > app/queries/orders_by_user.py <<'EOF'
import sqlite3

def open_orders_for(db, user_id):
    """Every non-shipped order for a user, newest first."""
    rows = db.execute(
        "SELECT id, status, placed_at FROM orders WHERE user_id = ? AND status != 'shipped' ORDER BY placed_at DESC",
        (user_id,)).fetchall()
    return rows
EOF
  cat > app/queries/spend_report.py <<'EOF'
def lifetime_spend(db, user_id):
    """Sum of payments for a user's orders."""
    return db.execute(
        "SELECT COALESCE(SUM(p.amount_cents),0) FROM payments p JOIN orders o ON p.order_id = o.id WHERE o.user_id = ?",
        (user_id,)).fetchone()[0]
EOF
  printf 'class Order:\n    table = "orders"\n    fields = ["id", "user_id", "status", "placed_at"]\n' > app/models/order.py
  printf 'import sqlite3, sys\ndb = sqlite3.connect("app.db")\nsys.path.insert(0, ".")\n' > scripts/repl.py
  printf 'DATABASE_URL=sqlite:///%s/app.db\n' "$PWD" > .env
  printf '# fixture shop\nOrders live in the orders table.\nQuery paths: app/queries/*.py\n' > README.md
  git add -A && git commit -qm "fixture: sqlite shop schema + raw-SQL query app"
  )
}
```

The trap: `orders.user_id` is the schema's ONLY un-indexed foreign key (every other FK is indexed — corrected per plan-eng-review finding 4), and `app/queries/orders_by_user.py` filters on it — exactly what dbmap's Index Analysis is designed to surface. The fixture README states only that orders live in `orders` and query paths are app/queries/*.py — it does NOT name the missing index (the original draft leaked the answer).

- [ ] **Step 4: Green, wire, graders, arm-C artifact**

`bats tests/db-fixture.bats` → PASS. Case wiring identical to Task 1 (`case.yaml` name `dbmap-schema-task`; `fixture.sh` calls `db_fixture ./fixture-repo`).

`prompt.md` (A/C shape; B inserts `Start by running /dbmap against the connection in .env (write DBMAP.md), then do the task below.`):
```
---
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
tags: [dbmap, schema-task, maintainer]
---

The repo at ./fixture-repo backs a small shop on the sqlite DB in app.db
(connection string in .env — that's the only connection; use it). Our
load tests show the orders-by-user page is the slowest query path in the
app. Diagnose the database-side cause, write the exact migration SQL to
fix it, and update BOTH python query files in app/queries/ if they need
to change. Reply with: the diagnosis, the migration SQL, and the files
you touched.
```

`graders/task-correct.md`:
```
---
type: llm
focus: last_message
arm: both
---

Ground truth: orders.user_id is the schema's ONLY un-indexed foreign key
(every other FK carries an index) and app/queries/orders_by_user.py
filters on it — the diagnosis the fixture plants.

PASS if the reply: names the missing index on orders.user_id (FK + query
filter), provides CREATE INDEX SQL for it, and does NOT rewrite either
query file in a way that changes results (a no-op note is correct — the
fix is the index; harmless query rewrites pass, wrong-SQL rewrites fail).

FAIL if the diagnosis names a different cause (missing index elsewhere,
wrong table) or no migration SQL is given.
```
`graders/no-wrong-edits.md`:
```
---
type: llm
focus: last_message
arm: both
---

PASS if touched files are only within app/queries/ (and at most a
migration/sql file the reply itself defines) — not app/models/, scripts/,
the schema DDL of unrelated tables, or .env.

FAIL if unrelated files are claimed as changed.
```
`graders/skill-fired.md` matches `dbmap`.

Arm C artifact (corrected — plan-eng-review finding 5): B and C must receive the SAME information, and /dbmap's output includes the agent-authored `## Index Analysis` on top of the tbls doc. Generate C's artifact by actually running the /dbmap skill once against a scratch build of the fixture (executor-side, Task-0-style scratch repo), commit the resulting FULL DBMAP.md into `evals/dbmap-schema-task/DBMAP.md`, and `cp` it into `./fixture-repo/` in the scaffold for arm C only.

- [ ] **Step 5: PREREG, commit, run A → B → C with single-plugin checks, analyze, report, commit**

PREREG skeleton identical to Task 1's (swap names/arms; budget $12; note the headless single-connection steering: the prompt names .env as the only connection so dbmap's interactive ask is never reached — if a run stalls on a connection question anyway, that is a FINDING about the skill's headless usability, recorded verbatim). Same run command shape, outputs `dbmap-arm{A,B,C}.json`. Report → `…-dbmap-utility.md` → commit.

---

### Task 3: Consolidated verdict + close-out

**Files:** Create `evals/reports/$(date +%F)-context-maps-consolidated.md`; Modify `evals/RUBRIC.md` (two case rows).

- [ ] **Step 1: Write the consolidated report** — both experiments' verdict tables (the fixed outcome-matrix row that matched), turns/duration deltas, total spend vs the ≤$25 plan budget, the graphify scope-out note (human-facing HTML output; no agent consumer; revisit only if a consumer lands), and follow-up candidates gated on the verdicts: a "run /dbmap first" convention for DB-heavy work ONLY if B>A; the CLAUDE.md map-rule (dbmap already offers it) ONLY if C>A with B≡A; write-plan under-firing unaffected.
- [ ] **Step 2: Register both cases in RUBRIC.md's sampling table** (the round-2 correction's pattern — rows land inside the table, not an appendix):
  `| `repomap-nav-task` | repomap | direct | maintainer | nav-fixture; measures map utility A/B/C |`
  `| `dbmap-schema-task` | dbmap | direct | maintainer | db-fixture + sqlite; measures map utility A/B/C |`
- [ ] **Step 3: Suite + commit**

```bash
./tests/run.sh   # expected: all green (664+ with the two new fixture bats files)
git add evals/RUBRIC.md evals/reports/$(date +%F)-context-maps-consolidated.md
git commit -m "evals: context-map utility consolidated verdict — <one line per experiment>; graphify scoped out; follow-ups gated on verdicts; RUBRIC rows"
```
No VERSION bump: this plan ships measurements only; any skill-body change its verdicts justify is a separate eval-gated plan.

---

## Test Plan & Verification

**Coverage target:** both fixture libs 100% path-tested in bats (build, expected content, trap present, idempotence, cwd isolation — 4+4 tests); every eval case carries ≥2 llm task graders + a skill-fired indicator; every experiment has a PREREG committed before its first run (commit timestamps verify); the single-plugin check passes before any number is read (its assertion failure is the guard).

**Critical paths (must pass before ship):**
- Fixture → case wiring → eval run executes and grades (Task 0 Step 2's smoke proves the toolchain; each experiment's arm-A run proves the case end-to-end)
- Single-plugin check green on all six arm outputs
- Verdict row selection follows the pre-registered outcome matrix verbatim

**Edge cases & error paths:**
- Second plugin root appears → check fails loudly → experiment halts, reported (the 2026-10-06 lesson, now structural)
- dbmap run stalls on the interactive connection ask → recorded as a headless-usability finding with the transcript tail; arm-B interpretation notes it
- One run > $1.50 at calibration → experiment aborts per PREREG, cases + PREREG stay committed
- skill-fired < 2/3 in arm B → under-powered, no verdict (the testphilosophy rule, applied prospectively this time)

**Regression guards:** `./tests/run.sh` green before and after every task (the errexit guard owns assertion style); existing quota/writeplan cases untouched.

**Verification commands:**
- `bats tests/nav-fixture.bats tests/db-fixture.bats` — expected: all pass
- `./tests/run.sh` — expected: all pass
- Six JSONs under `evals/results/{repomap,dbmap}-arm{A,B,C}.json`, each passing the single-plugin assertion

**Acceptance criteria (from spec):**
- [ ] "Do they help it work/program better?" → per-skill verdict rows with numbers, or documented under-powered/null
- [ ] Map-value vs skill-call-overhead separated → the C arm exists in both experiments and its delta is reported
- [ ] Exploration cost measured → turns + durationSeconds per arm in both reports
- [ ] graphify question answered → scope-out note with the consumer rationale

## GSTACK REVIEW REPORT

Target: docs/superpowers/plans/2026-10-06-context-map-utility.md (plan review, /write-plan → /plan-eng-review chain; codex outside voice per maintainer config)
Date: 2026-10-06 · Scope Challenge: complexity gate tripped (~12 files); structure kept — the scope is the maintainer's named question ("this test"); aborts and pilot framing added instead of cuts.

| Review | Trigger | Why | Status | Findings |
|---|---|---|---|---|
| Scope Challenge | 12+ files | challenge cuts/structure | read-only | scope accepted (single question, three-arm design is the minimum that separates map value from overhead) | F0: budget math $48>​$25 and plugin check placed post-spend — both folded (caps→4, free `claude plugin list` pre-check) |
| 1. Architecture | experiment design | arm isolation, feasibility | read-only | FOLDED | F1 [P0 10/10] sandbox cannot read $HOME → skills' toolchain lookup dies in-harness (verified RUBRIC.md Known limits) → toolchain vendored into workspace + REPOMAP_HOME + mandatory in-harness pilot; F5 B−A is a policy effect, C−A ambient-file → verdict claims narrowed; F2 leakage boundary disclosed + traces probe |
| 2. Code quality | fixture/DRY | shared-code rubric | read-only | FOLDED | F10 pre-spend free plugin check added |
| 3. Tests | grader validity | coverage/power | read-only | FOLDED | F6 [P0 9/10] graders scored claims not edits → tool_used edit-proof graders added, claims-without-proofs fail, map artifacts exempted from no-wrong-edits; F8 n=3 one-vote=0.167 → pilot framing, ±0.34 signal rule, optional n=5 confirmatory, no "proven null" language; F9 turns truncation/partial/error accounting + archived-trace exploration counts |
| 4. Performance | cost = budget | arithmetic | read-only | FOLDED | F11 caps 8→4, cumulative per-experiment budget checks, limit-error policy |
| Outside Voice | codex exec (read-only, user-configured) | independent second opinion | 1 pass — 11 findings, ALL verified against RUBRIC/eval-traces/claude-CLI before folding (three citations spot-checked: RUBRIC.md Known-limits line, scripts/eval-traces.sh, `claude plugin list` output) | COMPLETED | F3 [P1 10/10] nav ground truth was wrong (hook constructs, never sends; controller is the second caller; bats grep impossible) → task wording, grader, bats all corrected; F4 [P1 9/10] events.user_id was a second un-indexed FK + README leaked the answer → indexed + de-leaked; F7 headless dbmap interactivity → pilot + separate headless-usability finding channel |

VERDICT: PASS AFTER REVISION — all 11 findings folded; the plan now leads with an in-harness toolchain pilot (which can itself conclude "arm B structurally impossible in-sandbox" and narrow the experiment to A/C), grades edits rather than claims, and speaks in pilot language.

OUTSIDE COVERAGE: codex (read-only sandbox; Recommendation was "fix-first because the current fixtures, grading, and arm isolation can produce confident-looking verdicts about the wrong intervention" — the fixes are folded above).

NO UNRESOLVED DECISIONS
