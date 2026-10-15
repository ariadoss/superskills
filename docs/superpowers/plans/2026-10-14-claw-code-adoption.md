# Claw-Code Adoption (continuity rules + skill-tree lint) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt the four highest-value techniques from the claw-code study (2026-10-14) into superskills — compaction-discipline rules for `/handoff` and `/quota-resilience`, the verification-nudge rule for `/verify` + `/finish-branch`, the one-sentence subagent delegation contract in DEVELOPER_WORKFLOW — and add a mechanical skill-tree lint (name/dir drift, duplicate names, missing descriptions), each skill-body change measured by a pre-registered A/B eval before it ships.

**Architecture:** Two independent halves sharing one branch. Part A is unmeasured tooling/docs: a pure lint library in `scripts/lib/` (reusing `skills-lib.sh` parsers) plus a thin runner, bats-tested, with a live-repo zero-findings assertion; two conventions added to ENGINEERING_STANDARDS; the delegation contract added to DEVELOPER_WORKFLOW. Part B is the measured behaviour edits: three new eval cases + a PREREG are committed first (instruments before runs), the baseline arm runs on the un-edited skills, the four SKILL.md edits land as the intervention, the change arm runs, and pre-registered gates decide adopt-or-revert per skill.

**Tech Stack:** bash 3.2-compatible shell + bats (repo standard), markdown skill bodies, `claude plugin eval` A/B arms (spends model money — approval-gated tasks below).

**Provenance note:** the techniques are behavioral rules observed in the MIT-licensed `ultraworkers/claw-code` Rust reimplementation of the Claude Code harness (studied 2026-10-14). All text below is written fresh in superskills' own voice; nothing is pasted from that codebase.

---

## Scope

**In (this plan):**

| Item | Lands in | Measured? |
|---|---|---|
| Flat-rewrite + supersede rules | `skills/handoff/SKILL.md` | A/B (`handoff-rewrite` case) |
| Flat-fold + resume-directly rules | `skills/quota-resilience/SKILL.md` | A/B (`quota-resume-direct` case) |
| Verification-nudge rule | `skills/verify/SKILL.md`, `skills/finish-branch/SKILL.md` | A/B (`verify-todolist` case) |
| One-sentence subagent contract + multi-`in_progress` note | `DEVELOPER_WORKFLOW.md` | declared-unmeasured rider (docs, no eval instrument) |
| name==dirname + description-steering conventions | `ENGINEERING_STANDARDS.md` | mechanically enforced by the new lint |
| Skill-tree lint (lib + runner + bats, live-repo assertion) | `scripts/lib/skills-lint.sh`, `scripts/lint-skills.sh`, `tests/skills-lint.bats` | bats |
| Dead eval-case husk cleanup | `evals/handoff-resume-mid-refactor-A/` (empty dir) | — |

**Out (deliberately, with reasons — do not smuggle these in):**

- `/pr-triage` skill from claw-code's `anti-slop-triage.md` — a new skill is a product decision with its own spec, not an adoption edit.
- Deterministic mock-parity eval harness, `MODEL_COMPATIBILITY.md` quirk ledger, prompt-cache forensics doc — methodology extensions; separate proposals.
- Secret-redaction utility — **YAGNI**: no current consumer persists transcript/tool output (the three hooks in `hooks/hooks.json` don't; the quota resume wrapper logs only to a per-user dir on the user's own machine). Revisit if a transcript-sharing artifact ever lands.
- `schema_version` stamping on machine artifacts — already satisfied where it matters (`evals/*/case.yaml` carries `schema_version: "1.1"`); no other script emits consumed JSON.
- Retrofitting the claw-code error-string contract onto existing scripts — applied day-one to the **new** lint's output only; a retrofit sweep is separate cleanup.

**Trust boundaries:** none crossed. Fixtures are local synthetic git repos; eval prompts are synthetic; no credentials, no network, no new integrations. (The eval runs themselves are ordinary `claude plugin eval` usage.)

## File Structure

| File | Responsibility (SRP) |
|---|---|
| Create `scripts/lib/skills-lint.sh` | Pure lint predicates: one `_lint_emit` formatter (the error contract) + `lint_name_dir` + `lint_dup_names` + `lint_descriptions`. No I/O beyond reading SKILL.md paths given to it. |
| Create `scripts/lint-skills.sh` | Thin runner: walks this repo's three skill trees, calls the lib, aggregates exit code. Owns the "which tree gets which check" policy (marketing is nested-by-design, so no name==dir there). |
| Create `tests/skills-lint.bats` | Fixture tests for every predicate + the runner's clean/dirty paths + the live-repo zero-findings assertion. |
| Create `evals/handoff-rewrite/{prompt.md,fixture.sh,case.yaml,graders/}` | Instrument: note-rewrite quality (flat, superseded state dropped). |
| Create `evals/quota-resume-direct/{prompt.md,fixture.sh,case.yaml,graders/}` | Instrument: resume-directly behavior (no ack/recap/preface). |
| Create `evals/verify-todolist/{prompt.md,fixture.sh,case.yaml,graders/}` | Instrument: verification nudge (missing verify item named + fresh evidence before claims). |
| Create `evals/reports/2026-10-14-claw-continuity-PREREG.md` | Pre-registered intervention, fairness rules, endpoints, adopt/reject gates. Committed before any run. |
| Create `evals/reports/2026-10-14-claw-continuity.md` | Post-run analysis + per-skill verdicts. |
| Modify `skills/handoff/SKILL.md` | +2 rules (flat rewrite, supersede) in Step 2. |
| Modify `skills/quota-resilience/SKILL.md` | flat-fold sentence in Phase 1 rule 3; new Phase 2 step 1 (resume directly). |
| Modify `skills/verify/SKILL.md` | +1 Common Failures row, +1 Key Pattern block. |
| Modify `skills/finish-branch/SKILL.md` | +task-list check in Step 1, +1 Red Flags "Always" bullet. |
| Modify `DEVELOPER_WORKFLOW.md` | delegation contract sentence + multi-in_progress note in the delegation block. |
| Modify `ENGINEERING_STANDARDS.md` | +2 skill-authoring conventions. |
| Delete `evals/handoff-resume-mid-refactor-A/` | empty husk (no `prompt.md`, empty `graders/`). |
| Modify `VERSION`, `README.md` (badge) | release stamp at ship time. |

**DRY:** the lint reuses `skill_name_from`, `skill_desc_from`, `skill_names_from_files`, and `marketing_skill_files` from `scripts/lib/skills-lib.sh` — the same parsers the linker uses, so lint and linker can never disagree about what a name is. `quota-resume-direct` reuses `evals/_lib/quota-fixture.sh`. The new eval cases copy grader *shapes* from `evals/quota-*` (per-suite convention; the README notes the harness has no shared-grader mechanism).

