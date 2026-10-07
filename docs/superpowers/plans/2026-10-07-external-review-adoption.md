# External Review Technique Adoption — Measured Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt only the external-repo techniques that measurably beat the current baseline under `claude plugin eval` — six candidates, each behind a pre-registered adopt/reject gate, implemented one at a time in cost order, with nulls documented as real answers.

**Architecture:** Six single-intervention A/B experiments (Task 1–6), each: extend the eval fixture → write the case → commit PREREG + cases before any paid run → price-calibration run → baseline run (current tree) → apply the one skill edit → change run → decide against the pre-registered gates → adopt (version bump) or revert. New skills (Tasks 4–5) are vendored/adapted first and measured as with-skill vs without-skill. A consolidated report (Task 7) ships everything adopted in one reviewed release. The method is the one `docs/superpowers/plans/2026-10-05-codex-eval-gated-adoption.md` established; the PREREG discipline is `evals/reports/2026-10-05-review-calibration-PREREG.md`.

**Tech Stack:** `claude plugin eval` (sonnet judge — never downgraded), bash fixture libs under `evals/_lib/`, markdown skill bodies, bats. No new dependencies.

---

## Research verdicts (done before this plan — do not re-litigate while executing)

Verified 2026-10-07 against: `augmentcode/auggie` (plugin_marketplace/code-review, .augment/commands), `augmentcode/review-pr` (templates/*.njk, action.yml), `augmentcode/augment-agent` (TEMPLATE.md), `cursor/plugins` (thermos, pr-review-canvas, cli-for-agent, pstack), `cursor/community-plugins`, `vercel-labs/open-agents` (.agents/skills/code-review/SKILL.md, vercel-react-best-practices).

**Overlap check against what is already adopted** (verified in-tree): `skills/basic-review/SKILL.md` v1.2.0 already carries the 2026-10-06-adopted "What earns a finding" block (introduced-in-diff rule, no-speculation, rigor-matching, prefer-no-findings) — that experiment measured +0.267 primary and was adopted (`evals/reports/2026-10-06-review-calibration.md`). Anything in the external candidates that duplicates that block is already ours; only the delta is measured. `skills/qa-full/SKILL.md` already mandates the per-check accounting ledger (RAN-CLEAN/FIXED(n)/…, ~line 618) and structured report (~line 659) — the 2026-10-05 plan correctly rejected a qa-full *accounting* experiment; the thermos delta below is *cross-check synthesis*, which the ledger does not do.

| Candidate (source) | Evidence | Verdict |
|---|---|---|
| Repo-pinned conventions discovery (vercel-labs code-review: check CONVENTIONS.md/AGENTS.md before reviewing) | Not in `basic-review`. Tension with prefer-no-findings is resolved by the existing "author would fix it if told" rule — a pinned rule is exactly that. | **Experiment 1** (primary). Riders in the same edit: PR-URL routing (review-pr/auggie) and the trigger-conditions sentence (vercel-labs) — both unmeasured, guarded by the unchanged cases. |
| Structured review-guidelines file with globs + id citation (auggie `.augment/code_review_guidelines.yaml`) | Not in any superskills skill. Distinct from Task 1: prose conventions vs a machine-readable contract repos can pin (`id`, `globs`, `rules`). | **Experiment 2.** Runs after Task 1's decision; its baseline includes Task 1's outcome. |
| "Code judo" ambition bar (cursor thermos: reframe that deletes a whole category of complexity; 1k-line smell; spaghetti-growth-as-design; canonical layer) | `clean-code` v1.0.0 mandates "smallest safe refactor" and has no ambition dimension. Genuine delta, genuine tension to resolve in the edit text. | **Experiment 3.** |
| cli-for-agent patterns (cursor: non-interactive first, layered --help with examples, fail-fast errors with a correct invocation, idempotency, --dry-run/--yes, machine-useful success output) | No superskills skill covers agent-usable CLI design. Upstream is MIT; vendoring rule applies (in-tree copy + `metadata.upstream`). | **Experiment 4** (vendored new skill). |
| Diff walkthrough presentation (cursor pr-review-canvas: core→wiring→boilerplate ordering, pseudocode distillation, old-vs-new example trace, sparse tricky-tags) | No superskills skill presents changes for comprehension (review skills judge them). Canvas SDK parts are host-specific and dropped. | **Experiment 5** (adapted new skill). |
| Cross-check synthesis rules (cursor thermos orchestrator: dedupe findings across reviewers, weight overlapping findings, resolve disagreements by evidence) | Verified absent from `qa-full` Step 3: `/review` then `/clean-code` run with no merge rule between them. The thermos guardrails (intended breakage, no unfinished research) are already covered by "What earns a finding" — only the synthesis rules are the delta. Weakest prior + highest cost → runs last, with a hard abort. | **Experiment 6.** |

**Rejected up front (stays out of the tree, with reasons):**
- *Auggie's specialized reviewer subagent* (`local-analyzer` with tool allow/deny + return contract): superskills skills run in-session by design and `/review` already runs an adversarial subagent; a second reviewer layer duplicates it. No consumer.
- *review-pr / augment-agent GitHub Actions themselves*: paid CI on a private repo is barred by the repo invariant, and superskills offers no CI review product. The transferable ideas (avoid-list, zero-findings-ok, capabilities/limitations sections) are already inside `basic-review` v1.2.0's adopted block.
- *Auggie `warp` plugin hooks*: Warp-terminal-specific; no other host consumes them.
- *cursor/community-plugins scan pipeline*: Next.js/Supabase directory infrastructure; our marketplace is curated. The vendoring-hygiene idea is noted as a possible future task, not built here (YAGNI — no observed vendoring incident).
- *pstack micro-principle skills*: opposite granularity to our fewer-richer convention; the two transferable ideas (`show-me-your-work`, `no-comments`) are already implied by `verify` and the standards.
- *vercel-react-best-practices umbrella+rules layout*: an authoring-layout note with no active authoring need right now; revisit when the next umbrella skill lands.
- *augment-agent's 128KB diff cap*: operationally sensible but unmeasurable at fixture scale; deferred, not adopted.

**Cross-harness rule (user requirement):** every intervention is a markdown edit to a skill body or an in-tree vendored skill — no new host-specific instructions. Task-validated by the existing `tests/skills-host-neutral.bats`, which new skills must pass.

**Cost governance (money rule):** every behavioural run and every `llm` grader vote is a real model charge on the user's account. Measured unit costs from 2026-10-06 (`evals/reports/2026-10-06-review-calibration.md`): review-case runs $0.23–0.48; planning runs $1.00–1.53; qa-full fan-out is unmeasured. Per-experiment budget, worst case: E1 $19 (3+8+8), E2 $19, E3 $36 (6+15+15), E4 $29 (5+12+12), E5 $29 (5+12+12), E6 $48 (8+20+20). **Worst case ≈ $180 if every experiment runs to completion; realistic ≈ $55–90.** Every command below carries its own `--max-cost-usd`; every experiment has a price-calibration run with a stated abort condition. **No paid run starts without the user's explicit go-ahead for that experiment** — the plan states the budgets; the user authorises each one. Skipping an experiment leaves the plan valid; the skip is reported.

**Security & threat model:** this plan crosses no trust boundary — no auth, no untrusted input, no sensitive data; the eval fixtures are local synthetic repos and no script leaves the machine. Stated per the plan checklist; no `/cso` pass needed.

---

## File Structure

| File | Responsibility | Create/Modify |
|---|---|---|
| `evals/_lib/review-fixture.sh` | Builds the review-eval fixture repo; gains `conventions` (Task 1) and `guided-violation`/`guided-clean` (Task 2) modes alongside the existing `bait`/`benign`. Idempotent (`rm -rf` first, subshell). | Modify |
| `evals/review-conventions/` | Task 1's case: `case.yaml`, `fixture.sh`, `prompt.md`, `graders/{skill-fired,cites-convention,no-convention-bleed}.md`. | Create |
| `evals/review-guidelines/`, `evals/review-guidelines-clean/` | Task 2's cases (same wiring pair convention). | Create |
| `evals/_lib/cleancode-fixture.sh` | Task 3's fixture: exporters repo with a planted fourth-copy + a visible judo reframe. | Create |
| `evals/cleancode-judo/` | Task 3's case. | Create |
| `skills/cli-for-agent/SKILL.md` | Task 4's vendored skill (adapted from cursor/plugins, MIT). | Create |
| `evals/_lib/cli-fixture.sh`, `evals/cli-agents-quality/` | Task 4's fixture + case. | Create |
| `skills/diff-walkthrough/SKILL.md` | Task 5's adapted skill. | Create |
| `evals/_lib/walkthrough-fixture.sh`, `evals/walkthrough-pricing/` | Task 5's fixture + case. | Create |
| `evals/_lib/qaful-synthesis-fixture.sh`, `evals/qaful-synthesis/` | Task 6's fixture + case (separate from `qa-full-fixture.sh` so the closed routing work's fixture state is never perturbed — same separation as `daily-qa-fixture.sh`). | Create |
| `evals/reports/2026-10-07-<experiment>-PREREG.md` (×6) | Pre-registrations, each committed before its experiment's first comparative run. | Create |
| `skills/basic-review/SKILL.md` | Tasks 1–2 interventions; `version: 1.2.0 → 1.3.0 → 1.4.0` only on adoption. | Modify (gated) |
| `skills/clean-code/SKILL.md` | Task 3 intervention; `version: 1.0.0 → 1.1.0` only on adoption. | Modify (gated) |
| `skills/qa-full/SKILL.md` | Task 6 intervention (synthesis block at the end of Step 3); `version: 2.0.1 → 2.1.0` only on adoption. | Modify (gated) |
| `evals/reports/2026-10-07-external-adoption.md` | Consolidated verdicts + costs (Task 7). | Create |
| `VERSION`, manifests, `README.md` badge | Ship step, only if anything adopted (Task 7). | Modify (gated) |

DRY: fixtures live in `_lib/` shared via case-local `fixture.sh` shims (the `doctor`/`review` convention); grader `skill-fired` patterns follow the house regex; the Task 1 conventions block deliberately does not restate the adopted "What earns a finding" rules, only extends them. SOLID: each fixture lib has one responsibility (build one repo state); each skill edit is one section in one file (single reason to change). YAGNI: no guidelines-file *parser script* (the agent reads the YAML at runtime — auggie-validated), no JSON review schema (no consumer), no diff-cap machinery (deferred, rejected list).

---

## Context for executors (zero-context assumption)

- **This repo IS superskills** — a plugin of markdown skills installed into multiple agent harnesses. `AGENTS.md` and `ENGINEERING_STANDARDS.md` are the contributor rules; `evals/README.md` is the eval harness manual — read it before Task 1.
- **Eval harness:** `claude plugin eval . --case <name> --runs N --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd <cap> --json <out>` (add ` --case` per extra case; `--scaffold --allow-tools Bash` always; judge stays sonnet). A case = directory with `prompt.md` (frontmatter: `max_turns`, `timeout_seconds`, `allowed_tools`, `tags`), `case.yaml` (`schema_version: "1.1"`, `name`, `context.scaffold_script: fixture.sh`), a case-local `fixture.sh` sourcing the lib, and `graders/*.md` (types: `tool_used` with `tool`/`input_match`; `llm` with `focus: last_message`; `regex`). Results land in `evals/results/<timestamp>/` (git-ignored).
- **Arms:** baseline = current tree (before the intervention); treatment = after. Both `--ablation none` (with-plugin only), same day. n=3 runs/case/arm. Check `cases[].arms.*[].error` for usage-limit/rate-limit noise before trusting a Δ.
- **Per-grader means** are computed as pass-rate over 3 runs, then averaged across the experiment's graders (the arithmetic `evals/reports/2026-10-06-review-calibration.md` used).
- **Do not use in-session subagents for these evals** (`evals/README.md` — closed question, ~25% firing ceiling).
- **New skills are invisible until `./setup` runs** — Tasks 4–5 run it before the treatment arm.
- **Git model:** trunk-style on the current branch; commit every task with the repo's git user; never add Co-Authored-By lines; never rewrite `main`.
- **Versioning:** one reviewed bump per merged change happens once, at Task 7 — except the per-skill frontmatter `version:` bumps inside adoption commits (the 2026-10-06 precedent).

---

### Task 1: Experiment 1 — basic-review repo-pinned conventions (cheapest, cases reuse the review fixture)

**Files:**
- Modify: `evals/_lib/review-fixture.sh` (add `conventions` mode)
- Create: `evals/review-conventions/{case.yaml,fixture.sh,prompt.md,graders/*.md}`
- Create: `evals/reports/2026-10-07-review-conventions-PREREG.md`
- Modify (gated): `skills/basic-review/SKILL.md`

- [ ] **Step 1: Add the `conventions` mode to the review fixture**

In `evals/_lib/review-fixture.sh`, add a third branch after the `benign` branch (inside the existing `if [ "$mode" = ... ]` chain, before the `else`):

```bash
  elif [ "$mode" = "conventions" ]; then
    cat > CONVENTIONS.md <<'EOF'
# orders — house rules

1. Money math is integer cents. Never compute amounts as float fractions;
   percentages are basis-point integers (8500 = 85%).
2. Public functions keep a docstring stating their units.
EOF
    git add -A && git commit -qm "docs: house rules"
    cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream (rounded)."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    value = charge(total)
    return {"items": qty, "charged": value}


def refund(total, pct_bp=8500):
    """Total in dollars; returns the refunded amount in dollars."""
    return round(total * (pct_bp / 10000), 2)
EOF
```

(`refund` computes a float fraction — a violation of pinned rule 1 — while remaining functionally correct, so the finding can only come from the convention, not from a bug.)

**Verify before committing** (this repo's history shows fixture breakage discovered mid-run burning paid budget): append the new branch to a copy of the real `evals/_lib/review-fixture.sh`, `bash -n` it, build the `conventions` mode into a `/tmp` dir, and assert: `git log --oneline | head -2` shows `docs: house rules` on top of `base: orders helpers`; `git show HEAD --stat | grep -q CONVENTIONS`; `grep -q 'pct_bp / 10000' app.py`; `git diff --name-only` lists `app.py`. Delete the temp dir.

- [ ] **Step 2: Write the case**

`evals/review-conventions/case.yaml`:

```yaml
schema_version: "1.1"
name: review-conventions
context:
  scaffold_script: fixture.sh
```

`evals/review-conventions/fixture.sh`:

```bash
#!/bin/bash
. "$(dirname "$0")/../_lib/review-fixture.sh"
review_fixture ./fixture-repo conventions
```

`evals/review-conventions/prompt.md`:

```markdown
---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [basic-review, conventions]
---

The repo under review is at ./fixture-repo. Review my pending changes before I commit — a basic review is fine.
```

`evals/review-conventions/graders/skill-fired.md`:

```markdown
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?basic-review"'
---
```

`evals/review-conventions/graders/cites-convention.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

CONVENTIONS.md pins rule 1: money math is integer cents; percentages are
basis-point integers, never float fractions. The diff adds refund() computing
`total * (pct_bp / 10000)` — a float fraction. The function is functionally
correct; the violation is of the repo's own pinned rule, which is exactly what
a conventions-aware review should catch.

PASS if the reply flags the refund money-math against the pinned rule AND
cites the convention source (names CONVENTIONS.md, quotes its rule, or uses a
`(convention: ...)` style citation).

FAIL if the reply does not mention refund's float math at all, or mentions it
only as a generic style aside with no connection to the pinned rule.

Boundary rulings: flagging refund as a correctness bug it is not does NOT
fail this grader as long as the pinned rule is cited. Flagging it purely as
"float math is risky" without the convention source FAILS.
```

`evals/review-conventions/graders/no-convention-bleed.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

The diff does not touch README.md, and refund() has a docstring stating its
units — the diff conforms to house rule 2.

PASS if the reply raises no finding about README.md, the docstring, or
anything other than the pinned-rule violation.

FAIL if the reply invents findings beyond the convention violation, or treats
a house rule the diff conforms to as a finding.
```

- [ ] **Step 3: Write the PREREG (commit before any run)**

`evals/reports/2026-10-07-review-conventions-PREREG.md`:

```markdown
# PREREG — basic-review repo-pinned conventions discovery

Registered before any run of `review-conventions`. Provenance: vercel-labs
open-agents `.agents/skills/code-review/SKILL.md` (fetched 2026-10-07) checks
CONVENTIONS.md/AGENTS.md/.editorconfig before reviewing. Distinct from the
adopted 2026-10-06 "What earns a finding" block: that block decides which
candidates become findings; this adds a discovery step whose hits are repo-
pinned. Host-agnostic by construction (markdown skill-body edit).

## Intervention (applied only between the two runs)

`skills/basic-review/SKILL.md` gains one subsection after the "What earns a
finding" block (full text in the plan): repo-pinned conventions discovery,
with `(convention: <file>)` citation. Two declared UNMEASURED riders in the
same edit: PR-URL input routing (Scope bullet) and the trigger-conditions
sentence (Report section). Riders are guarded only by the regression cases;
they never fire in any fixture (no PR URLs, no severity-ambiguous findings).

## Cases

| Case | Role |
|---|---|
| `review-conventions` (new) | primary: cites-convention + no-convention-bleed |
| `review-clean` (unchanged) | regression guard: no invented findings on a benign diff |
| `review-calibration` (unchanged) | regression guard: flags introduced bug, skips pre-existing/speculation/style |

## Fairness rule (fixed in advance)

Graders grade behaviour (what was flagged, whether the pinned rule was
connected to the finding), never vocabulary. skill-fired graders are unscored
indicators. Boundary rulings are in the grader texts, committed before runs.

## Endpoints and thresholds (set before the runs)

- Price calibration: one `--runs 1` run of `review-conventions`
  (`--max-cost-usd 3`). ABORT (keep cases, report the price) if it exceeds
  $2.50.
- Runs: `--ablation none`, 3 runs/case/arm, both arms same day.
  Budget: baseline `--max-cost-usd 8`, change `--max-cost-usd 8`
  (≤ $19 total with the price run).
- **Firing-power gate:** basic-review fires in ≥ 2/3 runs in BOTH arms on the
  primary case. Below that: under-powered, adopt nothing.
- **Primary:** mean of cites-convention + no-convention-bleed over 3 runs,
  change vs baseline.
- **Adopt** if: primary ≥ +0.15 AND no grader across all three cases
  regresses ≥ 0.34 AND `review-clean`/`no-false-positive` does not regress at
  all AND the firing gate holds.
- **Reject** otherwise: revert the skill edit, keep cases + PREREG, report
  the null. A null is a real answer.
- Stated limit: n=3; same-day drift between the two sequential runs is an
  uncontrolled small confound (precedent: 2026-10-06 calibration report).
```

- [ ] **Step 4: Commit PREREG + case BEFORE any run**

```bash
git add evals/_lib/review-fixture.sh evals/review-conventions evals/reports/2026-10-07-review-conventions-PREREG.md
git commit -m "evals: pre-register the basic-review conventions A/B (fixture mode, case, PREREG) before any comparative run"
```

- [ ] **Step 5: Price-calibration run (baseline tree, untouched)**

Run: `claude plugin eval . --case review-conventions --runs 1 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 3 --json evals/results/conv-price.json`
Expected: 1 run completes; note the cost. If > $2.50 → execute the PREREG abort: stop, record in the consolidated report, move to Task 2.

- [ ] **Step 6: Baseline run**

Run: `claude plugin eval . --case 'review-*' --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 8 --json evals/results/conv-baseline.json`
Expected: 9 runs — `--case` takes a **single glob** (verified against `claude plugin eval --help`; multiple `--case` flags do not accumulate), and `review-*` matches exactly the three cases that exist at this point: review-conventions, review-clean, review-calibration. Record per-grader means and the skill-fired indicators.

- [ ] **Step 7: Apply the intervention**

In `skills/basic-review/SKILL.md`:

(a) After the line `Skip pure style, formatting, naming, and anything a linter or CI already enforces.` insert:

```markdown
### Repo-pinned conventions (check before reviewing)

Before reviewing, look for the repo's own rules: `CONVENTIONS.md`,
`CONTRIBUTING.md`, `AGENTS.md`, `.editorconfig`, or a conventions/style-guide
file the README names. A rule pinned there applies even when this skill's
defaults would skip it, and a diff that violates it is a finding — the author
pinned it, so they would fix it if told. Cite the source in the finding as
`(convention: <file>)`. Rules the diff follows are not findings; do not
restate them. Judge relevance like any other finding: a pinned rule this repo
no longer follows in practice, or one the diff's context makes inapplicable,
is worth at most a one-line aside — never a finding.
```

(b) In `## Scope`, append a bullet:

```markdown
- With a GitHub PR URL or number, review that PR: `gh pr diff` gives the diff
  and `gh pr view` the base; if `gh` cannot reach the remote, say so and ask
  for a local range instead of guessing.
```

(c) In `## Report`, after the "No findings worth fixing" paragraph, insert:

```markdown
For CRITICAL and HIGH findings, state the trigger condition — the input,
environment, or caller that turns the latent problem into an observable
failure. A finding whose trigger condition cannot be stated drops one
severity level.
```

- [ ] **Step 8: Change run**

Same command as Step 6 with `--json evals/results/conv-change.json`. Expected: 9 runs.

- [ ] **Step 9: Decide against the pre-registered gates**
Apply the PREREG decision rule verbatim. ADOPT → bump `skills/basic-review/SKILL.md` frontmatter `version: 1.2.0` → `1.3.0`. REJECT → `git restore skills/basic-review/SKILL.md` (cases and PREREG stay either way).

- [ ] **Step 10: Commit**

```bash
git add skills/basic-review/SKILL.md
git commit -m "evals: review-conventions A/B for /basic-review — repo-pinned conventions discovery (vercel-labs import) with PR-routing + trigger-condition riders; <ADOPTED: kept the edit, version 1.2.0→1.3.0 | REJECTED: reverted> per pre-registered gates; <primary Δ +X.XX, guards unregressed>"
```

(Fill the bracketed fragments from the actual results — they are the run's findings, not unspecified work.)

---

### Task 2: Experiment 2 — structured review-guidelines file (runs after Task 1's decision)

**Files:**
- Modify: `evals/_lib/review-fixture.sh` (add `guided-violation` + `guided-clean` modes)
- Create: `evals/review-guidelines/`, `evals/review-guidelines-clean/` (wiring pair + prompt + graders each)
- Create: `evals/reports/2026-10-07-review-guidelines-PREREG.md`
- Modify (gated): `skills/basic-review/SKILL.md`

- [ ] **Step 1: Add the two `guided` modes to the review fixture**

In `evals/_lib/review-fixture.sh`, add two more branches directly before the closing `else` (after the `conventions` branch when Task 1's fixture edit landed; before the `else` regardless — Task 1 may have aborted before its fixture edit). Both commit the guidelines file as part of the base, then leave their respective `app.py` as the uncommitted diff:

```bash
  elif [ "$mode" = "guided-violation" ] || [ "$mode" = "guided-clean" ]; then
    cat > REVIEW_GUIDELINES.yaml <<'EOF'
areas:
  - id: money-cents
    globs: ["app.py"]
    rules:
      - "Monetary math is integer cents. Never compute amounts as float
         fractions; percentages are basis-point integers (8500 = 85%)."
  - id: readme-voice
    globs: ["README.md"]
    rules:
      - "README examples always show full argument lists, never bare
         placeholders."
EOF
    git add -A && git commit -qm "docs: review guidelines"
    if [ "$mode" = "guided-violation" ]; then
      cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream (rounded)."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    value = charge(total)
    return {"items": qty, "charged": value}


def refund(total, pct_bp=8500):
    """Total in dollars; returns the refunded amount in dollars."""
    return round(total * (pct_bp / 10000), 2)
EOF
    else
      cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream (rounded)."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    value = charge(total)
    return {"items": qty, "charged": value}


def refund_cents(total_cents, pct_bp=8500):
    """Amount in integer cents; pct_bp is basis points; returns integer cents."""
    return total_cents * pct_bp // 10000
EOF
    fi
```

(`guided-violation`'s `refund` computes a float fraction — a `money-cents` violation that is functionally correct, so only the guideline can justify the finding. `guided-clean`'s `refund_cents` conforms exactly, so the correct review is "no findings".)

**Verify before committing** (same rule as Task 1): extend a copy of the lib with both new branches, `bash -n` it, build each mode into a `/tmp` dir, and assert: both modes show `REVIEW_GUIDELINES.yaml` in `git show HEAD --stat`; `guided-violation` has `pct_bp / 10000` uncommitted in `app.py`; `guided-clean` has `refund_cents` uncommitted and `refund_cents(20000) == 17000` by direct evaluation. Delete the temp dirs.

- [ ] **Step 2: Write the two cases**

`evals/review-guidelines/` — `case.yaml` (`name: review-guidelines`), `fixture.sh` calling `review_fixture ./fixture-repo guided-violation`, prompt identical to Task 1's (tags `[basic-review, guidelines]`), plus:

`graders/skill-fired.md` — identical pattern to Task 1's (`basic-review`).

`graders/cites-guideline.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

REVIEW_GUIDELINES.yaml pins area money-cents on app.py: monetary math is
integer cents; percentages are basis-point integers, never float fractions.
The diff adds refund() computing `total * (pct_bp / 10000)` — float
fractions — while remaining functionally correct.

PASS if the reply flags refund against the pinned rule AND names the
guideline: the id `money-cents`, the area name, or a verbatim quote of the
rule text.

FAIL if the reply does not flag refund's float math, or flags it with no
connection to the pinned guideline (generic "avoid floats" advice).

Boundary ruling: flagging refund as a correctness bug does not fail this
grader as long as the guideline is named. Using the exact `(Guideline:
money-cents)` citation format is welcome but NOT required to pass.
```

`graders/no-bleed.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

The readme-voice area is scoped to README.md, which the diff does not touch,
and refund() has a docstring stating units.

PASS if the reply raises no finding about README.md, the docstring, or
anything other than the money-cents violation.

FAIL if the reply applies the README rule outside its glob or invents
findings.
```

`evals/review-guidelines-clean/` — same wiring with `guided-clean`, prompt identical (tags `[basic-review, guidelines-clean]`), graders: `skill-fired.md` (identical) and `no-guideline-findings.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

The diff adds refund_cents(), which follows the pinned money-cents rule
exactly (integer cents in, basis-point percentage, integer division out) and
carries a units docstring. README.md is untouched.

PASS if the reply reports no findings (any honest "no findings worth fixing"
phrasing), or at most notes that the diff conforms to the guidelines.

FAIL if the reply presents any finding, blocker, or must-fix item — including
presenting the guidelines file itself as missing, stale, or wrong.
```

- [ ] **Step 3: Write the PREREG (commit before any run)**

`evals/reports/2026-10-07-review-guidelines-PREREG.md` — same structure as Task 1's, with: provenance = auggie `plugin_marketplace/code-review/commands/local.md` Step 2 (fetched 2026-10-07) + the schema/citation adapted to a tool-neutral root file; intervention = the "Repository review guidelines (opt-in contract)" subsection (full text in the plan, inserted after the Task 1 conventions subsection if Task 1 adopted, else after "What earns a finding"); cases table (`review-guidelines` primary, `review-guidelines-clean` precision control, `review-clean` + `review-calibration` unchanged regression guards); fairness rule identical in shape; thresholds: price run $3 cap (abort > $2.50), baseline $8, change $8, ≤ $19 total; firing ≥ 2/3 both arms; **primary = mean of cites-guideline + no-bleed + no-guideline-findings; adopt if primary ≥ +0.15 AND no grader across the four cases regresses ≥ 0.34 AND `no-false-positive` and `no-guideline-findings` each do not regress at all AND firing gate holds;** declared untested limits: the invalid-YAML fallback and glob-scoping edge cases are defensive text guarded only by the regression cases (no fixture exercises them); if E2 adopts, a follow-up case may pin them; same stated limits as Task 1. Dependency note: this experiment runs after Task 1's decision, and its PREREG records Task 1's outcome (adopted/reverted) so the baseline state is unambiguous.

- [ ] **Step 4: Commit PREREG + cases BEFORE any run**

```bash
git add evals/_lib/review-fixture.sh evals/review-guidelines evals/review-guidelines-clean evals/reports/2026-10-07-review-guidelines-PREREG.md
git commit -m "evals: pre-register the review-guidelines A/B (two fixture modes, two cases, PREREG) before any comparative run"
```

- [ ] **Step 5: Price-calibration run**

Run: `claude plugin eval . --case review-guidelines --runs 1 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 3 --json evals/results/guidelines-price.json`
Expected: 1 run; if > $2.50 → abort per PREREG.

- [ ] **Step 6: Baseline run**

Run: `claude plugin eval . --case 'review-*' --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 8 --json evals/results/guidelines-baseline.json`
Expected: 12 runs — `review-*` matches exactly the five cases that exist at this point (review-guidelines, review-guidelines-clean, review-conventions, review-clean, review-calibration).

- [ ] **Step 7: Apply the intervention**

In `skills/basic-review/SKILL.md`, directly after the Task 1 subsection (or after "What earns a finding" if Task 1 was rejected), insert:

```markdown
### Repository review guidelines (opt-in contract)

If the repo root contains `REVIEW_GUIDELINES.yaml`, load it and apply it as an
extension of this review. Match each changed path against every area's
`globs`; only rules of matching areas apply. Cite a guideline-sourced finding
as `(Guideline: <area-id>)` after the severity tag. If the file is absent,
unreadable, or invalid YAML, continue without it and never treat that as a
finding. Guideline rules can only add findings (the repo pinned them) or name
the house fix for a default finding — they never loosen the bar above. Judge
relevance like any other finding: a pinned rule this repo no longer follows in
practice, or one the diff's context makes inapplicable, is worth at most a
one-line aside — never a finding.

Schema (areas with `id`, `globs`, `rules`; `globs` defaults to `["**"]`):

```yaml
areas:
  - id: money-cents
    globs: ["app.py", "src/billing/**"]
    rules:
      - "Monetary math is integer cents; no float fractions."
```
```

- [ ] **Step 8: Change run**

Same command as Step 6 with `--json evals/results/guidelines-change.json`. Expected: 12 runs.

- [ ] **Step 9: Decide against the gates, bump or revert**

ADOPT → `version: 1.3.0` → `1.4.0` (or 1.2.0 → 1.3.0 if Task 1 was rejected). REJECT → `git restore skills/basic-review/SKILL.md`.

- [ ] **Step 10: Commit**

```bash
git add skills/basic-review/SKILL.md
git commit -m "evals: review-guidelines A/B for /basic-review — REVIEW_GUIDELINES.yaml opt-in contract (auggie import: glob-scoped areas, guideline naming in findings); <ADOPTED: version →X.Y.Z | REJECTED: reverted>; <primary Δ, guards unregressed>"
```

---

### Task 3: Experiment 3 — clean-code ambition bar ("code judo")

**Files:**
- Create: `evals/_lib/cleancode-fixture.sh`
- Create: `evals/cleancode-judo/{case.yaml,fixture.sh,prompt.md,graders/*.md}`
- Create: `evals/reports/2026-10-07-cleancode-judo-PREREG.md`
- Modify (gated): `skills/clean-code/SKILL.md`

- [ ] **Step 1: Write the fixture builder**

`evals/_lib/cleancode-fixture.sh` (a sourced lib, same shape as `review-fixture.sh`; idempotent, subshell). The yaml branch **rewrites `exporters.py` in full** (base content + `export_yaml` + `_esc_yaml` + the `yaml` branch in `Dispatcher.export`) so the planted diff is green — `clean-code` refuses to work on a red suite:

```bash
#!/usr/bin/env bash
# cleancode_fixture <dir>: builds the exporters repo for the clean-code judo
# eval. Base: three near-identical export functions (csv/json/xml) each
# re-implementing row handling, behind a one-method Dispatcher. Diff: adds
# export_yaml as a fourth copy wired into the Dispatcher. The judo move: one
# spec-driven exporter replacing all four (a per-format table deletes the
# duplication category); the smallest-fix is only extracting a shared helper.
# Tests pin behavior for all formats + the unknown-format error.
cleancode_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: cleancode_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"
  cd "$dir" || exit 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture
  cat > exporters.py <<'EOF'
def _validate(rows):
    out = []
    for row in rows:
        if not isinstance(row, dict):
            raise TypeError("rows must be dicts")
        out.append({str(k): "" if v is None else str(v) for k, v in row.items()})
    return out


def _esc_csv(value):
    value = str(value)
    if any(c in value for c in ",\"\n"):
        return '"' + value.replace('"', '""') + '"'
    return value


def _esc_xml(value):
    return (str(value).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;"))


def export_csv(rows):
    rows = _validate(rows)
    if not rows:
        return ""
    headers = list(rows[0].keys())
    lines = [",".join(_esc_csv(h) for h in headers)]
    for row in rows:
        lines.append(",".join(_esc_csv(row.get(h, "")) for h in headers))
    return "\n".join(lines)


def export_json(rows):
    rows = _validate(rows)
    import json as _json
    return _json.dumps(
        [{h: row.get(h, "") for h in (list(rows[0].keys()) if rows else [])}
         for row in rows] if rows else [])


def export_xml(rows):
    rows = _validate(rows)
    lines = ["<rows>"]
    for row in rows:
        lines.append("  <row>")
        for h in (list(rows[0].keys()) if rows else []):
            lines.append(f"    <{h}>{_esc_xml(row.get(h, ''))}</{h}>")
        lines.append("  </row>")
    lines.append("</rows>")
    return "\n".join(lines)


class Dispatcher:
    """Routes a format name to its export function."""

    def export(self, fmt, rows):
        if fmt == "csv":
            return export_csv(rows)
        if fmt == "json":
            return export_json(rows)
        if fmt == "xml":
            return export_xml(rows)
        raise ValueError(f"unknown format: {fmt}")
EOF
  cat > test_exporters.py <<'EOF'
import pytest
from exporters import Dispatcher

ROWS = [{"id": 1, "name": 'Ann, "A"'}, {"id": 2, "name": "Bob"}]

@pytest.mark.parametrize("fmt", ["csv", "json", "xml"])
def test_roundtrip_fields(fmt):
    out = Dispatcher().export(fmt, ROWS)
    assert "Ann" in out and "Bob" in out

def test_unknown_format_raises():
    with pytest.raises(ValueError):
        Dispatcher().export("parquet", ROWS)
EOF
  git add -A && git commit -qm "base: csv/json/xml exporters"
  git switch -qc feature/export-yaml
  # --- the diff under review: a fourth format as a fourth copy (committed on
  # the feature branch so clean-code's Step 1.4 clean-tree precondition holds
  # without a user to ask) ---
  cat > exporters.py <<'EOF'
def _validate(rows):
    out = []
    for row in rows:
        if not isinstance(row, dict):
            raise TypeError("rows must be dicts")
        out.append({str(k): "" if v is None else str(v) for k, v in row.items()})
    return out


def _esc_csv(value):
    value = str(value)
    if any(c in value for c in ",\"\n"):
        return '"' + value.replace('"', '""') + '"'
    return value


def _esc_xml(value):
    return (str(value).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;"))


def _esc_yaml(value):
    value = str(value)
    return '"' + value.replace('"', '\\"') + '"' if any(
        c in value for c in ':,"\n') else value


def export_csv(rows):
    rows = _validate(rows)
    if not rows:
        return ""
    headers = list(rows[0].keys())
    lines = [",".join(_esc_csv(h) for h in headers)]
    for row in rows:
        lines.append(",".join(_esc_csv(row.get(h, "")) for h in headers))
    return "\n".join(lines)


def export_json(rows):
    rows = _validate(rows)
    import json as _json
    return _json.dumps(
        [{h: row.get(h, "") for h in (list(rows[0].keys()) if rows else [])}
         for row in rows] if rows else [])


def export_xml(rows):
    rows = _validate(rows)
    lines = ["<rows>"]
    for row in rows:
        lines.append("  <row>")
        for h in (list(rows[0].keys()) if rows else []):
            lines.append(f"    <{h}>{_esc_xml(row.get(h, ''))}</{h}>")
        lines.append("  </row>")
    lines.append("</rows>")
    return "\n".join(lines)


def export_yaml(rows):
    rows = _validate(rows)
    lines = ["---"]
    for row in rows:
        lines.append("- " + ", ".join(
            f"{h}: {_esc_yaml(row.get(h, ''))}"
            for h in (list(rows[0].keys()) if rows else [])))
    return "\n".join(lines)


class Dispatcher:
    """Routes a format name to its export function."""

    def export(self, fmt, rows):
        if fmt == "csv":
            return export_csv(rows)
        if fmt == "json":
            return export_json(rows)
        if fmt == "xml":
            return export_xml(rows)
        if fmt == "yaml":
            return export_yaml(rows)
        raise ValueError(f"unknown format: {fmt}")
EOF
  cat >> test_exporters.py <<'EOF'

def test_yaml_roundtrip_fields():
    out = Dispatcher().export("yaml", ROWS)
    assert "Ann" in out and "Bob" in out

def test_yaml_dispatcher():
    out = Dispatcher().export("yaml", [{"id": 1, "name": "Ann"}])
    assert out.startswith("---")
EOF
  git add -A && git commit -qm "feature: add yaml exporter as a fourth copy"
  )
}
```

**Verify before committing:** source the lib, build into a `/tmp` dir, and assert: 2 commits (`feature: …` on top of `base: csv/json/xml exporters`), `git status --porcelain` is EMPTY (clean-code Step 1.4 refuses a dirty tree and there is no user to ask), and `pytest -q` passes on HEAD (6 tests — the planted diff must be green or `clean-code` Step 1.3 exits). Delete the temp dir.

- [ ] **Step 2: Write the case**

`evals/cleancode-judo/case.yaml` (`name: cleancode-judo`, `scaffold_script: fixture.sh`), `fixture.sh` sourcing the new lib, `prompt.md`:

```markdown
---
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill, Edit, Write]
tags: [clean-code, judo]
---

The repo under review is at ./fixture-repo (a small exporters library with a pytest suite). Clean up the changes on this branch before I ship.
```

`graders/skill-fired.md` — pattern `'"skill"\s*:\s*"(?:[\w-]+:)?clean-code"'`.

`graders/names-judo.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

The diff adds export_yaml as a fourth copy of the per-format export
functions. The structural reframe available: one spec-driven exporter — a
per-format table (serialize function + headers rule) with a single export()
loop — deletes the whole category of per-format copies and can swallow the
one-method Dispatcher. The smaller fix (extract one shared escaping helper)
leaves the four-copies shape intact.

PASS if the reply NAMES the structural reframe (a spec/table-driven single
exporter replacing the per-format copies, or equivalent language about
deleting the per-format category / making the Dispatcher disappear), whether
or not it applies it.

FAIL if the reply tops out at the smaller fix (extract-a-helper, dedupe two
lines) with no structural reframe named anywhere.

Boundary ruling: naming the reframe and then deliberately applying the
smaller fix, recording the reframe as deferred with its content written out,
PASSES — the measured thing is seeing the reframe. Applying the reframe
behavior-preservingly with a green suite also PASSES.
```

`graders/behavior-preserved.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

The fixture's pytest suite pins behavior: every format round-trips its fields
and an unknown format raises ValueError.

PASS if the reply reports the suite green on the final HEAD (or, if no fix
was applied, reports the suite still green), and no behavior change is made
or claimed.

FAIL if fixes are claimed without a green-suite report, or a behavior change
is introduced (unknown format no longer raises, output contract broken).
```

`graders/diff-scoped.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

Only exporters.py and test_exporters.py are in the diff.

PASS if the reply's fixes touch nothing beyond the diff's files (plus
characterization tests for code it restructures).

FAIL if unrelated modules or the base commit's behavior were "improved" while
here.
```

- [ ] **Step 3: Write the PREREG (commit before any run)**

`evals/reports/2026-10-07-cleancode-judo-PREREG.md` — same structure: provenance = cursor/plugins `thermos/skills/thermo-nuclear-code-quality-review/SKILL.md` (fetched 2026-10-07); intervention = the "Ambition bar" subsection (full text in Step 7) inserted at the end of `## Step 2: Audit`, which explicitly resolves the tension with the "Smallest safe refactor" hard rule (smallest is the default fix; the reframe is recorded and may be applied only when behavior-preserving, test-covered, and strictly simpler); the fixture commits the diff on a feature branch so Step 1.4's clean-tree precondition holds without a user to ask, and the measured thing is SEEING the reframe (audit quality — applying it is optional and suite-gated); cases: `cleancode-judo` primary; fairness rule identical in shape; thresholds: price run `--max-cost-usd 6` (abort > $5), baseline $15, change $15 (≤ $36); firing ≥ 2/3 both arms; **primary = mean of names-judo + behavior-preserved + diff-scoped; adopt if names-judo ≥ +0.15 AND primary ≥ +0.10 AND behavior-preserved does not regress at all AND diff-scoped does not regress ≥ 0.34 AND firing gate holds;** limits as before.

- [ ] **Step 4: Commit PREREG + case BEFORE any run**

```bash
git add evals/_lib/cleancode-fixture.sh evals/cleancode-judo evals/reports/2026-10-07-cleancode-judo-PREREG.md
git commit -m "evals: pre-register the clean-code judo A/B (exporters fixture, case, PREREG) before any comparative run"
```

- [ ] **Step 5: Price-calibration run**

Run: `claude plugin eval . --case cleancode-judo --runs 1 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 6 --json evals/results/judo-price.json`
Expected: 1 run; if > $5 → abort per PREREG.

- [ ] **Step 6: Baseline run**

Run: `claude plugin eval . --case cleancode-judo --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 15 --json evals/results/judo-baseline.json`
Expected: 3 runs.

- [ ] **Step 7: Apply the intervention**

In `skills/clean-code/SKILL.md`, at the end of `## Step 2: Audit (report-only discovery)` (before the "Also note" paragraph), insert:

```markdown
### Ambition bar (the audit's second question)

Alongside the signals above, ask one more question per changed file: **is
there a reframe that deletes a whole category of complexity?** The smallest
safe refactor stays the default fix; it is not an excuse to leave a better
structure unreported.

- **Code judo:** a re-organization that uses the existing architecture so the
  change gets dramatically simpler — whole branches, helpers, modes, or
  layers disappear instead of being tidied. Prefer the version that feels
  inevitable in hindsight.
- **Size smell:** a diff pushing a file from under 1000 lines over 1000 needs
  a strong reason; name the decomposition you would apply first.
- **Spaghetti growth:** new ad-hoc conditionals or special cases bolted onto
  an unrelated flow are a design finding, not a style nit — push the logic
  into the abstraction that owns it.
- **Canonical layer:** logic living outside the module/layer that owns the
  concept, or a bespoke helper where a canonical one exists, is a finding —
  the fix moves or reuses, not re-implements.

Record these as `JUDO — file:line — the reframe — what it deletes`. A JUDO
finding may be applied as the fix when it is behavior-preserving, covered by
tests (characterization test first, like any other fix), and strictly simpler
— fewer concepts, not more movement. If it is bigger than the diff's own risk
budget, leave it UNFIXED with the reframe written out so the author can
decide. A visible reframe that goes unreported is a miss. The ambition bar
ships as four rules; the fixture measures the reframe dimension — size-smell,
spaghetti-growth, and canonical-layer ride as declared-unmeasured, guarded by
the behavior-preserved and diff-scoped graders.
```

- [ ] **Step 8: Change run**

Same command as Step 6 with `--json evals/results/judo-change.json`. Expected: 3 runs.

- [ ] **Step 9: Decide against the gates**

ADOPT → `skills/clean-code/SKILL.md` frontmatter `version: 1.0.0` → `1.1.0`. REJECT → `git restore skills/clean-code/SKILL.md`.

- [ ] **Step 10: Commit**

```bash
git add skills/clean-code/SKILL.md
git commit -m "evals: cleancode-judo A/B for /clean-code — ambition bar (thermos code-judo import: reframe reporting, 1k-line smell, spaghetti-growth, canonical layer); <ADOPTED: version 1.0.0→1.1.0 | REJECTED: reverted>; <names-judo Δ, guards unregressed>"
```

---

### Task 4: Experiment 4 — vendor `cli-for-agent` (cursor/plugins, MIT)

**Ordering rule for this task:** `claude plugin eval .` loads skills from the repo working tree — a skill directory that is present but uncommitted still fires. So the baseline run happens on a tree with **no** `skills/cli-for-agent/` directory at all, and the skill is created only after the baseline. Do not create the file early.

**Files:**
- Create: `evals/_lib/cli-fixture.sh`, `evals/cli-agents-quality/{case.yaml,fixture.sh,prompt.md,graders/*.md}`
- Create: `evals/reports/2026-10-07-cli-for-agent-PREREG.md`
- Create: `skills/cli-for-agent/SKILL.md` (Step 6, after the baseline run)
- Run: `./setup` (new skill is invisible without it)

- [ ] **Step 1: Write the fixture and case**

`evals/_lib/cli-fixture.sh`:

```bash
#!/usr/bin/env bash
# cli_fixture <dir>: builds the book-inventory repo for the cli-for-agent eval.
# Base: inventory.py (Book dataclass, in-memory store, JSON load/save) +
# README specifying the shelfy CLI. The agent's task is to BUILD the CLI, so
# the fixture ships the library and spec, not the CLI. Domain deliberately
# disjoint from the skill's mycli/deploy examples (anti-leakage).
cli_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: cli_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"
  cd "$dir" || exit 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture
  cat > inventory.py <<'EOF'
import json
from dataclasses import dataclass, asdict


@dataclass
class Book:
    isbn: str
    title: str
    genre: str
    rating: int  # 1-5


class Inventory:
    def __init__(self):
        self._books = []

    def add(self, book):
        if any(b.isbn == book.isbn for b in self._books):
            raise ValueError(f"duplicate isbn: {book.isbn}")
        self._books.append(book)

    def by_genre(self, genre):
        return [b for b in self._books if b.genre == genre]

    def save(self, path):
        with open(path, "w") as f:
            json.dump([asdict(b) for b in self._books], f, indent=2)

    @classmethod
    def load(cls, path):
        inv = cls()
        with open(path) as f:
            for row in json.load(f):
                inv.add(Book(**row))
        return inv
EOF
  cat > README.md <<'EOF'
# shelfy

Personal book inventory. The `inventory.py` module holds the logic; we need a
command-line interface named `shelfy` (runnable as `python -m shelfy`) exposing:
add a book by ISBN/title/genre/rating, list books filtered by genre, export the
inventory to a JSON file, and initialize a new inventory file.
EOF
  git add -A && git commit -qm "base: inventory library + shelfy spec"
  )
}
```

**Verify before committing:** source the lib, build into a `/tmp` dir, and assert: one commit; `python3 -c "from inventory import Inventory, Book"` imports clean; the README names the four commands. Delete the temp dir.

`evals/cli-agents-quality/case.yaml` (`name: cli-agents-quality`, `scaffold_script: fixture.sh`), `fixture.sh` sourcing the lib, `prompt.md`:

```markdown
---
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill, Write, Edit]
tags: [cli-for-agent, quality]
---

The repo at ./fixture-repo needs the `shelfy` CLI built (spec in its README, logic in inventory.py). Build it so both humans and coding agents can drive it, then show me the evidence: the `--help` output, what a missing-required-flag run prints, and what a successful `add` prints.
```

`graders/skill-fired.md` — pattern `'"skill"\s*:\s*"(?:[\w-]+:)?cli-for-agent"'`.

`graders/non-interactive.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

The shelfy CLI was just built (or reviewed) in the fixture.

PASS if every input the CLI takes is expressible as a flag/argument shown in
the evidence (add takes isbn/title/genre/rating as flags or args; list takes
--genre; export takes --out; init takes its path) and nothing in the shown
evidence requires arrow keys, menus, or a timed prompt.

FAIL if any shown flow requires an interactive prompt before it can run, or
inputs are only documented as "you will be asked".
```

`graders/help-examples.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

PASS if the shown --help (top-level or subcommand) includes at least one
Example section with real, copy-pasteable invocations of the actual commands
(add/list/export/init with real-looking values) — not just option
descriptions.

FAIL if the help shows only option lists with no example invocations, or the
evidence shows no help output at all.
```

`graders/errors-actionable.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

PASS if the shown missing-required-flag run exits immediately with an error
message that includes (or is followed by the agent showing) a correct example
invocation of the command — the user can copy it, fix the argument, and run
again.

FAIL if the error is bare ("missing argument"), hangs waiting for input, or
shows no error evidence at all.
```

`graders/repeat-safe.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

PASS if the CLI's design shown in the evidence is idempotent-safe or
guarded: a repeated `add` of the same ISBN is rejected or explicitly reported
as already-present (the library raises on duplicate isbn — the CLI must not
silently double-add), and any destructive action (export overwriting an
existing file, init overwriting an existing inventory) is previewable
(--dry-run or equivalent) or guarded.

FAIL if the evidence shows destructive actions with no preview/guard, or a
duplicate add silently overwrites/duplicates.
```

- [ ] **Step 2: Write the PREREG (commit before any run)**

`evals/reports/2026-10-07-cli-for-agent-PREREG.md` — same structure: provenance = cursor/plugins `cli-for-agent` (MIT, vendored with attribution and `metadata.upstream`); intervention = the new skill itself (tree gains `skills/cli-for-agent/` + its `./setup` link); cases: `cli-agents-quality` primary + `offtopic-no-skill` as the global negative guard (must stay clean in the treatment arm — the new skill must not fire off-topic); fairness: graders grade the shown evidence, never skill vocabulary; graders see the **final message only**, so the prompt explicitly demands the evidence be shown in the reply (`--help` output, the missing-flag error run, the success output) — a build whose evidence lives only in tool calls scores 0 on the outcome graders; this prompt-shape dependency is declared here rather than discovered later; the fixture domain (book inventory) is disjoint from the skill's `mycli deploy` examples (anti-leakage per `evals/METHODOLOGY.md`); thresholds: price run `--max-cost-usd 5` (abort > $4), baseline $12, change $12 (≤ $29); **primary = mean of the four outcome graders; adopt if primary ≥ +0.15 AND firing gate holds in the treatment arm (skill fires ≥ 2/3; if it fires < 2/3 the experiment is void — the skill is unreachable, report and revisit the description, do not adopt) AND `offtopic-no-skill` records no skill-firing in the treatment arm AND no outcome grader regresses ≥ 0.34** (a baseline run can pass a grader without the skill — the gates catch a skill that makes the CLI *worse*); rider declaration: the skill ships whole and the four graders sample its highest-risk patterns (non-interactive, help examples, actionable errors, idempotency) — the remaining sections (stdin/pipelines, discoverability, predictable structure, success output) are guarded only by the regression cases; limits as before.

- [ ] **Step 3: Commit PREREG + case BEFORE any run**

```bash
git add evals/_lib/cli-fixture.sh evals/cli-agents-quality evals/reports/2026-10-07-cli-for-agent-PREREG.md
git commit -m "evals: pre-register the cli-for-agent A/B (fixture, case, PREREG) before the baseline run; skill vendored separately after"
```

- [ ] **Step 4: Price-calibration run**

Run: `claude plugin eval . --case cli-agents-quality --runs 1 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 5 --json evals/results/cli-price.json`
Expected: 1 run; if > $4 → abort per PREREG.

- [ ] **Step 5: Baseline run (tree without the skill)**

Run (two invocations — `--case` takes a single glob and these two case names share no prefix):

```bash
claude plugin eval . --case cli-agents-quality --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 9 --json evals/results/cli-baseline.json
claude plugin eval . --case offtopic-no-skill --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 3 --json evals/results/cli-baseline-offtopic.json
```

Expected: 6 runs total. First confirm the tree has no skill directory: `test ! -e skills/cli-for-agent` (the ordering rule at the top of this task).

- [ ] **Step 6: Vendor the skill**

Create `skills/cli-for-agent/SKILL.md`:

````markdown
---
name: cli-for-agent
version: 1.0.0
description: |
  Design or review CLIs so coding agents can run them reliably: non-interactive
  flags first, layered --help with real copy-pasteable examples, stdin/pipeline
  support, fail-fast errors that include a correct invocation, idempotency,
  --dry-run/--yes for destructive actions, and machine-useful success output.
  Use when building a CLI, adding commands or subcommands, writing --help
  text, or when asked for an "agent-friendly CLI". Not for GUIs, TUIs, or
  library APIs (no CLI surface to design).
metadata.upstream: https://github.com/cursor/plugins (cli-for-agent/skills/cli-for-agents, MIT)
triggers:
  - agent-friendly cli
  - cli for agents
  - build a cli
  - add a subcommand
  - write --help
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# /cli-for-agent

Human-oriented CLIs block agents: interactive prompts, huge upfront docs, and
help text without copy-pasteable examples. Prefer patterns that work headlessly
and compose in pipelines.

## Non-interactive first

- Every input should be expressible as a flag or flag value. Do not require
  arrow keys, menus, or timed prompts.
- If flags are missing, **then** fall back to interactive mode — not the other
  way around.

**Bad:** `mycli deploy` → `? Which environment? (use arrow keys)`
**Good:** `mycli deploy --env staging`

## Discoverability without dumping context

- Agents discover subcommands incrementally: `mycli`, then `mycli deploy
  --help`. Do not print the entire manual on every run.
- Let each subcommand own its documentation so unused commands stay out of
  context.

## `--help` that works

- Every subcommand has `--help`.
- Every `--help` includes **Examples** with real invocations. Examples do more
  than prose for pattern-matching.

```text
Options:
  --env     Target environment (staging, production)
  --tag     Image tag (default: latest)
  --force   Skip confirmation

Examples:
  mycli deploy --env staging
  mycli deploy --env production --tag v1.2.3
  mycli deploy --env staging --force
```

## stdin, flags, and pipelines

- Accept stdin where it makes sense (e.g. `cat config.json | mycli config
  import --stdin`).
- Avoid odd positional ordering and avoid falling back to interactive prompts
  for missing values.
- Support chaining: `mycli deploy --env staging --tag $(mycli build --output
  tag-only)`.

## Fail fast with actionable errors

- On missing required flags: exit immediately with a clear message and a
  **correct example invocation**, not a hang.

```text
Error: No image tag specified.
  mycli deploy --env staging --tag <image-tag>
  Available tags: mycli build list --output tags
```

## Idempotency

- Agents retry often. The same successful command run twice should be safe
  (no-op or explicit "already done"), not duplicate side effects.

## Destructive actions

- Add `--dry-run` (or equivalent) so agents can preview plans before
  committing.
- Offer `--yes`/`--force` to skip confirmations while keeping the safe default
  for humans.

## Predictable structure

- Use a consistent pattern everywhere, e.g. `resource` + `verb`: if `mycli
  service list` exists, `mycli deploy list` and `mycli config list` should
  follow the same shape.

## Success output

- On success, return machine-useful data: IDs, URLs, durations. Plain text is
  fine; avoid relying on decorative output alone.

```text
deployed v1.2.3 to staging
url: https://staging.myapp.com
deploy_id: dep_abc123
duration: 34s
```

## When reviewing an existing CLI

- Check: non-interactive path, layered help, examples on `--help`,
  stdin/pipeline story, error messages with invocations, idempotency,
  dry-run, confirmation bypass flags, consistent command structure,
  structured success output.

---

Adapted from [cursor/plugins](https://github.com/cursor/plugins)
`cli-for-agent/skills/cli-for-agents/SKILL.md` (MIT, © Cursor). Vendored per
the superskills imported-skills rule; changes here do not track upstream.
````

- [ ] **Step 7: Link, validate, and commit the skill**

Run: `./setup && claude plugin validate . && ./tests/run.sh` (root plugin validation stays **non-strict** — the accepted CLAUDE.md-at-root warning becomes an error under `--strict`, and `tests/plugin-manifests.bats` owns that contract)
Expected: all pass (includes `tests/skills-host-neutral.bats` over the new skill and the manifest tests). Fix any frontmatter complaint before proceeding; do not skip setup — the treatment arm cannot fire the skill without its link.

```bash
git add skills/cli-for-agent
git commit -m "skills: vendor cli-for-agent from cursor/plugins (MIT) — agent-usable CLI patterns; measured by the cli-agents-quality A/B before adoption is decided"
```

- [ ] **Step 8: Treatment run**

Same two invocations as Step 5 with `--json evals/results/cli-change.json` and `--json evals/results/cli-change-offtopic.json`. Expected: 6 runs total, skill-fired ≥ 2/3 on the primary case.

- [ ] **Step 9: Decide against the gates**

ADOPT → keep the skill (no frontmatter bump yet; Task 7 ships it). REJECT → `git rm -r skills/cli-for-agent && ./setup` and record the null (the case, fixture, PREREG and report stay either way).

- [ ] **Step 10: Commit the decision**

```bash
git commit --allow-empty -m "evals: cli-for-agent A/B verdict — <ADOPTED: skill kept | REJECTED: skill removed, null recorded>; <primary Δ over four graders; firing X/3; offtopic clean/dirty>"
```

---

### Task 5: Experiment 5 — new `diff-walkthrough` skill (cursor pr-review-canvas techniques, markdown)

**Ordering rule for this task:** `claude plugin eval .` loads skills from the repo working tree, so the baseline run happens on a tree with **no** `skills/diff-walkthrough/` directory; the skill is created in Step 6, after the baseline.

**Files:**
- Create: `evals/_lib/walkthrough-fixture.sh`, `evals/walkthrough-pricing/{case.yaml,fixture.sh,prompt.md,graders/*.md}`
- Create: `evals/reports/2026-10-07-diff-walkthrough-PREREG.md`
- Create: `skills/diff-walkthrough/SKILL.md` (Step 6, after the baseline run)

- [ ] **Step 1: Write the fixture and case**

`evals/_lib/walkthrough-fixture.sh`:

```bash
#!/usr/bin/env bash
# walkthrough_fixture <dir>: builds the pricing repo for the diff-walkthrough
# eval. Base: compute_total applies 8% tax then a flat $10 member discount;
# routes.py wires /checkout; models.py holds helpers. Feature branch (the diff
# to walk through): (core) compute_total now applies the $10 member discount
# BEFORE tax — for base 100, member: old (100+8)-10 = 98.00, new
# (100-10)*1.08 = 97.20, a real $0.80 divergence (a multiplicative discount
# would be order-insensitive — probe-verified trap, do not "simplify" back);
# (wiring) routes.py registers /refund; (boilerplate) models.py renames
# cust->customer and reorders imports. Domain disjoint from the skill's
# core.py/routes.py validator example (anti-leakage).
walkthrough_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: walkthrough_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"
  cd "$dir" || exit 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture
  cat > pricing.py <<'EOF'
TAX_RATE = 0.08
MEMBER_DISCOUNT_USD = 10.00


def compute_total(base_price, member=False):
    """Old policy: flat $10 member discount applied after tax."""
    subtotal = base_price * (1 + TAX_RATE)
    if member:
        subtotal -= MEMBER_DISCOUNT_USD
    return round(subtotal, 2)
EOF
  cat > routes.py <<'EOF'
HANDLERS = {}


def route(path):
    def register(fn):
        HANDLERS[path] = fn
        return fn
    return register


@route("/checkout")
def checkout(payload):
    from pricing import compute_total
    return {"total": compute_total(payload["base_price"],
                                  payload.get("member", False))}
EOF
  cat > models.py <<'EOF'
import json


def cust_ref(cust):
    return {"id": cust["id"], "name": cust["name"]}


def dump(rows):
    return json.dumps(rows)
EOF
  git add -A && git commit -qm "base: checkout pricing"
  git switch -qc feature/member-discount
  cat > pricing.py <<'EOF'
TAX_RATE = 0.08
MEMBER_DISCOUNT_USD = 10.00


def compute_total(base_price, member=False):
    """New policy: flat $10 member discount applied before tax."""
    subtotal = base_price
    if member:
        subtotal -= MEMBER_DISCOUNT_USD
    return round(subtotal * (1 + TAX_RATE), 2)
EOF
  cat >> routes.py <<'EOF'


@route("/refund")
def refund(payload):
    from pricing import compute_total
    owed = compute_total(payload["base_price"], payload.get("member", False))
    return {"refund": round(max(payload["paid"] - owed, 0.0), 2)}
EOF
  cat > models.py <<'EOF'
import json


def customer_ref(customer):
    return {"id": customer["id"], "name": customer["name"]}


def dump(rows):
    return json.dumps(rows)
EOF
  git add -A && git commit -qm "feature: member discount before tax, refund route, rename"
  )
}
```

**Verify before committing:** source the lib, build into a `/tmp` dir, and assert: 2 commits with `feature: …` on top; the divergence is REAL by direct evaluation — load `pricing.py` from the base commit and from the working tree and confirm `compute_total(100, member=True)` returns `98.0` old vs `97.2` new (a multiplicative discount makes both orders identical at 97.2 — the probe that caught this is why this check exists); `git diff main...HEAD --stat` lists all three files. Delete the temp dir.

`evals/walkthrough-pricing/case.yaml` (`name: walkthrough-pricing`, `scaffold_script: fixture.sh`), `fixture.sh` sourcing the lib, `prompt.md`:

```markdown
---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [diff-walkthrough, comprehension]
---

Walk me through the changes on this branch in ./fixture-repo — I was out and need to catch up on what happened here.
```

`graders/skill-fired.md` — pattern `'"skill"\s*:\s*"(?:[\w-]+:)?diff-walkthrough"'`.

`graders/core-first.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

The branch mixes three kinds of change: the pricing-policy change (core),
the /refund route registration (wiring), and a rename + import reformat in
models.py (boilerplate).

PASS if the pricing change is presented with the most depth and appears
before (or is clearly separated from) the mechanical rename/reformat, and the
rename/reformat is summarized rather than shown as full hunks.

FAIL if the reply walks files in path order with equal depth, or leads with
the rename, or dumps every hunk equally.
```

`graders/traces-divergence.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

The pricing change reorders discount and tax: for base_price 100 with member
true, the old code returns 98.00 ((100 + 8) − 10: 8% tax first, then the flat
$10 discount) and the new code returns 97.20 ((100 − 10) × 1.08: discount
first, then tax on the discounted amount) — a 0.80 difference every member
checkout will see. (The discount is a flat dollar amount precisely so the
order matters; a multiplicative discount would make both orders identical.)

PASS if the reply surfaces this old-vs-new divergence with a concrete input
(a number like 100 walked through both orders, or the equivalent stated
outcome difference). PASS also if it states the general rule ("the discount
now applies before tax, so members pay tax on the discounted amount instead
of getting the discount off the taxed total") with an illustrative number.

FAIL if the reply describes the change only as "discount moved before tax"
with no concrete outcome, input, or order-of-operations consequence — the
thing a returning reader most needs is what a member's total now does.
```

`graders/wiring-connected.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

PASS if the reply mentions the new /refund route as wiring (registered into
the same handler table as /checkout) at least briefly, rather than omitting
it or presenting it as core logic.

FAIL if /refund is absent from the walkthrough, or gets a full hunk-by-hunk
treatment equal to the pricing change.
```

- [ ] **Step 2: Write the PREREG (commit before any run)**

`evals/reports/2026-10-07-diff-walkthrough-PREREG.md` — same structure: provenance = cursor/plugins `pr-review-canvas` (MIT; canvas layer dropped, markdown conventions adapted); intervention = the new skill; cases: `walkthrough-pricing` primary (+ `offtopic-no-skill` negative guard); fairness: graders grade presentation structure and trace content, never skill vocabulary; fixture domain (pricing/tax) disjoint from the skill's examples (validator/routes — anti-leakage); thresholds: price run `--max-cost-usd 5` (abort > $4), baseline $12, change $12 (≤ $29); **primary = mean of the three outcome graders; adopt if primary ≥ +0.15 AND traces-divergence ≥ +0.15 AND firing gate holds in the treatment arm (≥ 2/3; below that the experiment is void — revisit the description, do not adopt) AND `offtopic-no-skill` stays clean AND no outcome grader regresses ≥ 0.34**; rider declaration: the skill ships whole and the three graders sample its highest-risk behaviors (section ordering, divergence tracing, wiring connection) — pseudocode distillation, tricky-tags, and the ask-when-ambiguous rule are guarded only by the regression cases; limits as before.

- [ ] **Step 3: Commit PREREG + case BEFORE any run**

```bash
git add evals/_lib/walkthrough-fixture.sh evals/walkthrough-pricing evals/reports/2026-10-07-diff-walkthrough-PREREG.md
git commit -m "evals: pre-register the diff-walkthrough A/B (pricing fixture, case, PREREG) before the baseline run"
```

- [ ] **Step 4: Price-calibration run**

Run: `claude plugin eval . --case walkthrough-pricing --runs 1 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 5 --json evals/results/walkthrough-price.json`
Expected: 1 run; if > $4 → abort per PREREG.

- [ ] **Step 5: Baseline run (tree without the skill)**

Run (two invocations — the two case names share no prefix):

```bash
claude plugin eval . --case walkthrough-pricing --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 9 --json evals/results/walkthrough-baseline.json
claude plugin eval . --case offtopic-no-skill --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 3 --json evals/results/walkthrough-baseline-offtopic.json
```

Expected: 6 runs total. First confirm the tree has no skill directory: `test ! -e skills/diff-walkthrough` (the ordering rule at the top of this task).

- [ ] **Step 6: Write the skill**

Create `skills/diff-walkthrough/SKILL.md`:

````markdown
---
name: diff-walkthrough
version: 1.0.0
description: |
  Present a changeset for comprehension: reorganize the diff by reviewer value
  (core logic first, wiring condensed, boilerplate summarized), distill dense
  hunks into pseudocode, trace surprising behavior changes on a concrete
  input, and tag the few genuinely tricky hunks. Use when asked to "walk me
  through the diff/PR", "explain what changed", or to catch someone up on a
  branch. Not a review: it explains, it does not judge — for findings use
  /review (or /basic-review), for quality use /clean-code.
triggers:
  - walk me through the diff
  - walk me through this pr
  - explain what changed
  - catch me up on this branch
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# /diff-walkthrough

Present a changeset reorganized for reviewer comprehension — not in file-tree
order, not a raw diff dump. This skill explains what happened; it does not
review. Findings belong to `/review` or `/basic-review`.

## Gather the diff

Accept a branch, a range, staged/uncommitted changes, or a PR reference (with
`gh pr diff` when the remote is reachable). **If the user did not say which
changeset they mean, stop and ask.** Never guess from recent history or fall
back to a silent default — a walkthrough of the wrong diff is worse than no
walkthrough.

## Group changes for comprehension

Do **not** present files in alphabetical or tree order. Reorganize into
sections ordered by reviewer value:

1. **Core logic** — new behavior, algorithm changes, state transitions, API
   surface changes. Show the real hunks with surrounding context.
2. **Wiring & integration** — route registration, dependency injection, config
   plumbing that connects the core logic. Condensed: enough to confirm
   correctness.
3. **Boilerplate & mechanical** — renames, import reordering, generated code,
   formatting, type re-exports. Summarize as a list of files and stats; no
   inline hunks unless something is genuinely surprising there.

Lead with core logic: attention is freshest at the top.

## Distill dense logic into pseudocode

When a core hunk is dense — nested conditions, state machines, retry/backoff,
multi-step transforms — add a few lines of pseudocode next to it that strip
syntax and error handling to expose the essential control flow. Only for hunks
that are genuinely hard to scan; straightforward changes need no mirror.

## Trace surprising behavior on a concrete example

When a hunk changes behavior in a way that is hard to predict from reading it
— reordered operations, new short-circuits, altered edge cases — pick one
small, realistic input and walk it through the old and new code paths
side by side, highlighting the step where they diverge and the observable
outcome. Reserve this for genuinely surprising changes.

## Call attention to tricky things — sparingly

When a hunk hides something risky or easy to miss, mark it with a short tag
(`Subtle`, `Breaking`, `Race condition`, `Perf`) and one sentence. Overuse
destroys the signal; a few tags per walkthrough is the ceiling.

## Tone

Write reviewer-facing commentary, not a changelog: **why** it changed, how
files interact ("the new validator in core.py is invoked by the route added
in routes.py"), anything the diff alone does not make obvious. One or two
sentences per note. No findings, no verdicts, no "LGTM".

---

Adapted from [cursor/plugins](https://github.com/cursor/plugins)
`pr-review-canvas/skills/pr-review-canvas/SKILL.md` (MIT, © Cursor) — the
canvas-SDK presentation layer replaced with markdown conventions.
````

- [ ] **Step 7: Link, validate, and commit the skill**

```bash
./setup && claude plugin validate . && ./tests/run.sh
git add skills/diff-walkthrough
git commit -m "skills: diff-walkthrough — changeset comprehension presentation (pr-review-canvas techniques, markdown adaptation); measured by the walkthrough-pricing A/B before adoption is decided"
```

- [ ] **Step 8: Treatment run**

Same two invocations as Step 5 with `--json evals/results/walkthrough-change.json` and `--json evals/results/walkthrough-change-offtopic.json`. Expected: 6 runs total, skill-fired ≥ 2/3.

- [ ] **Step 9: Decide against the gates**

ADOPT → keep the skill. REJECT → `git rm -r skills/diff-walkthrough && ./setup`, record the null.

- [ ] **Step 10: Commit the decision**

```bash
git commit --allow-empty -m "evals: diff-walkthrough A/B verdict — <ADOPTED: skill kept | REJECTED: skill removed, null recorded>; <primary Δ; traces-divergence Δ; firing X/3; offtopic clean/dirty>"
```

---

### Task 6: Experiment 6 — qa-full cross-check synthesis rules (runs last: weakest prior, highest cost, hard abort)

**Files:**
- Create: `evals/_lib/qaful-synthesis-fixture.sh`
- Create: `evals/qaful-synthesis/{case.yaml,fixture.sh,prompt.md,graders/*.md}`
- Create: `evals/reports/2026-10-07-qaful-synthesis-PREREG.md`
- Modify (gated): `skills/qa-full/SKILL.md`

- [ ] **Step 1: Write the fixture builder**

`evals/_lib/qaful-synthesis-fixture.sh` (modeled on `qa-full-fixture.sh`'s shape — plain Node, `node --test`, a `CLAUDE.md` qa-full section with no Codex/pentest/browser triggers — but planting exactly one two-surface root cause, so the pipeline stays cheap):

```bash
#!/bin/bash
# qaful_synthesis_fixture <dir>: builds the Node repo for the qa-full
# synthesis eval. Feature branch adds src/invoice.js whose lineTotal()
# duplicates cart.js's per-item math but floors per line — a divergence
# invisible to single-item tests (suite green), flagged by /review (or
# /basic-review) as correctness and by /clean-code as DRY: one root cause,
# two check surfaces. No secrets, no SQL, no browser, no DB triggers.
set -e
D="$1"; rm -rf "$D"; mkdir -p "$D"; cd "$D"
git init -q -b main; git config user.email qa@example.test; git config user.name "QA Fixture"
cat > package.json <<'J'
{ "name": "invoicefix", "version": "1.0.0", "private": true, "type": "commonjs",
  "scripts": { "test": "node --test" } }
J
cat > CLAUDE.md <<'M'
# invoicefix

Plain Node (no dependencies, no build step). Tests use the built-in runner.

## qa-full

- Test/build: `npm test` (there is no build step)
- Dev URL: none. There is no dev server for this project.
- Codex passes: do not use Codex for this project.
- /pentest: not authorized for this project.
M
mkdir -p src tests
cat > src/cart.js <<'J'
// Money math for carts. Prices are dollars; totals are exact sums.
function itemTotal(item) {
  return item.price * item.qty;
}
function cartTotal(items) {
  return items.reduce((sum, i) => sum + itemTotal(i), 0);
}
module.exports = { itemTotal, cartTotal };
J
cat > tests/cart.test.js <<'J'
const test = require('node:test');
const assert = require('node:assert');
const { cartTotal, itemTotal } = require('../src/cart');
test('sums price times quantity', () => {
  assert.strictEqual(cartTotal([{ price: 2, qty: 3 }, { price: 5, qty: 1 }]), 11);
});
test('item total is exact', () => {
  assert.strictEqual(itemTotal({ price: 19.99, qty: 3 }), 59.97);
});
J
printf 'node_modules\n' > .gitignore
git add -A; git commit -qm "base: cart totals"
git switch -qc feature/invoice
cat > src/invoice.js <<'J'
const { itemTotal } = require('./cart');

// Per-line totals for invoices. Floors each line to whole cents.
function lineTotal(item) {
  return Math.floor(item.price * item.qty * 100) / 100;
}
function invoiceTotal(items) {
  return items.reduce((sum, i) => sum + lineTotal(i), 0);
}
function renderInvoice(items) {
  return items.map(i => `- ${i.qty} x ${i.price} = ${lineTotal(i)}`).join("\n");
}
module.exports = { lineTotal, invoiceTotal, renderInvoice };
J
cat > tests/invoice.test.js <<'J'
const test = require('node:test');
const assert = require('node:assert');
const { invoiceTotal } = require('../src/invoice');
test('single item invoice matches cart math on integers', () => {
  assert.strictEqual(invoiceTotal([{ price: 2, qty: 3 }]), 6);
});
J
git add -A; git commit -qm "feature: invoice rendering with per-line flooring"
```

**Verify before committing:** run the script into a `/tmp` dir and assert: current branch is `feature/invoice`; `node --test` passes (the planted diff must be green); `git diff main...HEAD --stat` lists `src/invoice.js` + `tests/invoice.test.js`; `src/invoice.js` requires `itemTotal` from `./cart` (the reuse seam the DRY finding points at). Delete the temp dir.

(The plant: `lineTotal` duplicates `itemTotal`'s math and floors per line — a correctness divergence from `cart.js`'s exact-sum contract that single-integer-item tests cannot see, plus a textbook DRY finding. `/review`/`/basic-review` and `/clean-code` each naturally surface one face of the same root cause.)

- [ ] **Step 2: Write the case**

`evals/qaful-synthesis/` — `case.yaml` (`name: qaful-synthesis`, `scaffold_script: fixture.sh`), plus a case-local `fixture.sh` that **invokes** the standalone lib (it is a script with `set -e`, not a sourced function like the review libs):

```bash
#!/bin/bash
bash "$(dirname "$0")/../_lib/qaful-synthesis-fixture.sh" ./fixture-repo
```

`prompt.md`:

```markdown
---
max_turns: 25
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Bash, Skill, Edit, Write]
tags: [qa-full, synthesis]
---

Run the full pre-ship QA pipeline on the current branch of ./fixture-repo.
```

`graders/skill-fired.md` — pattern `'"skill"\s*:\s*"(?:[\w-]+:)?qa-full"'`.

`graders/synthesis-present.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

The fixture's feature branch plants one root cause with two faces: lineTotal()
in src/invoice.js both duplicates cart.js's itemTotal math (a DRY surface that
/clean-code flags) and introduces a per-line floor that diverges from cart.js's
exact-sum contract (a correctness surface that /review or /basic-review flags).
The two findings share one fix: reuse the canonical per-item math (and drop the
floor or make it explicit), not two independent repairs.

PASS if the reply's report/ledger connects the two surfaces: the duplication
and the flooring are fixed together or cross-referenced as one root cause,
OR the overlapping finding is explicitly weighted/merged in the synthesis
(one item cited to both checks).

FAIL if the correctness fix and the DRY fix appear as unrelated items (e.g.
the floor is "fixed" in place while the duplication remains flagged, or the
duplication is extracted while the floor silently survives in the new helper).

Boundary ruling: extracting ONE shared helper that both fixes the floor AND
removes the duplication, cited once, is the ideal PASS. Two commits with an
explicit "same root cause as the review finding" ledger note also PASS.
```

`graders/verdict-discipline.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

PASS if the reply's verdict follows the qa-full contract: SHIP-READY only with
a fresh green test run on final HEAD and every triggered check accounted in
the ledger; blockers (if any) listed with file:line evidence and what was
tried; no "ready" claim while a triggered check is unaccounted.

FAIL if the verdict claims SHIP-READY with a red or unrun suite, or the
ledger is missing while the verdict asserts ready.
```

- [ ] **Step 3: Write the PREREG (commit before any run)**

`evals/reports/2026-10-07-qaful-synthesis-PREREG.md` — same structure: provenance = cursor/plugins `thermos` orchestrator (fetched 2026-10-07); overlap note: the 2026-10-05 plan rejected a qa-full *accounting* experiment because the ledger exists — this measures the *synthesis* rule the ledger lacks (verified: `skills/qa-full/SKILL.md` Step 3 has no merge/dedup/weight instruction between the two passes); intervention = the "Cross-check against the correctness pass" block (full text in Step 7) inserted at the end of Step 3, after the `/clean-code` paragraph and before the `/code-review ultra` paragraph — reconciling `/clean-code`'s report against `/review`'s applied fixes (the two passes' fix rounds are sequential, so the finding lists never coexist); cases: `qaful-synthesis` primary; fairness identical in shape; thresholds: **price run `--max-cost-usd 8` (abort > $6.50 — qa-full fan-out cost is unmeasured; this is the experiment's kill switch), baseline `--max-cost-usd 20`, change `--max-cost-usd 20` (≤ $48); primary = mean of synthesis-present + verdict-discipline; adopt if primary ≥ +0.15 AND synthesis-present ≥ +0.15 AND verdict-discipline does not regress at all AND firing gate ≥ 2/3 both arms;** limits: same-day drift + the fallback path (`/review` may be unavailable in-sandbox, in which case `/basic-review` runs — graders are written to accept either path); limits as before.

- [ ] **Step 4: Commit PREREG + case BEFORE any run**

```bash
git add evals/_lib/qaful-synthesis-fixture.sh evals/qaful-synthesis evals/reports/2026-10-07-qaful-synthesis-PREREG.md
git commit -m "evals: pre-register the qa-full synthesis A/B (fixture, case, PREREG) before any comparative run"
```

- [ ] **Step 5: Price-calibration run**

Run: `claude plugin eval . --case qaful-synthesis --runs 1 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 8 --json evals/results/qaful-price.json`
Expected: 1 run; **if > $6.50 → abort per PREREG: keep the case, record the price in the consolidated report, skip the experiment** (this is the expected abort path if the fan-out is expensive). Mechanism note: the harness checks `--max-cost-usd` before each run and aborts with exit 2 plus partial results (verified against `claude plugin eval --help`); a cap-tripped run's scores read 0 for unexecuted graders — check `cases[].arms.*[].error` before reading any Δ.

- [ ] **Step 6: Baseline run**

Run: `claude plugin eval . --case qaful-synthesis --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 20 --json evals/results/qaful-baseline.json`
Expected: 3 runs.

- [ ] **Step 7: Apply the intervention**

In `skills/qa-full/SKILL.md`, at the end of `## Step 3: Correctness + quality — /review then /clean-code (always)` (after the `/clean-code` paragraph, before the `/code-review ultra` paragraph), insert the "Cross-check against the correctness pass" block (full text follows). Sequencing note (verified against the existing Step 3 text): `/review` runs and its fix rounds complete BEFORE `/clean-code` starts, so the two finding lists never coexist — the intervention reconciles `/clean-code`'s report against `/review`'s applied fixes at `/clean-code`'s report time, before its fix round.

```markdown
**Cross-check against the correctness pass.** When `/clean-code` reports its
findings, reconcile them with what `/review` (or `/basic-review`) already
fixed before its pass ended. The ledger keeps one row per check — this rule is
about the FINDINGS, not the rows:

- A `/clean-code` finding whose root cause `/review` already fixed is the same
  root cause: finish it once if residue remains (e.g. the DRY fix completes
  the correctness fix), cite both checks in the row's evidence, and never
  repair one defect twice or leave it half-connected.
- Overlapping findings are fixed first: two independent checks landing on the
  same code is evidence it is the highest-risk spot in the diff.
- A disagreement (one pass flags what the other fixed or passed) is resolved
  by evidence — re-read the code, decide, and record the ruling in the ledger
  row. Never split the difference.
```

- [ ] **Step 8: Change run**

Same command as Step 6 with `--json evals/results/qaful-change.json`. Expected: 3 runs.

- [ ] **Step 9: Decide against the gates**

ADOPT → bump `skills/qa-full/SKILL.md` frontmatter `version: 2.0.1` → `2.1.0`. REJECT → `git restore skills/qa-full/SKILL.md`.

- [ ] **Step 10: Commit**

```bash
git add skills/qa-full/SKILL.md
git commit -m "evals: qaful-synthesis A/B for /qa-full — cross-check synthesis (thermos import: dedupe one-root-cause findings, weight overlaps, resolve disagreements by evidence); <ADOPTED: version 2.0.1→2.1.0 | REJECTED: reverted>; <primary Δ; firing X/3>"
```

---

### Task 7: Consolidated report, ship-if-adopted, final validation

**Files:**
- Create: `evals/reports/2026-10-07-external-adoption.md`
- Modify (only if anything adopted): `VERSION`, manifests via `./scripts/sync-version.sh`, `README.md` badge

- [ ] **Step 1: Write the consolidated report**

`evals/reports/2026-10-07-external-adoption.md`: one verdict row per experiment (E1–E6) with actual per-grader means, Δs, gate outcomes, and costs (each number cites its results JSON path or report file); the rejected-up-front list restated with reasons; the aborts actually taken; total spend. No new claims without a citation.

- [ ] **Step 2: Ship or stop**

If NOTHING adopted: commit the report, stop — no VERSION bump:

```bash
git add evals/reports/2026-10-07-external-adoption.md
git commit -m "evals: consolidated external-adoption report — <summary of nulls>; no skill changes shipped"
```

If ANYTHING adopted: bump `VERSION` to the next minor from whatever it reads at ship time (2.38.1 → **2.39.0** as of this plan's writing — new skills and/or significant behavior updates = minor per CLAUDE.md), run `./scripts/sync-version.sh`, update the README version badge, run `./setup` (new skills from Tasks 4–5), then one commit:

```bash
git add VERSION README.md .claude-plugin .codex-plugin .cursor-plugin
git commit -m "release <VERSION> — <one line per adopted change>; VERSION bumped, manifests stamped, README badge"
```

Then the release goes through the repo's own gate — `/finish-branch` → `/ship` per `DEVELOPER_WORKFLOW.md` (a human approves the merge; the release owner re-reads `main` before bumping if parallel work landed).

- [ ] **Step 3: Final validation**

Run: `./tests/run.sh && claude plugin validate . && claude plugin validate marketing-skills`
Expected: all pass (root validation stays **non-strict** — the accepted CLAUDE.md-at-root warning becomes an error under `--strict`, per `tests/plugin-manifests.bats`). If validate fails on new eval-case frontmatter (unknown keys), fix the frontmatter to the schema the existing cases use — do not delete cases to make validate pass.

---

## Test Plan & Verification

**Coverage target:** 100% of new deterministic artifacts are exercised before any paid run — every fixture lib builds and its case scaffold runs (`--scaffold` does this at eval time; fixture correctness is also spot-checked by `bash -n` and one manual scaffold per lib before the price run), every grader file parses under the house frontmatter shape, both new skills pass `tests/skills-host-neutral.bats` + `claude plugin validate --strict`. Every behavioural change ships only through an experiment whose PREREG was committed before its first comparative run (verifiable by commit timestamps), with the pre-registered gates actually executed.

**Critical paths (must pass before ship):**
- Each experiment: PREREG commit precedes the baseline run; adopt/revert matches the gates verbatim; the decision commit states the actual Δ
- New-skill path (Tasks 4–5): `./setup` links the skill → skill fires in the treatment arm (≥ 2/3) → `offtopic-no-skill` stays clean
- Release path (only if adopted): `VERSION` bump → `./scripts/sync-version.sh` → README badge → `./tests/run.sh` → `claude plugin validate --strict .` + `marketing-skills`

**Edge cases & error paths:**
- Missing/unparseable `REVIEW_GUIDELINES.yaml` → review proceeds without it, never a finding (grader: `no-guideline-findings` FAIL clause + PREREG)
- Conventions file present but diff conforms → no findings invented (grader: `no-convention-bleed`)
- Conforming guidelines diff → nothing flagged, guidelines file itself not reported as an issue (grader: `no-guideline-findings` boundary ruling)
- New skill unreachable in treatment arm → experiment void, description revisited, nothing adopted (PREREG firing gates, Tasks 4–5)
- Price overruns → per-PREREG abort paths ($2.50 / $2.50 / $5 / $4 / $4 / $6.50) skip the experiment, keep cases, report the price
- Usage-limit or rate-limit errors score 0 and look like regressions → check `cases[].arms.*[].error` before trusting a Δ (`evals/RUBRIC.md` known limits)

**Regression guards:**
- `review-clean` (`no-false-positive`) and `review-calibration` (four graders) must not regress in Tasks 1–2 (pre-registered)
- `behavior-preserved` must not regress at all in Task 3; `diff-scoped` not ≥ 0.34
- `offtopic-no-skill` must stay clean in Tasks 4–5 treatment arms
- `verdict-discipline` must not regress at all in Task 6
- `./tests/run.sh` green after every task; `basic-review.bats` (checklist parity) untouched by these edits but re-run anyway

**Verification commands:**
- Unit/lint: `./tests/run.sh` — expected: all pass
- Plugin shape: `claude plugin validate --strict . && claude plugin validate --strict marketing-skills` — expected: both pass
- Behavioural: the exact per-experiment commands above, each with its `--max-cost-usd` cap — expected: gates evaluated verbatim from the PREREGs

**Acceptance criteria (from spec):**
- [ ] "Implement one at a time, measured against baseline" → six sequential experiments, each a single intervention with a fresh paired baseline (Tasks 1–6), no parallel arms
- [ ] "Adopt only what beats baseline" → every adoption passes its pre-registered gates (primary ≥ +0.15 or the stated sub-gate shape, no regression ≥ 0.34, targeted graders not regressed, firing-power ≥ 2/3); everything else is reverted and reported as a null
- [ ] "Test and evaluate" → every experiment: committed PREREG + cases → price calibration → baseline n=3 → intervention → change n=3 → gate decision → decision commit stating the Δ; judge stays sonnet
- [ ] "All six ideas" → E1 conventions (vercel-labs), E2 guidelines file (auggie), E3 judo (thermos), E4 cli-for-agent (cursor), E5 diff-walkthrough (pr-review-canvas), E6 synthesis (thermos) — one task each; overlaps with already-adopted technique excluded by the research table
- [ ] Nulls are real answers → rejected experiments keep cases + PREREGs + negative-result commits; aborts are reported, not hidden

---

## Eng Review Record (2026-10-07)

Review of this plan by `/plan-eng-review` (native pass + bounded probes + codex outside voice). Scope Challenge: the six-idea, one-at-a-time, adopt-on-measured-improvement structure is the user's explicit instruction for this plan (session message 2026-10-07) and matches the recorded precedent from the 2026-10-05 review of `2026-10-05-codex-eval-gated-adoption.md` ("structure kept at original arrangement per the user's standing instructions — recorded as prior approval, cited, not re-asked"). Scope accepted as-is; no cuts proposed.

### Findings (all folded into the plan above; confidence per the calibration format)

| # | Finding | Source | Disposition |
|---|---|---|---|
| F1 | [P1] (9/10) Task 5 walkthrough fixture: multiplicative discount is order-insensitive — old == new == 97.2, no divergence to trace. Caught by executing the fixture (probe). | Test review (probe) | Fixed: flat $10 member discount → old 98.00, new 97.20; grader text updated; per-task fixture-verify steps added |
| F2 | [P1] (9/10) Multi-`--case` flags do not accumulate — `--case` takes a single glob (verified against `claude plugin eval --help`; matches the 2026-10-06 calibration report's note). Tasks 1–2 baseline/change commands were broken as written. | Architecture (probe) | Fixed: `--case 'review-*'` for Tasks 1–2; split invocations for Tasks 4–5 |
| F3 | [P1] (9/10, codex) Task 6 synthesis block contradicted qa-full's sequencing: `/review`'s fix rounds complete before `/clean-code` starts, so the two finding lists never coexist; "merge before the fix rounds" was unimplementable as written. | Outside voice | Fixed: block rewritten as "Cross-check against the correctness pass" (reconcile `/clean-code`'s report against `/review`'s applied fixes); ledger's one-row-per-check contract preserved; sequencing note added |
| F4 | [P1] (9/10, codex) Task 3 fixture left a dirty tree — `clean-code` Step 1.4 refuses to work without a user to ask, and the eval grants no AskUserQuestion. | Outside voice | Fixed: diff committed on `feature/export-yaml`; prompt says "changes on this branch"; verify step asserts empty `git status --porcelain` |
| F5 | [P2] (8/10) Task 6 case-local `fixture.sh` was specified as "sourcing the lib" but the lib is a standalone script — the scaffold would no-op. | Code quality | Fixed: explicit shim invocation |
| F6 | [P2] (8/10, codex) E1/E2 interventions let a pinned rule override the style-skip bar with no relevance guard; fixtures never test a stale convention. | Outside voice | Fixed: relevance clause added to both interventions ("worth at most a one-line aside"); `no-convention-bleed` FAIL extended; untested limits (invalid YAML, glob edges) declared in the E2 PREREG |
| F7 | [P2] (8/10, codex) `claude plugin validate --strict .` is known to fail (accepted CLAUDE.md-at-root warning; `tests/plugin-manifests.bats` owns the contract). Inherited from the 2026-10-05 plan. | Outside voice | Fixed: root validation non-strict in Tasks 4/5/7 |
| F8 | [P2] (8/10, codex) Task 5's refund handler could produce negative refunds and its unused `compute_total` import mislabeled wiring. | Outside voice | Fixed: handler recomputes the member total via `compute_total` and clamps at zero |
| F9 | [P2] (8/10, codex) Adoption gates certified unmeasured additions (riders, untested ambition rules, untested skill sections). | Outside voice | Declared: rider declarations added to E3/E4/E5/E6 PREREGs (ships-whole, graders sample highest-risk patterns, remainder guarded by regression cases) |
| F10 | [P2] (8/10) Task 7 hardcoded VERSION 2.39.0 (stale if releases land meanwhile) and omitted the repo's PR/review ship gate. | Code quality / Outside voice | Fixed: "next minor from whatever VERSION reads at ship time"; `/finish-branch` → `/ship` with human approval added |
| F11 | [P3] (7/10) Task 4 fixture's `shelfy_goal.txt` marker was YAGNI; Task 4 outcome graders depend on evidence appearing in the final message (prompt mitigates). | Code quality | Fixed (marker removed); prompt-shape dependency declared in the E4 PREREG |

### Failure modes
Fixture silently building a wrong state → per-task verify steps (bash -n + build + asserts) added after probe evidence showed one real instance (F1). Paid-run contamination by an uncommitted skill directory → ordering rules + `test ! -e` guards in Tasks 4–5. Cost-cap abort misread as regression → exit-2 mechanism noted in Task 6. No silent-failure critical gaps remain.

### What already exists (reused, not rebuilt)
`evals/_lib/review-fixture.sh` (extended, not duplicated), `offtopic-no-skill` (negative guard for Tasks 4–5), `qa-full-fixture.sh` shape (copied for the synthesis fixture, deliberately not shared — coupling the closed routing work's fixture was rejected), `tests/skills-host-neutral.bats` + `tests/plugin-manifests.bats` (new-skill gates), PREREG/arms/gates methodology (2026-10-05/06 reports).

### NOT in scope
Structured-guidelines parser script (agent reads YAML at runtime), invalid-YAML/glob-edge fixture case (deferred until/unless E2 adopts), vendored-skill malice-scan pipeline, diff-size caps, pstack-style micro-skills, community-plugins scan infra (rejected-up-front table above).

### Implementation Tasks
Synthesized from this review's findings. Each task derives from a specific finding above. Run with Claude Code or Codex; checkbox as you ship.

- [ ] **T1 (P1, human: ~1h / CC: ~10min)** — Tasks 1–2 — execute Experiments 1–2 exactly as written (fixture modes, PREREG-first, glob commands, gates)
  - Surfaced by: Architecture F2; Test review F1 (probe method)
  - Files: evals/_lib/review-fixture.sh, evals/review-conventions/, evals/review-guidelines{,-clean}/, skills/basic-review/SKILL.md
  - Verify: gates evaluated verbatim; decision commits state actual deltas
- [ ] **T2 (P1, human: ~1h / CC: ~10min)** — Task 3 — execute Experiment 3 (committed-diff fixture, clean-tree precondition, judo gates)
  - Surfaced by: Outside voice F4
  - Files: evals/_lib/cleancode-fixture.sh, evals/cleancode-judo/, skills/clean-code/SKILL.md
  - Verify: pytest green on HEAD; gates verbatim
- [ ] **T3 (P1, human: ~2h / CC: ~30min)** — Tasks 4–5 — vendored/new-skill experiments (create-after-baseline ordering, firing gates, offtopic guard)
  - Surfaced by: Architecture (baseline contamination rule); Outside voice F8/F9
  - Files: skills/cli-for-agent/, skills/diff-walkthrough/, evals/cli-agents-quality/, evals/walkthrough-pricing/
  - Verify: skill fires ≥2/3 in treatment; offtopic clean; validate non-strict passes
- [ ] **T4 (P2, human: ~1h / CC: ~20min)** — Task 6 — qa-full synthesis experiment with hard price abort
  - Surfaced by: Outside voice F3
  - Files: evals/_lib/qaful-synthesis-fixture.sh, evals/qaful-synthesis/, skills/qa-full/SKILL.md
  - Verify: price run ≤ $6.50 else abort; gates verbatim
- [ ] **T5 (P2, human: ~30min / CC: ~10min)** — Task 7 — consolidated report, single minor release through /finish-branch → /ship
  - Surfaced by: Outside voice (ship gate); F10
  - Files: evals/reports/2026-10-07-external-adoption.md, VERSION, manifests, README badge
  - Verify: ./tests/run.sh + validate . + validate marketing-skills; human-approved merge

Sequential implementation by design (one experiment at a time per the user's instruction); no parallelization opportunity. No unresolved decisions. Costs require the user's per-experiment go-ahead (money rule).

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| Outside Review | codex exec (read-only) via /plan-eng-review | Independent 2nd opinion | 1 | completed | 7 findings, all verified against tree and folded |
| Eng Review | /plan-eng-review | Architecture & tests (required) | 1 | issues_open | 6 issues (2 architecture, 3 code quality, 1 test gap), all folded into the plan |

**OUTSIDE COVERAGE:** codex (read-only sandbox), plan-review phase, completed; 7 findings (F3, F4, F6–F10 + ship gate), every one verified against the repository before folding.

**CROSS-MODEL:** native review + codex agree on F10 (ship gate) and the rider-declaration gap (F9); codex alone caught the qa-full sequencing contradiction (F3) and the clean-tree precondition (F4); the native pass alone caught the fixture math and single-glob bugs via probes (F1, F2).

**VERDICT: ENG REVIEWED — 11 findings total (native + outside), all folded; plan ready for execution behind the pre-registered gates; eng review required at ship time if the plan changes materially.**

NO UNRESOLVED DECISIONS