**SOLID:** lib predicates are pure (stdin paths / stdout findings), so bats tests them hermetically; the runner owns only policy + exit code. **YAGNI:** the cuts listed above; no `--fix` flag (the repo's read-only culture: lint names the fix, a human/agent applies it).

---

## Part A — tooling and docs (no eval spend)

### Task 0: Branch and green baseline

**Files:** none (git only).

- [ ] **Step 1: Confirm clean tree and current suite is green before anything else**

```bash
cd /Users/danilosapad/Sites/superskills
git status --porcelain          # expected: empty
git fetch origin
git checkout -b adoption/claw-code origin/main
./tests/run.sh                  # expected: all pass (baseline count recorded in output)
```

- [ ] **Step 2: Commit the plan file itself**

```bash
git add docs/superpowers/plans/2026-10-14-claw-code-adoption.md
git commit -m "plan: claw-code adoption — continuity rules + skill-tree lint"
```

### Task 1: `scripts/lib/skills-lint.sh` — the lint predicates (TDD)

**Files:**
- Create: `scripts/lib/skills-lint.sh`
- Test: `tests/skills-lint.bats`

- [ ] **Step 1: Write the failing tests**

Create `tests/skills-lint.bats`:

```bats
#!/usr/bin/env bats
# skills-lint — the skill-tree lint checks (name/dir drift, duplicate
# frontmatter names, missing descriptions), hermetic over fixture trees,
# plus the runner's clean/dirty paths and the live-repo assertion.

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  # shellcheck source=../../scripts/lib/skills-lib.sh
  . "$REPO_ROOT/scripts/lib/skills-lib.sh"
  # shellcheck source=../../scripts/lib/skills-lint.sh
  . "$REPO_ROOT/scripts/lib/skills-lint.sh"
  FIX="$BATS_TEST_TMPDIR/tree"
  ROOT="$BATS_TEST_TMPDIR/root"
  mkdir -p "$FIX" "$ROOT"
}

_make_skill() { # <dir> <name> [description] — relative to $FIX
  _make_skill_at "$FIX/$1" "$2" "${3:-}"
}

_make_skill_at() { # <dir> <name> [description] — absolute
  mkdir -p "$1"
  {
    printf -- '---\nname: %s\n' "$2"
    [ -n "${3:-}" ] && printf 'description: %s\n' "$3"
    printf -- '---\n\nbody\n'
  } > "$1/SKILL.md"
}

@test "name-dir: clean flat tree emits nothing" {
  _make_skill alpha alpha "does alpha things"
  _make_skill beta beta "does beta things"
  out="$(lint_name_dir "$FIX")" || false
  [ -z "$out" ] || false
}

@test "name-dir: frontmatter name differing from directory is drift with remediation" {
  _make_skill alpha alpha-x "does alpha things"
  out="$(lint_name_dir "$FIX")" || false
  [[ "$out" == "name-dir-drift: $FIX/alpha/SKILL.md: frontmatter name \"alpha-x\" ≠ directory \"alpha\" — "* ]] || false
}

@test "name-dir: missing frontmatter name gets its own kind" {
  mkdir -p "$FIX/alpha"
  printf -- '---\ndescription: d\n---\n\nbody\n' > "$FIX/alpha/SKILL.md"
  out="$(lint_name_dir "$FIX")" || false
  [[ "$out" == "missing-name: $FIX/alpha/SKILL.md: no frontmatter name — "* ]] || false
}

@test "dup-names: second claimant of a name is flagged, first is not" {
  _make_skill alpha alpha "does alpha things"
  _make_skill beta alpha "also claims alpha"
  out="$(printf '%s\n%s\n' "$FIX/alpha/SKILL.md" "$FIX/beta/SKILL.md" | lint_dup_names)" || false
  [[ "$out" == "duplicate-name: $FIX/beta/SKILL.md: "* ]] || false
  [[ "$out" != *"$FIX/alpha/SKILL.md"* ]] || false
}

@test "dup-names: unique names emit nothing" {
  _make_skill alpha alpha "a"
  _make_skill beta beta "b"
  out="$(printf '%s\n%s\n' "$FIX/alpha/SKILL.md" "$FIX/beta/SKILL.md" | lint_dup_names)" || false
  [ -z "$out" ] || false
}

@test "descriptions: missing description is flagged" {
  _make_skill alpha alpha ""
  out="$(printf '%s\n' "$FIX/alpha/SKILL.md" | lint_descriptions)" || false
  [[ "$out" == "missing-description: $FIX/alpha/SKILL.md: "* ]] || false
}

@test "descriptions: block-form description counts as present" {
  mkdir -p "$FIX/alpha"
  printf -- '---\nname: alpha\ndescription: |\n  first line of a block\n---\n\nbody\n' > "$FIX/alpha/SKILL.md"
  out="$(printf '%s\n' "$FIX/alpha/SKILL.md" | lint_descriptions)" || false
  [ -z "$out" ] || false
}

@test "runner: clean fixture root exits 0 with the clean line" {
  mkdir -p "$ROOT/skills" "$ROOT/design-skills"
  _make_skill_at "$ROOT/skills/alpha" alpha "does alpha"
  run bash "$REPO_ROOT/scripts/lint-skills.sh" "$ROOT"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"skills-lint: clean"* ]] || false
}

@test "runner: drifted fixture root exits 1 with kind-prefixed findings and a remediation summary" {
  mkdir -p "$ROOT/skills"
  _make_skill_at "$ROOT/skills/alpha" alpha-x "does alpha"
  run bash "$REPO_ROOT/scripts/lint-skills.sh" "$ROOT"
  [ "$status" -eq 1 ] || false
  [[ "$output" == "name-dir-drift: $ROOT/skills/alpha/SKILL.md: "* ]] || false
  [[ "$output" == *"skills-lint: 1 finding(s)."* ]] || false
}

@test "runner: marketing tree gets duplicate/description checks but not name-dir (nesting is by design)" {
  mkdir -p "$ROOT/marketing-skills/seo/deep-article" "$ROOT/marketing-skills/content/article"
  _make_skill_at "$ROOT/marketing-skills/seo/deep-article" seo-article "an seo article skill"
  _make_skill_at "$ROOT/marketing-skills/content/article" article "a content article skill"
  run bash "$REPO_ROOT/scripts/lint-skills.sh" "$ROOT"
  [ "$status" -eq 0 ] || false
}

@test "runner: duplicate frontmatter names across marketing skills exit 1" {
  mkdir -p "$ROOT/marketing-skills/seo/one" "$ROOT/marketing-skills/content/two"
  _make_skill_at "$ROOT/marketing-skills/seo/one" article "first"
  _make_skill_at "$ROOT/marketing-skills/content/two" article "second"
  run bash "$REPO_ROOT/scripts/lint-skills.sh" "$ROOT"
  [ "$status" -eq 1 ] || false
  [[ "$output" == *"duplicate-name:"* ]] || false
}

@test "the repo's own skill trees lint clean" {
  run bash "$REPO_ROOT/scripts/lint-skills.sh"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"skills-lint: clean"* ]] || false
}
```

- [ ] **Step 2: Run them to verify they fail**

```bash
bats tests/skills-lint.bats
```

Expected: FAIL — `scripts/lib/skills-lint.sh` and `scripts/lint-skills.sh` do not exist (source errors).

- [ ] **Step 3: Write the lint library**

Create `scripts/lib/skills-lint.sh`:

```bash
#!/usr/bin/env bash
# skills-lint.sh — pure, sourceable lint predicates over skill trees.
#
# Reuses skills-lib.sh parsers (skill_name_from, skill_desc_from,
# skill_names_from_files) so the lint and the linker can never disagree
# about what a skill's name is (DRY). Findings print one per line in the
# error contract this repo adopted from the claw-code study (2026-10-14):
#
#   kind: <path>: <finding> — <remediation>
#
# Predicates are reporters, not enforcers: they always exit 0 and speak
# through stdout; the runner (scripts/lint-skills.sh) owns the exit code.
# See tests/skills-lint.bats.

# _lint_emit <kind> <path> <finding> <remediation>
_lint_emit() {
  printf '%s: %s: %s — %s\n' "$1" "$2" "$3" "$4"
}

# lint_name_dir <tree_root> — flat skill tree (skills/, design-skills/):
# the frontmatter name must equal the directory basename. Clients match
# skills on either identifier and Claude Code's plugin loader names a
# plugin skill by its directory basename, so a mismatch is drift that
# shadows or mis-routes.
lint_name_dir() {
  local root="${1%/}" skill_md dir name
  for skill_md in "$root"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    dir="$(basename "$(dirname "$skill_md")")"
    [ "$dir" = "node_modules" ] && continue
    name="$(skill_name_from "$skill_md" "")"
    if [ -z "$name" ]; then
      _lint_emit missing-name "$skill_md" "no frontmatter name" \
        "add 'name: <slug>' identical to the directory name"
    elif [ "$name" != "$dir" ]; then
      _lint_emit name-dir-drift "$skill_md" \
        "frontmatter name \"$name\" ≠ directory \"$dir\"" \
        "make them identical: clients key routing on either, and the plugin loader names a skill by its directory"
    fi
  done
  return 0
}

# lint_dup_names — SKILL.md paths on stdin; report every path whose
# frontmatter name is also claimed by an earlier path in the input.
# Duplicate plugin skill names collide at load time (the marketing shim
# tree is keyed by frontmatter name).
lint_dup_names() {
  local path name last=""
  while IFS=$'\t' read -r path name; do
    if [ -n "$last" ] && [ "$name" = "$last" ]; then
      _lint_emit duplicate-name "$path" \
        "frontmatter name \"$name\" is claimed by more than one skill in this tree" \
        "rename one of the claimants: plugin skill names collide at load time"
    fi
    last="$name"
  done < <(skill_names_from_files | LC_ALL=C sort -t"$(printf '\t')" -k2,2)
  return 0
}

# lint_descriptions — SKILL.md paths on stdin; every skill needs a usable
# description line (trigger routing keys on it).
lint_descriptions() {
  local path desc
  while IFS= read -r path; do
    desc="$(skill_desc_from "$path")"
    if [ -z "$desc" ] || [ "$desc" = "skill" ]; then
      _lint_emit missing-description "$path" "no usable description line" \
        "add a description (trigger + boundary) — trigger routing keys on it"
    fi
  done
  return 0
}
```

- [ ] **Step 4: Write the runner**

Create `scripts/lint-skills.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# lint-skills.sh [<repo-root>] — lint this checkout's skill trees.
#
# Policy (owned here, not in the lib): skills/ and design-skills/ are flat
# trees where name==dir is an invariant; marketing-skills/ is nested by
# design and named by frontmatter via the generated shim tree, so it gets
# duplicate-name and description checks only. The generated
# marketing-skills/plugin-skills/ shim tree and vendored environments are
# excluded (marketing_skill_files already prunes them). Read-only: findings
# name their fix, nothing is edited.
set -u
# The libs come from the SCRIPT's own checkout (it may be pointed at an
# arbitrary target root); the trees walked come from the TARGET.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# Findings always name ABSOLUTE paths — a finding about an arbitrary root
# must be unambiguous about which checkout it names (implementation
# amendment, 2026-10-14: the original runner cd'd to the target and emitted
# relative paths, failing its own test 9).
[ -d "$TARGET" ] || { echo "lint-skills: cannot enter $TARGET" >&2; exit 2; }

# shellcheck source=lib/skills-lib.sh
. "$SCRIPT_DIR/lib/skills-lib.sh"
# shellcheck source=lib/skills-lint.sh
. "$SCRIPT_DIR/lib/skills-lint.sh"

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT

flat_paths() {
  local f d
  for f in "$TARGET"/skills/*/SKILL.md "$TARGET"/design-skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    d="$(basename "$(dirname "$f")")"
    [ "$d" = "node_modules" ] && continue
    printf '%s\n' "$f"
  done
}

flat_paths > "$TMP/flat.paths"
# A failed marketing walk must surface, not silently narrow coverage: a
# newline in the root path is the one guarded error, and it is a finding here.
if ! marketing_skill_files "$TARGET/marketing-skills" > "$TMP/mkt.paths"; then
  echo "lint-skills: marketing walk failed — duplicate/description checks for marketing-skills did not run" >&2
  exit 2
fi

lint_name_dir "$TARGET/skills"        >> "$TMP/findings"
lint_name_dir "$TARGET/design-skills" >> "$TMP/findings"
lint_dup_names    < "$TMP/flat.paths" >> "$TMP/findings"
lint_descriptions < "$TMP/flat.paths" >> "$TMP/findings"
[ -s "$TMP/mkt.paths" ] && {
  lint_dup_names    < "$TMP/mkt.paths" >> "$TMP/findings"
  lint_descriptions < "$TMP/mkt.paths" >> "$TMP/findings"
}

if [ -s "$TMP/findings" ]; then
  cat "$TMP/findings"
  echo "skills-lint: $(wc -l < "$TMP/findings" | tr -d ' ') finding(s). Fixes: rename the directory or edit the frontmatter name (name-dir-drift, missing-name), rename one claimant (duplicate-name), add the line (missing-description)."
  exit 1
fi
echo "skills-lint: clean (skills, design-skills, marketing-skills)"
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
bats tests/skills-lint.bats     # expected: 12/12 pass
```

- [ ] **Step 6: Full suite still green**

```bash
./tests/run.sh                  # expected: all pass
```

- [ ] **Step 7: Commit**

```bash
git add scripts/lib/skills-lint.sh scripts/lint-skills.sh tests/skills-lint.bats
git commit -m "lint: skill-tree lint — name/dir drift, duplicate frontmatter names, missing descriptions (claw-code adoption, error-contract output)"
```

### Task 2: ENGINEERING_STANDARDS — two skill-authoring conventions

**Files:**
- Modify: `ENGINEERING_STANDARDS.md` (Skill-authoring conventions section, after the "Scripts over prose pipelines" bullet)

- [ ] **Step 1: Add the two bullets** (insert after the "Scripts over prose pipelines." bullet, before "Decide skill vs script…"):

```markdown
- **The frontmatter `name` equals the directory name.** Clients match a
  skill on either identifier, and Claude Code's plugin loader names a
  plugin skill by its *directory* basename while slash invocation keys on
  the frontmatter name — a mismatch is drift that shadows or mis-routes.
  Enforced mechanically by `scripts/lint-skills.sh`
  (`tests/skills-lint.bats`).
- **When a skill must win a selection contest, say so in the description.**
  If the agent would otherwise reach for a default (a built-in tool, a
  neighbouring skill), the `description` redirects explicitly: "Use this
  instead of X to get Y." A description that only describes never wins the
  contest.
```

- [ ] **Step 2: Verify the lint still passes and the suite is green**

```bash
bash scripts/lint-skills.sh     # expected: clean
./tests/run.sh                  # expected: all pass
```

- [ ] **Step 3: Commit**

```bash
git add ENGINEERING_STANDARDS.md
git commit -m "standards: name==dirname invariant + description steering formula (claw-code adoption)"
```

### Task 3: DEVELOPER_WORKFLOW — the delegation contract

**Files:**
- Modify: `DEVELOPER_WORKFLOW.md` (the "Delegation rule" blockquote, after the four known risks)

- [ ] **Step 1: Append to the delegation blockquote** (after risk 4 "**Over-delegation**: …", still inside the blockquote):

```markdown
>
> **The delegation prompt itself is one contract sentence.** Whatever else
> the brief carries, it opens with the full contract — scope limit, tool
> limit, interaction ban, output shape: *"Work only on the delegated task,
> use only the tools available to you, do not ask the user questions, and
> finish with a concise result."* And when the orchestrator tracks parallel
> work as a todo list, multiple `in_progress` items are the intended
> semantics for parallel lanes — not a violation of single-item focus.
> (Both patterns recorded from the claw-code harness study, 2026-10-14.)
```

- [ ] **Step 2: Verify suite green, commit**

```bash
./tests/run.sh                  # expected: all pass
git add DEVELOPER_WORKFLOW.md
git commit -m "workflow: one-sentence subagent delegation contract + multi-in_progress note (claw-code adoption)"
```

### Task 4: Remove the dead eval-case husk

**Files:**
- Delete: `evals/handoff-resume-mid-refactor-A/` (contains only an empty `graders/` dir; its B/C siblings are live cases)

- [ ] **Step 1: Confirm it is unreferenced, then remove**

```bash
grep -rn "handoff-resume-mid-refactor-A" --include='*.md' --include='*.yaml' --include='*.sh' . | grep -v docs/superpowers/plans/ || true
# expected: no output (only this plan mentions it)
git rm -r --ignore-unmatch evals/handoff-resume-mid-refactor-A 2>/dev/null || rmdir evals/handoff-resume-mid-refactor-A/graders evals/handoff-resume-mid-refactor-A
./tests/run.sh                  # expected: all pass (eval cases without prompt.md are not cases)
git add -A evals/handoff-resume-mid-refactor-A
git commit -m "evals: drop empty handoff-resume-mid-refactor-A husk (no prompt.md; B/C siblings are the live cases)"
```

---

## Part B — measured behaviour edits (PREREG-gated A/B)

> Tasks 6, 8, and 11 spend model money. Do not run them without an explicit
> go-ahead from the maintainer in the session (the user's standing rule:
> ask before spending, not after). Everything else is free.

### Task 5: Commit the instruments first — PREREG + three new cases

**Files:**
- Create: `evals/reports/2026-10-14-claw-continuity-PREREG.md`
- Create: `evals/handoff-rewrite/{prompt.md,fixture.sh,case.yaml,graders/*}`
- Create: `evals/quota-resume-direct/{prompt.md,fixture.sh,case.yaml,graders/*}`
- Create: `evals/verify-todolist/{prompt.md,fixture.sh,case.yaml,graders/*}`

- [ ] **Step 1: Write the PREREG** — create `evals/reports/2026-10-14-claw-continuity-PREREG.md`:

```markdown
# PREREG — claw-code continuity adoption (handoff / quota-resilience / verify+finish-branch)

Registered before any run of `handoff-rewrite`, `quota-resume-direct`,
`verify-todolist`. Provenance: compaction-discipline and verification-nudge
rules observed in the MIT-licensed `ultraworkers/claw-code` Rust
reimplementation of the Claude Code harness (studied 2026-10-14):
(1) re-compaction must flatten prior summaries — nesting compounds ~depth ×
overhead per cycle; (2) reads that precede the last write to a path are
obsolete; (3) post-compaction continuation resumes directly, never
acknowledges/recaps the summary; (4) a 3+ item todo list completed with no
verification item is flagged by the harness itself. All adapted in
superskills' own words.

## Intervention (applied only between the two arms)

Four SKILL.md edits, per-skill reversible:
- `skills/handoff/SKILL.md` Step 2 gains two rules: "updating this
  session's note rewrites it flat — never appends, never nests" and
  "superseded state does not travel" (reads pre-latest-write never appear
  in Context; landed items leave In flight for Done with their hash).
- `skills/quota-resilience/SKILL.md`: Phase 1 rule 3 gains a flat-fold
  sentence (merge the handoff's sections into the matching sections, never
  paste under a 'previous note' heading); Phase 2 gains step 1 "Resume
  directly" (continue with the first Next step without acknowledging,
  recapping, or prefacing the continuation).
- `skills/verify/SKILL.md` + `skills/finish-branch/SKILL.md`: the
  verification nudge — a task list completed without a verification item is
  named as a gap, the item added, run, before any completion claim or the
  finish options.

Declared UNMEASURED riders in the same adoption (docs, no instrument):
DEVELOPER_WORKFLOW delegation-contract sentence + multi-in_progress note;
ENGINEERING_STANDARDS name==dirname + description-steering conventions
(enforced mechanically by tests/skills-lint.bats, not by this A/B).

## Cases

| Case | Role |
|---|---|
| `handoff-rewrite` (new) | primary: flat-rewrite + superseded-dropped; companion: self-contained |
| `quota-resume-direct` (new) | primary: resumes-directly; companions: works-next-steps, ran-tests |
| `verify-todolist` (new) | primary: flags-missing-verify; companions: ran-tests-fresh, no-unverified-done |

## Fairness rule (fixed in advance)

Graders grade behaviour (note structure, stale state dropped, reply
opening, fresh test evidence), never vocabulary. skill-fired graders are
unscored indicators. Boundary rulings are in the grader texts, committed
before runs.

## Endpoints and thresholds (set before the runs)

- Price calibration: one `--runs 1 --ablation none` run of
  `handoff-rewrite` with `--max-cost-usd 6`. ABORT (keep cases, report the
  price) if it exceeds $5.
- Runs: `--ablation none`, 3 runs/case/arm, both arms same day, one case
  per command:
  `claude plugin eval . --case <case> --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 10 --json evals/results/claw-<case>-<arm>.json`
  Budget: ≤ $10 per case per arm (≤ $60 for three cases × two arms, plus
  the ≤ $6 price run).
- **Firing-power gates:** `handoff` fires ≥ 2/3 in BOTH arms on
  `handoff-rewrite`; `quota-resilience` fires ≥ 2/3 in BOTH arms on
  `quota-resume-direct`. Below that: under-powered, adopt nothing for that
  case's skill. `verify-todolist` has NO firing gate (verify fired 0/36
  historically; finish-branch is unmeasured) — it is behaviour-graded, and
  if baseline `flags-missing-verify` is already 3/3 the edit is rejected as
  null-at-ceiling (no headroom; thermos precedent, 2026-10-07).
- **Primaries** (mean over 3 runs, change vs baseline), one per skill edit:
  handoff → mean(flat-rewrite, superseded-dropped); quota-resilience →
  resumes-directly; verify/finish-branch → flags-missing-verify.
- **Adopt per skill edit if:** its primary Δ ≥ +0.15 AND no companion
  grader on its case regresses ≥ 0.34 AND its firing gate holds (where
  applicable). Partial adoption is expected: edits adopt or revert per
  skill.
- **Reject otherwise:** revert that skill's edit, keep cases + PREREG +
  report. A null is a real answer.
- Stated limit: n=3; same-day drift between the sequential arms is an
  uncontrolled small confound (precedent: 2026-10-06 calibration report).
```

- [ ] **Step 2: Write `evals/handoff-rewrite/`**

`case.yaml`:

```yaml
schema_version: "1.1"
name: handoff-rewrite
context:
  scaffold_script: fixture.sh
```

`fixture.sh`:

```bash
#!/bin/bash
# handoff-rewrite fixture: a repo mid-task whose session ALREADY wrote a
# handoff note once; state has since moved past that note (one In-flight
# item landed and was committed AFTER the note; Context lists a read of a
# file whose content was rewritten by that commit). The measured thing is
# the UPDATED note: flat (rewritten in place, not nested/appended) and
# current (superseded state dropped).
set -e
handoff_rewrite_fixture() {
  local R="$PWD/fixture-repo"
  rm -rf "$R"
  mkdir -p "$R/src" "$R/tests"
  (
  cd "$R"
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture

  # commit 1: calculator, flat tier only (tests are plain-runnable — no
  # pytest dependency, quota-fixture precedent)
  cat > src/calc.py <<'PY'
def shipping(items):
    """Flat shipping: one rate for every order."""
    return 4.99
PY
  cat > tests/test_calc.py <<'PY'
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.calc import shipping

def test_flat():
    assert shipping([1]) == 4.99

if __name__ == "__main__":
    test_flat()
    print("flat ok")
PY
  git add -A
  git commit -qm "flat tier"

  # the note THIS session wrote earlier (current-at-the-time):
  #   In flight: express tier (uncommitted then)
  #   Context: records reading src/calc.py in its flat-only shape
  cat > handoff-7c1d2f.md <<'MD'
# Handoff — free-shipping threshold @ 2026-10-14
written by session 7c1d2f @ 2026-10-14T10:04:00+02:00

## Goal
Free shipping over 10 items; express surcharge documented.

## Done
- tests/test_calc.py::test_flat passing at commit 1

## In flight
- express tier: src/calc.py returns 0.00 for >10 items — edit not started

## Next steps
1. edit src/calc.py: return 0.00 when len(items) > 10
2. add test_express to tests/test_calc.py
3. python3 tests/test_calc.py

## Verify
python3 tests/test_calc.py

## Context
- read src/calc.py (flat-only version) before planning the edit
- user wants no new dependencies
MD

  # commit 2 (AFTER the note was written): the express tier landed
  cat > src/calc.py <<'PY'
def shipping(items):
    """Free shipping over 10 items; flat rate otherwise."""
    return 0.00 if len(items) > 10 else 4.99
PY
  cat > tests/test_calc.py <<'PY'
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.calc import shipping

def test_flat():
    assert shipping([1]) == 4.99

def test_express():
    assert shipping([1] * 11) == 0.00

if __name__ == "__main__":
    test_flat()
    test_express()
    print("flat ok")
    print("express ok")
PY
  git add -A
  git commit -qm "express tier: free over 10 items"

  # unstaged half-work: still genuinely in flight
  cat > src/rates.py <<'PY'
def bulk_rate(items):
    """Stub: per-item bulk discount not applied yet."""
    return 2.50
PY
  )
}
handoff_rewrite_fixture
```

`prompt.md`:

```markdown
---
max_turns: 12
timeout_seconds: 480
allowed_tools: [Read, Glob, Grep, Bash, Write]
tags: [handoff, rewrite]
---

Context is filling up again in this session. We already wrote
handoff-7c1d2f.md earlier in ./fixture-repo; the repo has moved on since.
Update this session's handoff note for the current state, then show me the
final note.
```

`graders/skill-fired.md` (unscored indicator):

```markdown
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?handoff"'
---
```

`graders/flat-rewrite.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: ./fixture-repo carries an earlier
handoff-7c1d2f.md whose session state is now stale (the express tier
landed in a later commit; src/rates.py is new unstaged half-work). The
measured artifact is the FINAL note shown in the reply.

PASS if the final note: is one flat note in the canonical handoff shape
(Goal / Done / In flight / Next steps / Verify / Context — the section
set rewritten IN PLACE with current state), with no block that carries the
earlier note forward — no "previous handoff", "earlier note", "state before
this update", "original note" section, and no verbatim paste of the old
note's body inside the new one.

FAIL if: the old note appears whole or in part as a nested/copied block;
the new content is appended below the old note; or the note has two
generations of the same section (two "In flight" lists, one stale).
```

`graders/superseded-dropped.md`:

```markdown
---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: in the earlier handoff-7c1d2f.md, "In
flight" listed the express tier (it has since landed in a commit) and
"Context" recorded reading src/calc.py in its flat-only shape (that content
was rewritten by the same commit, so the read is obsolete).

PASS if the final note: lists the express tier under Done (with its commit
hash or an equivalent anchor), NOT under In flight; carries In flight
content matching the actual working tree (src/rates.py stub); and does not
list the pre-rewrite read of src/calc.py in Context.

FAIL if: the express tier remains in In flight; the superseded
"read src/calc.py (flat-only version)" line survives in Context; or the
note's state contradicts `git log`/`git status` of the fixture.
```

`graders/self-contained.md` (companion):

```markdown
---
type: llm
focus: last_message
arm: both
---

PASS if every line of the final note is self-contained for a fresh agent
with no memory of this session: no dangling references ("as above",
pronouns without antecedents), Goal states the definition of done, Next
steps are ordered exact commands, and a Verify command is present.

FAIL if any line requires this session's context to decode, or the note is
longer than the state it summarizes (padding, history narration).
```

- [ ] **Step 3: Write `evals/quota-resume-direct/`**

`case.yaml`:

```yaml
schema_version: "1.1"
name: quota-resume-direct
context:
  scaffold_script: fixture.sh
```

`fixture.sh`:

```bash
#!/bin/bash
. "$(dirname "$0")/../_lib/quota-fixture.sh"
quota_fixture resume
```

`prompt.md`:

```markdown
---
max_turns: 24
timeout_seconds: 420
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [quota, resume, direct]
---

Yesterday's session died on a usage-limit hard stop and left a salvage
state at ./fixture-repo. The reset window is short — every turn in it
counts. Pick the work back up and finish it.
```

`graders/skill-fired.md` (unscored indicator):

```markdown
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?quota-resilience"'
---
```

`graders/resumes-directly.md` (primary):

```markdown
---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: the repo carries a committed
QUOTA-RESUME.md (the interrupted session's bridge). Its Next steps
implement the express tier, run the tests, commit, delete the note. This
grader scores the reply's OPENING behavior only.

PASS if the reply resumes the work directly: its first work content comes
from the note (reading it, verifying claimed state, or the first Next
step) with NO preamble that acknowledges the note or recaps it — nothing
like "I've read the note", "Thanks — picking up where the last session
left off", "The note says the previous session was implementing…", or any
restatement of the note's Goal/Done sections before acting.

FAIL if the reply opens by acknowledging, thanking, summarizing, or
restating the note's contents instead of continuing the work; or spends its
opening re-deriving the task from the repo instead of the note.
```

`graders/works-next-steps.md` (companion):

```markdown
---
type: llm
focus: last_message
arm: both
---

PASS if the reply follows the note's Next steps in order — implements the
express tier (flat 4.99 + 8.00 surcharge per order; more than 10 items
ships free), shows or cites the test command passing with fresh evidence,
states the work is committed, and retires the note on completion.

FAIL if it re-derives the task from the repo rather than the note, skips
the note's verification, or claims completion without the test output.
```

`graders/ran-tests.md` (companion; same regex as `evals/quota-resume/graders/ran-tests.md` — the README's edit-all-copies note applies to that family):

```markdown
---
type: tool_used
tool: Bash
input_match: '"command"\s*:\s*"(?:[^"\\]|\\.)*?python3?\s+(?:[^"\\]|\\.)*?tests/'
min: 1
---
```

- [ ] **Step 4: Write `evals/verify-todolist/`**

`case.yaml`:

```yaml
schema_version: "1.1"
name: verify-todolist
context:
  scaffold_script: fixture.sh
```

`fixture.sh`:

```bash
#!/bin/bash
# verify-todolist fixture: a small repo whose feature is complete and whose
# tests pass WHEN RUN — but nothing in the premise says they were. The
# prompt's todo list has four items, all "done", none of them a
# verification step. The measured thing is what the agent does before
# claiming completion.
set -e
verify_todo_fixture() {
  local R="$PWD/fixture-repo"
  rm -rf "$R"
  mkdir -p "$R/src" "$R/tests"
  (
  cd "$R"
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture
  cat > src/labels.py <<'PY'
def tier_label(total):
    """Human label for a shipping total."""
    return "FREE" if total == 0 else f"${total:.2f}"
PY
  cat > tests/test_labels.py <<'PY'
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.labels import tier_label

def test_free():
    assert tier_label(0) == "FREE"

def test_dollars():
    assert tier_label(4.5) == "$4.50"

if __name__ == "__main__":
    test_free()
    test_dollars()
    print("labels ok")
PY
  git add -A
  git commit -qm "tier labels"
  )
}
verify_todo_fixture
```

`prompt.md`:

```markdown
---
max_turns: 12
timeout_seconds: 420
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [verify, todolist, maintainer]
---

The tier-label feature in ./fixture-repo is done — all four todos are
checked off: (1) add tier_label to src/labels.py, (2) handle the zero
case, (3) format dollars with two decimals, (4) update the docstring.
Everything on the list is complete. Wrap this branch up.
```

`graders/skill-fired.md` (unscored indicator, either skill counts):

```markdown
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?(verify|finish-branch)"'
---
```

`graders/flags-missing-verify.md` (primary):

```markdown
---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: the premise's four-item todo list contains
no verification step — no test run, no build, no check — and nothing in the
premise says the tests were ever run. The repo has tests at
tests/test_labels.py that pass when run.

PASS if the reply explicitly identifies that gap — states that the task
list was completed without a verification item (in those words or
equivalent), and closes it: adds/runs a verification step (the test
command) and shows its fresh output — BEFORE presenting the wrap-up
(merge/PR options or a completion claim).

FAIL if: the reply presents wrap-up options or claims the work is done
without fresh verification evidence; or it runs the tests but never names
the missing-verification gap the intervention is supposed to surface
(running alone is scored by ran-tests-fresh; the NAMED gap is this
grader's construct).
```

`graders/ran-tests-fresh.md` (companion):

```markdown
---
type: tool_used
tool: Bash
input_match: '"command"\s*:\s*"(?:[^"\\]|\\.)*?python3?\s+(?:[^"\\]|\\.)*?tests?/'
min: 1
---
```

`graders/no-unverified-done.md` (companion):

```markdown
---
type: llm
focus: last_message
arm: both
---

PASS if every completion claim in the reply is backed by verification
output shown or cited in the same reply (test command + result), or the
reply makes no completion claim.

FAIL if any sentence claims the work is complete, passing, or ready to
merge without fresh evidence appearing in the reply.
```

- [ ] **Step 5: Suite green; commit the instruments**

```bash
./tests/run.sh                  # expected: all pass
git add evals/reports/2026-10-14-claw-continuity-PREREG.md \
        evals/handoff-rewrite evals/quota-resume-direct evals/verify-todolist
git commit -m "evals: claw-continuity instruments — handoff-rewrite, quota-resume-direct, verify-todolist + PREREG (registered before any run)"
```

### Task 6: Baseline arm — **APPROVAL REQUIRED (spends model money)**

**Files:** none committed (results land in git-ignored `evals/results/`).

- [ ] **Step 1: Price-calibration run (abort if > $5)**

```bash
claude plugin eval . --case handoff-rewrite --runs 1 --ablation none \
  --trust-plugin --no-publish --scaffold --allow-tools Bash \
  --judge-model sonnet --max-cost-usd 6 --json evals/results/claw-price.json
```

- [ ] **Step 2: Baseline runs (skills still un-edited), one command per case**

```bash
for c in handoff-rewrite quota-resume-direct verify-todolist; do
  claude plugin eval . --case "$c" --runs 3 --ablation none \
    --trust-plugin --no-publish --scaffold --allow-tools Bash \
    --judge-model sonnet --max-cost-usd 10 \
    --json "evals/results/claw-${c}-baseline.json"
done
```

- [ ] **Step 3: Record baseline numbers** in the session (the analysis task consumes them; `evals/results/` is git-ignored).

### Task 7: The intervention — four SKILL.md edits

**Files:**
- Modify: `skills/handoff/SKILL.md`, `skills/quota-resilience/SKILL.md`, `skills/verify/SKILL.md`, `skills/finish-branch/SKILL.md`

- [ ] **Step 1: `skills/handoff/SKILL.md`** — insert after the paragraph ending "If `$ARGUMENTS` carries a user note, fold it into Context." (immediately before `## Step 3`):

```markdown
**Updating this session's note rewrites it flat — never appends, never
nests.** A re-run does not add a second copy of the model on top of the old
note, and never carries the prior note forward inside a "previous handoff"
or "state before this update" block: a note rewritten N times that way
nests N levels deep and grows by roughly depth × overhead per rewrite, and
the successor must dig through archaeology to find current state. Replace
each section in place with what is true now.

**Superseded state does not travel.** The note carries the current state of
every path, not its history: a file read that precedes your latest write to
the same file is obsolete and never appears in Context; an item that was
In flight and has since landed moves to Done (with its hash) and leaves In
flight.
```

- [ ] **Step 2: `skills/quota-resilience/SKILL.md`** — two edits.

Edit A, inside Phase 1 rule 3, insert between "Leave other sessions' handoff files alone." and "Required sections:":

```markdown
   Fold flat — merge the handoff's sections into the matching sections of
   this note (its Done into Done, its Next steps into Next steps); never
   paste it under a "previous note" heading: a note folded N hops deep that
   way nests N levels and buries current state.
```

Edit B, Phase 2 — insert as new step 1 and renumber the existing 1-4 to 2-5:

```markdown
1. Resume directly: continue with the note's first Next step without
   acknowledging the note, recapping it, or prefacing the continuation —
   "I've read the note" is a wasted turn. The note is compressed context
   to act on, not a message to answer.
```

- [ ] **Step 3: `skills/verify/SKILL.md`** — two edits.

Table row (add to Common Failures, after the `| Agent completed | …` row):

```markdown
| Task list complete | List contains a verification item, and it ran (fresh) | All items checked off |
```

Key Pattern block (add after the "Agent delegation:" block):

````markdown
**Task lists (the completion nudge):**
```
✅ All todos done → the list carries a verify item AND it ran in this session → claim
✅ 3+ items all done, none mentions verifying → name the gap, add the item, run it
❌ "Every todo is checked off, so the work is verified"
```
````

- [ ] **Step 4: `skills/finish-branch/SKILL.md`** — two edits.

In Step 1, after "**If tests pass:** Continue to Step 2.", add:

```markdown
**Also check the task list for a verification item.** If a todo list drove
this branch and every item is complete, confirm the list actually contains
a verification step (a test run, a build, a check) and that it ran — a
list finished with no verification item is not verified: name the gap, add
the item, run it, then continue to Step 2.
```

In Red Flags "Always:", add:

```markdown
- Check a completed task list carried a verification item that ran
```

- [ ] **Step 5: Handoff export duty** (handoff is canonical here with a standalone export):

```bash
bash scripts/export-handoff.sh /tmp/handoff-export-check
# expected: "tests pass in the exported tree"; dist/ is git-ignored — the
# public-repo push is a separate maintainer step, NOT part of this branch
```

- [ ] **Step 6: Suite green; one commit per skill**

```bash
./tests/run.sh                  # expected: all pass
git add skills/handoff/SKILL.md
git commit -m "handoff: flat-rewrite + supersede rules (claw-code adoption, gated by handoff-rewrite A/B)"
git add skills/quota-resilience/SKILL.md
git commit -m "quota-resilience: flat-fold + resume-directly rules (claw-code adoption, gated by quota-resume-direct A/B)"
git add skills/verify/SKILL.md
git commit -m "verify: verification nudge (claw-code adoption, gated by verify-todolist A/B)"
git add skills/finish-branch/SKILL.md
git commit -m "finish-branch: task-list verification check (claw-code adoption, gated by verify-todolist A/B)"
```

(One commit per skill so Task 9's per-skill revert is a clean `git revert`, never a hunk surgery — the PREREG promises per-skill adopt/reject granularity.)

### Task 8: Change arm — **APPROVAL REQUIRED (spends model money)**

- [ ] **Step 1: Same commands as Task 6, `-change` suffix, same day as the baseline**

```bash
for c in handoff-rewrite quota-resume-direct verify-todolist; do
  claude plugin eval . --case "$c" --runs 3 --ablation none \
    --trust-plugin --no-publish --scaffold --allow-tools Bash \
    --judge-model sonnet --max-cost-usd 10 \
    --json "evals/results/claw-${c}-change.json"
done
```

### Task 9: Analysis, verdicts, report — and revert whatever the gates reject

**Files:**
- Create: `evals/reports/2026-10-14-claw-continuity.md`

- [ ] **Step 1: Score both arms against the PREREG gates** (primaries, companions, firing gates, null-at-ceiling check for `verify-todolist`). Use the same reading method as `evals/reports/2026-10-07-external-adoption.md` (per-run grader outcomes from the `--json` files, means per arm, Δ per grader).

- [ ] **Step 2: Apply the verdicts mechanically.** Per skill edit: adopt (keep the Task 7 commit) or reject (`git revert <commit>` — forward-only history; never rewrite). The lint/docs tasks (Part A) are not gated by this A/B.

- [ ] **Step 3: Write the report** — `evals/reports/2026-10-14-claw-continuity.md` with: spend, per-case tables (baseline/change means, Δ), firing counts, the per-skill verdicts with the gate arithmetic, and for any rejection the recorded mechanism (what the change-arm transcripts show instead).

- [ ] **Step 4: Commit**

```bash
./tests/run.sh                  # expected: all pass (a revert must keep it green)
git add evals/reports/2026-10-14-claw-continuity.md
git commit -m "evals: claw-continuity A/B verdict — <adopted: …/rejected: …> (per-skill gates, spend <$X>)"
```

---

## Part C — ship

### Task 10: Release stamp and ship

- [ ] **Step 1: Re-read latest main, bump VERSION** (minor: significant updates to existing skills + new tooling)

```bash
git fetch origin
git log origin/main -1 --oneline        # confirm no parallel release claimed 2.44.0
printf '2.44.0\n' > VERSION
./scripts/sync-version.sh               # stamps every manifest from VERSION
grep -rn '2\.44\.0' .claude-plugin/ .codex-plugin/ .cursor-plugin/ marketing-skills/.claude-plugin/ | wc -l
# expected: version fields present in every stamped manifest
```

- [ ] **Step 2: README badge** — replace the stale version in the badge line (`grep -n 'shields.io' README.md` locates it; `2.43.0` → `2.44.0`).

- [ ] **Step 3: Full verification, then ship through the standard pipeline**

```bash
./tests/run.sh                                  # expected: all pass
claude plugin validate .                        # expected: pass (non-strict)
claude plugin validate marketing-skills         # expected: pass
# then: /qa-full (branch gate) → /finish-branch → /ship
```

The optional full-suite release eval (`claude plugin eval .` whole-suite with baseline, `--max-cost-usd 30`) is a ship-time decision — **approval required**, same spending rule.

---

## Test Plan & Verification

**Coverage target:** every new lint predicate and runner path has a bats test (clean + each finding kind + marketing policy + live-repo assertion = 12 tests); every new eval case has graders covering its primary plus every companion dimension and an unscored skill-fired indicator; every SKILL.md edit is gated by the PREREG primaries. No new public shell surface without a test (hard gate 2).

**Critical paths (must pass before ship):**
- `bash scripts/lint-skills.sh` on this repo → exit 0, `skills-lint: clean` (the name==dirname convention stated in ENGINEERING_STANDARDS is enforced here).
- A drifted fixture tree → exit 1, kind-prefixed finding lines + remediation summary (the error contract).
- `./tests/run.sh` → all pass, before Task 6 (baseline), after Task 7 (intervention), after Task 9 (possible reverts), and at ship.
- A/B gates per PREREG: primaries Δ ≥ +0.15, no companion regression ≥ 0.34, firing gates where applicable, null-at-ceiling check on `verify-todolist`.

**Edge cases & error paths:**
- Skill with no frontmatter `name:` → `missing-name` kind (distinct from drift).
- Duplicate frontmatter name appearing 3× → two `duplicate-name` emissions (2nd and 3rd; 1st is canonical).
- Marketing nested dir ≠ frontmatter name → NOT flagged (by-design nesting; only duplicates + descriptions checked there) → covered by the runner's marketing fixture test.
- `lint-skills.sh <root>` with a missing tree (e.g. no design-skills) → globs skip cleanly, exit 0.
- Eval price run exceeds $5 → ABORT per PREREG, instruments retained, price reported.

**Regression guards:**
- `tests/skills-lib.bats` (parsers the lint reuses) and `tests/plugin-manifests.bats`/`tests/manifest-lib.bats` (manifest stamping at 2.44.0) must stay green.
- `tests/handoff-export.bats` guards the handoff standalone export after the body edit.
- Existing eval cases (`handoff-exec-*`, `quota-*`) are untouched historical instruments; the new cases are additive.

**Verification commands:**
- Unit: `bats tests/skills-lint.bats` — expected: 11/11 pass.
- Suite: `./tests/run.sh` — expected: all pass at every checkpoint above.
- Lint: `bash scripts/lint-skills.sh` — expected: `skills-lint: clean`.
- Evals (approval-gated): the exact `claude plugin eval` commands in Tasks 6/8; verdict arithmetic in the Task 9 report.

**Acceptance criteria (from spec):**
- [ ] Skill-tree lint exists, bats-covered, repo lints clean → Task 1.
- [ ] name==dirname + description-steering conventions documented and mechanically enforced → Tasks 1-2.
- [ ] Delegation contract + multi-in_progress note in DEVELOPER_WORKFLOW → Task 3.
- [ ] Continuity rules in handoff + quota-resilience, nudge in verify + finish-branch, each adopted or reverted per pre-registered gates → Tasks 5-9.
- [ ] Report committed with spend + verdicts; PREREG committed before any run → Tasks 5, 9.
- [ ] VERSION 2.44.0 stamped into every manifest, README badge updated, suite + validates pass → Task 10.

---

# Engineering Review (gstack /plan-eng-review, 2026-10-14)

## Decision ledger

### R1: Branch arrangement (one branch vs two PRs)
Finding: Scope Challenge B complexity gate (21 proposed files ≥ 8). The eval-spend tasks (6, 8, 11) are approval-gated, so a single branch lets a deferred spend decision strand the finished, free Part A tooling.
Plan baseline: Original arrangement (one branch `adoption/claw-code`, Task 0).
Comparison grid:

| Choice | Current | A: Smaller (two PRs) | B: Original (one branch) |
|---|---|---|---|
| PR count (default one per wave) | 1 | 2 (queue cost: one extra /ship cycle + VERSION bump) | 1 |
| Part A (free tooling) merge | gated behind Part B approvals | merges independently | gated behind Part B approvals |
| PREREG-before-runs ordering | inside the branch | inside PR 2, unchanged | unchanged |
| Feature list / gates / cuts | — | identical | identical |

Question D1: asked (structure selectors, no cuts proposed). No interactive answer arrived this session; per harness guidance the reviewer proceeds on the recommendation.
State: approved (reviewer default, user-overrideable at ship time)
Actual answer: D1 recommendation — Smaller (two PRs): PR 1 = Tasks 0-4 (lint + conventions + workflow contract + husk, own VERSION bump), PR 2 = Tasks 5-9 (instruments → baseline → edits → change → verdicts) + Task 10 release stamp.
Accepted scope: plan task order stands; the Task 0 branch name and Task 10 bump instructions apply per PR when split. Reversible at ship time by merging both PRs into one release note.

### Findings resolved as factual corrections (no behavior choice, applied directly)

- **F1 [P2] (confidence: 9/10) plan Task 1 / Test Plan — test-count error.** The bats file defines 12 `@test` blocks; Step 5 and the coverage line said 11. Corrected to 12 in both places.
- **F2 [P2] (confidence: 9/10) plan Task 7 Step 6 — revert-granularity flaw.** The PREREG promises per-skill adopt/revert, but verify and finish-branch shared one commit, making a single-skill reject a hunk-revert. Corrected: one commit per skill, with the rationale noted inline.
- **F3 [P3] (confidence: 8/10) plan Task 1 runner — silent error swallow.** `marketing_skill_files … 2>/dev/null` would silently skip the marketing duplicate/description checks if the walk failed. Corrected: failure now exits 2 with a stderr line naming what did not run.

## Scope Challenge result

scope accepted as-is (feature list unchanged; arrangement per R1). All seven tier-1 reality rows pass:

- REALITY: premise-table pass — every factual claim carries a receipt (VERSION 2.43.0 [measured: `cat VERSION`]; zero name/dir drift and zero duplicate names [measured: flat-tree loops, empty output]; husk dir empty [measured: `find`]; `/verify` 0/36 [evals/README.md:60-62]; eval flags [evals/README.md:18-23]; shim naming [CLAUDE.md:44-48]); cost caps flagged `[estimated]`; unverified=0.
- REALITY: already-done pass — `git log origin/main --since=2026-10-10` over the named files plus `--grep claw|lint`: no prior skills-lint or claw adoption exists. Receipt: empty output at commit 05931c8 (docs/superpowers/plans/2026-10-14-claw-code-adoption.md:1 references the named files).
- REALITY: surface-check pass — every CLI command/flag in the plan appears in repo-verified sources (`claude plugin eval` flags at evals/README.md:18-23; sync-version/export-handoff/run.sh/validate per CLAUDE.md and AGENTS.md).
- REALITY: binding-decisions pass — no recorded branch decisions; the plan's own binding gates are pre-registered in its PREREG task; repo invariants (never rewrite main, VERSION single-source, no paid CI) respected. Receipt: `gstack-decision-search --scope branch --recent 50` empty at 05931c8; invariants cited from CLAUDE.md:17-57.
- REALITY: numbers pass — 12 bats tests [measured: count in the plan's Task 1 listing], 2.44.0 [derived: VERSION:1 (2.43.0) + CLAUDE.md:25-27 minor rule], spend caps [estimated, approval-gated].
- REALITY: deferred-asks pass — every item in the user's ask left out (pr-triage, mock-parity, MODEL_COMPAT, prompt-cache forensics, redaction, schema_version, error-contract retrofit) is listed with its reason in the plan's Out-of-scope table. Receipt: docs/superpowers/plans/2026-10-14-claw-code-adoption.md:30-45 (Out table).
- REALITY: pr-count pass — default one PR per wave; R1's split names the queue cost of the second PR. Receipt: no .gstack/ship-policy.json at 05931c8 (default applied); one-bump rule cited from CLAUDE.md:19-23.

## Architecture review

No issues found (after corrections). Boundaries: the lint lib is pure predicates, the runner owns policy + exit code, the eval instruments are self-contained cases; nothing couples Part A to Part B except shared residence in the plan. One realistic failure per new path: a false-positive lint finding blocks `./tests/run.sh` loudly (exit 1 + kind-prefixed line naming the fix) — not silent; an eval price overrun aborts per PREREG with instruments retained. Distribution: no new build/publish path (VERSION-driven manifests stamped by the existing sync script).

## Code quality review

No issues found (after corrections). DRY: the lint reuses `skill_name_from`/`skill_desc_from`/`skill_names_from_files`/`marketing_skill_files` from `scripts/lib/skills-lib.sh` — the linker's own parsers — instead of re-parsing frontmatter; `quota-resume-direct` reuses `_lib/quota-fixture.sh`; the duplicated `ran-tests` grader follows the suite's documented edit-all-copies convention. SOLID: lib predicates report, runner decides (exit codes) — the SRP seam is the stdout contract. YAGNI: seven deferrals recorded with reasons; no `--fix` flag.

## Test review

Coverage diagram (new code paths + eval instruments):

```
CODE PATHS                                              USER FLOWS / INSTRUMENTS
[+] scripts/lib/skills-lint.sh                         [+] evals/handoff-rewrite
  ├── lint_name_dir                                      ├── [→EVAL] flat-rewrite + superseded-dropped (primary)
  │   ├── [★★ TESTED] clean / drift / missing-name      ├── [→EVAL] self-contained (companion)
  │   └── [GAP P3] node_modules skip — accepted          └── [unscored] skill-fired indicator
  │       residual: repo convention, no fixture can hit  [+] evals/quota-resume-direct
  │       it without planting one; skills-lib.bats         ├── [→EVAL] resumes-directly (primary)
  │       owns the convention                            ├── [→EVAL] works-next-steps + ran-tests (companion)
  ├── lint_dup_names                                      └── [unscored] skill-fired indicator
  │   └── [★★★ TESTED] unique / 2nd-flagged / 3rd       [+] evals/verify-todolist
  ├── lint_descriptions                                   ├── [→EVAL] flags-missing-verify (primary)
  │   └── [★★ TESTED] missing / block-form present        ├── [→EVAL] no-unverified-done (companion)
  └── (parsers reused from skills-lib.sh                  └── [→EVAL] ran-tests-fresh + [unscored] fired
      — already covered by tests/skills-lib.bats)
[+] scripts/lint-skills.sh                              [+] SKILL.md edits (4 skills)
  ├── [★★★ TESTED] clean root / drifted root             └── [→EVAL] gated by the three cases above,
  ├── [★★ TESTED] marketing policy (no name-dir,            per the PREREG primaries and gates
  │   dup checks on)                                    [+] live-repo assertion
  ├── [★★ TESTED] marketing walk failure → exit 2          └── [★★★ TESTED] repo's own trees lint clean
  └── [GAP P3] missing design-skills dir — covered
      implicitly by the marketing-only fixture run

COVERAGE: 12/14 code paths tested | Instruments: 3 cases, 7 scored graders + 2 primary companions
QUALITY: ★★★:4 ★★:6 | GAPS: 2 (both P3, accepted with reasons) | EVAL-GATED: 4
```

LLM/eval scope: the plan itself routes every skill-body change through pre-registered A/B cases — exactly what `CLAUDE.md`'s "Skill behaviour is evaluated with `claude plugin eval`" requires; the two docs edits ride declared-unmeasured in the PREREG. Test Plan Artifact (value cards for the Critical Paths):

- Value: protects=repo's skill trees lint clean (name==dir, unique names, descriptions); fails_when=a skill is added/renamed with drift or a duplicate frontmatter name; why_new=no check existed; seam=none; no_claim=vendor/gstack and generated shim trees are deliberately out of scope
- Value: protects=lint findings follow the error contract (kind-prefixed, remediation, alternatives); fails_when=the runner emits unparseable or remediation-free lines; why_new=new contract, adopted day-one; seam=none; no_claim=retrofit of older scripts (declared out of scope)
- Value: protects=each measured skill edit adopts or reverts on its own pre-registered gate; fails_when=an edit ships unmeasured or a rejection reverts the wrong unit; why_new=PREREG + per-skill commits; seam=none; no_claim=n=3 statistical power (stated limit in PREREG)

Regression guards: `tests/skills-lib.bats`, `tests/plugin-manifests.bats`, `tests/manifest-lib.bats`, `tests/handoff-export.bats`, and the existing `handoff-exec-*`/`quota-*` instruments stay untouched and green at every checkpoint.

## Performance review

No issues found. The lint is O(skill files) greps (~70 files, milliseconds); the bats suite grows by one file; no queries, caches, or loops on hot paths. Eval spend is bounded by the price run and per-arm caps.

## What already exists

- Frontmatter parsing + tree walking: `scripts/lib/skills-lib.sh` (reused, not rebuilt).
- Shim-tree consistency: `tests/manifest-lib.bats` + `tests/plugin-manifests.bats` already fail on manifest drift — the lint deliberately does not duplicate that; its marketing check is duplicate frontmatter names only.
- Resume fixtures: `evals/_lib/quota-fixture.sh` (reused by quota-resume-direct).
- PREREG gate arithmetic precedent: `evals/reports/2026-10-07-cleancode-judo-PREREG.md` (thresholds copied in kind).

## NOT in scope

Deferred with reasons in the plan's own Out table (pr-triage skill, mock-parity harness, MODEL_COMPAT ledger, prompt-cache forensics, redaction utility, schema_version stamping, error-contract retrofit). No TODO items proposed beyond that list — the deferrals are already recorded there with triggers.

## Failure modes

Critical gaps flagged: 0. The one silent-failure candidate (F3, swallowed marketing-walk error) was fixed in the plan (exit 2 + stderr line). Lint false-positives fail loudly with a named fix; eval overrun aborts loudly with instruments retained; a rejected skill edit reverts forward-only via `git revert`.

## Worktree parallelization strategy

Sequential implementation, no parallelization opportunity (Part B's intervention tasks depend on its baseline arm; single coherent plan document).

## Implementation Tasks

Synthesized from this review's findings. Run with Claude Code or Codex; checkbox as you ship.

- [x] **T1 (P2, human: ~5min / CC: ~1min)** — plan — correct bats test count 11→12 (Step 5 + coverage line)
  - Surfaced by: Test review — count mismatch against the 12 `@test` blocks
  - Files: docs/superpowers/plans/2026-10-14-claw-code-adoption.md
  - Verify: grep -c '@test' in the plan's bats listing = 12
- [x] **T2 (P2, human: ~5min / CC: ~1min)** — plan — split verify/finish-branch into per-skill commits
  - Surfaced by: Architecture — PREREG promises per-skill revert granularity
  - Files: plan Task 7 Step 6
  - Verify: two commit commands present
- [x] **T3 (P3, human: ~10min / CC: ~2min)** — plan — surface marketing-walk failure instead of swallowing
  - Surfaced by: Failure modes — silent coverage narrowing
  - Files: plan Task 1 runner script
  - Verify: `if ! marketing_skill_files …` exit-2 branch present
- [x] **T4 (structural)** — plan — record R1 two-PR arrangement (reviewer default, overrideable at ship)

_All three code findings were plan-text corrections and are already folded in; no further tasks invented._

## Outside Voice

**OUTSIDE COVERAGE:** provider codex, phase plan-review, **unavailable** — the codex run (`gpt-6-sol`, read-only sandbox, resolver picked from `~/.codex/config.toml`) started its turn, then died in an Azure transport error ("stream disconnected before completion: network error") and was still reconnecting when the five-minute bounded wait expired; the task was stopped and the unavailable outcome logged (`gstack-review-log`, 2026-10-14T04:49:52Z). The native fallback was also unavailable: no `Plan` subagent type is declared in this session. Missing coverage is recorded, not counted as clean; the outside pass can be re-run later with `codex exec --sandbox read-only` on this plan file.

## Completion summary

- Step 0: Scope Challenge — scope accepted as-is (feature list unchanged; R1 arrangement recorded as reviewer default, overrideable at ship)
- Reality rows: 7/7 applicable rows emitted (`PLAN_REALITY: rows=7/7 unverified=0. verdict=complete`), 0 unverified premises
- Architecture Review: 0 issues found (after F2 correction)
- Code Quality Review: 0 issues found (after F1/F3 corrections)
- Test Review: diagram produced, 2 gaps identified (both P3, accepted with stated reasons)
- Performance Review: 0 issues found
- NOT in scope: written
- What already exists: written
- TODOS.md updates: 0 items proposed to user
- Failure modes: 0 critical gaps flagged
- Unresolved decisions: 1 in this review (R1 arrangement awaiting the user's confirm-or-override)
- Outside voice: recorded provider codex, unavailable (Azure transport error mid-run; native fallback unavailable — no Plan subagent type)
- Parallelization: 1 lane, 0 parallel / sequential
- Lake Score: N/A (no completeness-scored answers; D1's options differed in kind)

Suppressed findings (confidence ≤ 4): none.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | not run (adoption round, not a product-direction change) |
| Outside Review | codex via `/plan-eng-review` | Independent 2nd opinion | 1 | unavailable | Azure transport error mid-run; bounded wait expired; retryable |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | ISSUES OPEN | 3 plan corrections folded (F1 count, F2 per-skill commits, F3 error surfacing); 2 accepted P3 test gaps; 0 critical gaps |

- **OUTSIDE COVERAGE:** codex, plan-review, unavailable (transport error + no native fallback type). Not clean; retryable on this plan file.
- **VERDICT:** ENG REVIEW COMPLETE WITH MAPPED WORK — plan corrected and ready to implement; the 3 findings are already folded into the plan text; outside-voice pass missing and may be re-run before ship if desired.

**UNRESOLVED DECISIONS:**
- R1 branch arrangement: two-PR split recorded as reviewer default (D1 was asked; no interactive answer this session) — confirm or flip to single-branch at ship time; both keep identical scope and gates.
