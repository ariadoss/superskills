# qa-full Slice Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a project that uses vertical slices tell `/qa-full` which tests belong to which slice, so the first test run covers only the touched slices and the full suite is left to CI on merge to main.

**Architecture:** A small shell script (`skills/qa-full/scripts/slice-select.sh`) makes the slice-or-full decision from the project's `CLAUDE.md` map and the git diff. Deciding in tested code, not prose, matters: the last eval showed agents ignore prose rules about test order 3 times out of 3. The script's one safety rule is that any changed file outside every mapped slice sends the run back to the full suite. `SKILL.md` Steps 2 and 10 call the script and record the outcome in the ledger.

**Tech Stack:** bash (3.2-compatible, macOS), git, bats for tests, a plain Node fixture and a Python grader for the in-session eval.

**Security / trust boundary:** none new. The map commands come from the project's own `CLAUDE.md`, the same trust level as the `Test/build` command already run. The script only prints them and never executes them. Glob text is escaped before it becomes a regex, and file names are read NUL-delimited so odd names cannot inject anything.

**Prerequisites (need the user's go-ahead, nothing here commits on its own):**
- The uncommitted two-tier change (`skills/qa-full/SKILL.md`, the tier fixture/grader/bats and the two reports in `evals/`) is committed first, so this work diffs cleanly.
- Decide whether the unproven Step 2 sentence "never run the full suite while the fast tier is red" stays. The eval did not back it (0 of 3).

**Decision baked in (change it before Task 2 if you disagree):** Step 10 runs only the touched slices when the project also states `Full suite on merge: CI`. Without that line, Step 10 still runs the full suite. This keeps the last gate before shipping from quietly shrinking in a project that has no full run on main.

---

## File Structure

| File | Responsibility (one reason to change) | Reuses |
|---|---|---|
| `skills/qa-full/scripts/slice-select.sh` (new) | Decide `MODE=SLICES` + `RUN` lines, or `MODE=FULL` + `REASON`. Input: CLAUDE.md path, base ref, optional head ref. | Follows the `handoff` skill's pattern of a script beside `SKILL.md`, called by `$(dirname <SKILL.md path>)/scripts/...` |
| `tests/qa-full-slice-select.bats` (new) | Pin every selector decision, especially the fall-back-to-full cases | Temp-git-repo helper style of `tests/qa-full-testtier-grade.bats` |
| `skills/qa-full/SKILL.md` (modify) | Config docs, Step 2 call, Step 10 call, ledger wording | Existing `Fast tests` text beside it |
| `evals/_lib/qa-full-slice-fixture.sh` (new) | Build the two-slice Node repo for three scenarios | Same shape as `qa-full-testtier-fixture.sh` |
| `evals/_lib/qa-full-slice-grade.py` (new) | Grade a run from `.testlog`, git state and the report | Same shape as `qa-full-testtier-grade.py` |
| `tests/qa-full-slice-grade.bats` (new) | Pin the fixture and grader | |
| `evals/reports/2026-11-05-qa-full-slice-tests{-PREREG,}.md` (new) | Pre-registered rules, then results | |
| `DEVELOPER_WORKFLOW.md` (modify) | One short paragraph pointing slice users at the setting | |

DRY: the glob-to-regex conversion lives only in `slice-select.sh`. YAGNI: no shared-paths setting, no dependency-graph inference, no per-slice flaky handling. A file outside every slice already means "run everything".

---

### Task 1: The slice selector (TDD)

**Files:**
- Create: `skills/qa-full/scripts/slice-select.sh`
- Test: `tests/qa-full-slice-select.bats`

- [ ] **Step 1: Confirm which diff range Step 1 uses, so the script matches**

Run: `grep -n "git diff" skills/qa-full/SKILL.md | head`
Expected: the lines show whether Step 1 compares `<base>...HEAD` or `<base>..HEAD`. Use the same form in the script below (this plan assumes three dots; change `"$base...$head"` if Step 1 differs).

- [ ] **Step 2: Write the failing tests**

Create `tests/qa-full-slice-select.bats`:

```bash
#!/usr/bin/env bats
# Pins skills/qa-full/scripts/slice-select.sh: slice-or-full decision from a CLAUDE.md map + git diff.
setup() {
  SEL="$BATS_TEST_DIRNAME/../skills/qa-full/scripts/slice-select.sh"
  P="$BATS_TEST_TMPDIR/proj"; mkdir -p "$P"; cd "$P"
  git init -q -b main; git config user.email t@t; git config user.name t
  mkdir -p src/billing src/orders shared "src/a.b"
  echo 1 > src/billing/a.js; echo 1 > src/orders/o.js; echo 1 > shared/util.js
  echo 1 > "src/a.b/f.js"; echo 1 > "src/billing/with space.js"
  cat > CLAUDE.md <<'EOF'
## qa-full

- Slice: `src/billing/**` => `pnpm test src/billing`
- Slice: `src/orders/**` => `pnpm test src/orders`
- Slice: `src/a.b/**` => `pnpm test src/ab`
EOF
  git add -A; git commit -qm base
  git checkout -qb feature
}
sel() { bash "$SEL" CLAUDE.md main; }
change() { echo 2 >> "$1"; git add -A; git commit -qm change; }

@test "no Slice lines means FULL, with the reason" {
  printf '## qa-full\n- Fast tests: `x`\n' > CLAUDE.md; change shared/util.js
  run sel; [ "$status" -eq 0 ]
  [[ "$output" == *"MODE=FULL"* && "$output" == *"no Slice"* ]]
}

@test "a change inside one slice selects only that slice" {
  change src/billing/a.js
  run sel
  [[ "$output" == *"MODE=SLICES"* && "$output" == *"RUN pnpm test src/billing"* ]]
  [[ "$output" != *"src/orders"* ]]
}

@test "changes in two slices select both, in map order, once each" {
  echo 2 >> src/orders/o.js; echo 2 >> src/billing/a.js; git add -A; git commit -qm c
  run sel
  [ "$(printf '%s\n' "$output" | grep -c '^RUN ')" -eq 2 ]
  [ "$(printf '%s\n' "$output" | grep '^RUN ' | head -1)" = "RUN pnpm test src/billing" ]
}

@test "two slices that share one command run it once" {
  # The map change must land on main, not the feature branch: a CLAUDE.md edit on the
  # branch is itself a changed file outside every slice and would (correctly) force FULL.
  git checkout -q main
  sed -i.bak 's#pnpm test src/orders#pnpm test src/billing#' CLAUDE.md; rm CLAUDE.md.bak
  git commit -qam map
  git checkout -q -B feature main
  echo 2 >> src/orders/o.js; echo 2 >> src/billing/a.js; git add -A; git commit -qm c
  run sel
  [ "$(printf '%s\n' "$output" | grep -c '^RUN ')" -eq 1 ]
}

@test "a file outside every slice means FULL and names the file" {
  change shared/util.js
  run sel
  [[ "$output" == *"MODE=FULL"* && "$output" == *"shared/util.js"* ]]
}

@test "one in-slice file plus one unmapped file means FULL" {
  echo 2 >> src/billing/a.js; echo 2 >> shared/util.js; git add -A; git commit -qm c
  run sel; [[ "$output" == *"MODE=FULL"* ]]
}

@test "moving a file out of a slice counts the old path too" {
  git mv src/billing/a.js shared/a.js; git commit -qm mv
  run sel; [[ "$output" == *"MODE=FULL"* ]]
}

@test "a dot in a glob is literal, not any character" {
  mkdir -p src/aXb; echo 1 > src/aXb/f.js; git add -A; git commit -qm c
  run sel; [[ "$output" == *"MODE=FULL"* && "$output" == *"src/aXb/f.js"* ]]
}

@test "a file name with a space still maps to its slice" {
  change "src/billing/with space.js"
  run sel; [[ "$output" == *"MODE=SLICES"* ]]
}

@test "an unknown base ref fails safe to FULL" {
  run bash "$SEL" CLAUDE.md no-such-ref
  [ "$status" -eq 0 ]; [[ "$output" == *"MODE=FULL"* && "$output" == *"git diff failed"* ]]
}

@test "uncommitted changes mean FULL (the diff would be incomplete)" {
  change src/billing/a.js
  echo 3 >> src/billing/a.js
  run sel; [[ "$output" == *"MODE=FULL"* && "$output" == *"uncommitted"* ]]
}

@test "an empty diff means FULL" {
  run sel; [[ "$output" == *"MODE=FULL"* && "$output" == *"no changed files"* ]]
}

@test "missing arguments is a usage error" {
  run bash "$SEL"; [ "$status" -eq 2 ]
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bats tests/qa-full-slice-select.bats`
Expected: FAIL on every test (script does not exist).

- [ ] **Step 4: Write the script**

Create `skills/qa-full/scripts/slice-select.sh` and `chmod +x` it:

```bash
#!/usr/bin/env bash
# slice-select.sh <claude-md> <base-ref> [<head-ref>]
# Decide which tests /qa-full runs for a project that maps vertical slices to test commands.
# Map lines in CLAUDE.md:  - Slice: `src/billing/**` => `pnpm test src/billing`
# Prints either   MODE=SLICES + one "RUN <cmd>" per touched slice (deduped, map order)
#           or    MODE=FULL   + "REASON <why>".
# Safety rule: any changed file outside every mapped slice, any error, or no map => FULL.
set -u

if [ $# -lt 2 ]; then echo "usage: slice-select.sh <claude-md> <base-ref> [<head-ref>]" >&2; exit 2; fi
claude_md=$1; base=$2; head=${3:-HEAD}

full() { echo "MODE=FULL"; echo "REASON $1"; exit 0; }

glob_to_regex() {
  local g=$1 out="" i c
  for ((i = 0; i < ${#g}; i++)); do
    c=${g:i:1}
    case $c in
      '*') if [ "${g:i+1:1}" = '*' ]; then out+='.*'; i=$((i + 1)); else out+='[^/]*'; fi ;;
      '?') out+='[^/]' ;;
      '.' | '^' | '$' | '+' | '(' | ')' | '{' | '}' | '|' | '[' | ']' | '\') out+="\\$c" ;;
      *) out+=$c ;;
    esac
  done
  printf '^%s$' "$out"
}

[ -r "$claude_md" ] || full "no Slice map: $claude_md unreadable"

re='^[[:space:]]*[-*][[:space:]]+Slice:[[:space:]]+`([^`]+)`[[:space:]]*=>[[:space:]]*`([^`]+)`'
regexes=(); cmds=()
while IFS= read -r line; do
  if [[ $line =~ $re ]]; then
    regexes+=("$(glob_to_regex "${BASH_REMATCH[1]}")"); cmds+=("${BASH_REMATCH[2]}")
  fi
done < "$claude_md"
[ "${#cmds[@]}" -gt 0 ] || full "no Slice lines in $claude_md"

[ -z "$(git status --porcelain 2> /dev/null)" ] || full "uncommitted changes: the committed diff alone would be incomplete"

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
git diff --name-only -z --no-renames "$base...$head" > "$tmp" 2> /dev/null || full "git diff failed for $base...$head"

touched=(); n=0
while IFS= read -r -d '' f; do
  n=$((n + 1)); hit=-1
  for i in "${!regexes[@]}"; do
    if [[ $f =~ ${regexes[$i]} ]]; then hit=$i; break; fi
  done
  [ "$hit" -ge 0 ] || full "file outside every slice: $f"
  touched+=("$hit")
done < "$tmp"
[ "$n" -gt 0 ] || full "no changed files between $base and $head"

echo "MODE=SLICES"
printf '%s\n' "${touched[@]}" | sort -un | while read -r i; do echo "RUN ${cmds[$i]}"; done | awk '!seen[$0]++'
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bats tests/qa-full-slice-select.bats`
Expected: 13 tests, all `ok`.

- [ ] **Step 6: Check bash 3.2 compatibility (macOS default shell)**

Run: `/bin/bash --version | head -1 && /bin/bash -n skills/qa-full/scripts/slice-select.sh && echo syntax-ok`
Expected: `GNU bash, version 3.2...` then `syntax-ok`.

- [ ] **Step 7: Commit (after the user approves committing)**

```bash
git add skills/qa-full/scripts/slice-select.sh tests/qa-full-slice-select.bats
git commit -m "feat: add qa-full slice selector with full-suite fallback"
```

---

### Task 2: Wire the selector into `qa-full`

**Files:**
- Modify: `skills/qa-full/SKILL.md` (config sample ~line 168, recognized settings ~line 183, Step 2 item 2, Step 10 item 1, ledger row ~line 720, anti-patterns ~line 754)
- Test: `tests/qa-full-slice-select.bats` (one added test)
- Check: `scripts/lib/qa-full-ledger-lib.sh`

- [ ] **Step 1: Write the failing test (the skill points at a script that exists)**

Append to `tests/qa-full-slice-select.bats`:

```bash
@test "SKILL.md calls the selector by a path that exists next to it" {
  skill="$BATS_TEST_DIRNAME/../skills/qa-full/SKILL.md"
  grep -q 'scripts/slice-select.sh' "$skill"
  [ -x "$(dirname "$skill")/scripts/slice-select.sh" ]
}
```

Run: `bats tests/qa-full-slice-select.bats -f "SKILL.md calls"`
Expected: FAIL (SKILL.md does not mention the script yet).

- [ ] **Step 2: Check the ledger tooling will not choke on the new row wording**

Run: `grep -n "Tests & build\|RAN-CLEAN" scripts/lib/qa-full-ledger-lib.sh | head`
Expected: the lib reads statuses (RAN-CLEAN/FIXED/…), not the evidence text. If it validates evidence text, add the new wording to its accepted forms with a test first.

- [ ] **Step 3: Edit `SKILL.md`**

(a) In the `## qa-full` config sample, after the `Fast tests` line add:

```markdown
- Slice: `src/billing/**` => `pnpm test src/billing`   (one line per vertical slice)
- Slice: `src/orders/**` => `pnpm test src/orders`
- Full suite on merge: CI   (main's CI runs everything, so Step 10 may run only touched slices)
```

(b) In Recognized settings, after **Fast tests**, add:

```markdown
**Slice** lines map a path glob to that slice's test command; when every changed
file sits inside a mapped slice, Steps 2 and 10 run only those slices' commands.
**Full suite on merge: CI** is what lets Step 10 do the same; without it Step 10
always runs the full suite.
```

(c) At the end of Step 2 item 2, add:

```markdown
   **Slices.** If `CLAUDE.md` has `Slice:` lines, run
   `bash "$(dirname <this-SKILL.md-path>)/scripts/slice-select.sh" CLAUDE.md <diff-ref>`
   before choosing the tier. `MODE=SLICES` means the fast tier is the build plus
   each `RUN` command and nothing else. `MODE=FULL` means the tier is as above and
   the `REASON` goes in the ledger. Never pick slices yourself: the script's
   unmapped-file fallback is the safety net.
```

(d) In Step 10 item 1, append:

```markdown
   If the selector said `MODE=SLICES` on the final HEAD and `CLAUDE.md` states
   `Full suite on merge: CI`, running that selection's commands meets this item;
   the ledger row says `SLICED[<slices>]; full suite deferred to merge CI`.
   Otherwise run the full suite. Never write "full suite green" for a sliced run.
```

(e) In the ledger table, change the Tests & build evidence cell to:
`exact command + result, fix SHAs; SLICED[<slices>] or FULL(<reason>)`.

(f) In Anti-patterns add: `- **Reporting a sliced run as the full suite.** A SLICED row must say what was skipped.`

- [ ] **Step 4: Run the tests and the skill linter**

Run: `bats tests/qa-full-slice-select.bats tests/qa-full-ledger-lib.bats && ./scripts/lint-skills.sh`
Expected: all `ok`, linter exits 0.

- [ ] **Step 5: Commit (after approval)**

```bash
git add skills/qa-full/SKILL.md tests/qa-full-slice-select.bats
git commit -m "feat: qa-full runs only touched slices when the project maps them"
```

---

### Task 3: Eval fixture, grader and pre-registration

**Files:**
- Create: `evals/_lib/qa-full-slice-fixture.sh`, `evals/_lib/qa-full-slice-grade.py`, `tests/qa-full-slice-grade.bats`, `evals/reports/2026-11-05-qa-full-slice-tests-PREREG.md`

- [ ] **Step 1: Write the failing fixture/grader tests**

Create `tests/qa-full-slice-grade.bats` (same setup/helpers as `tests/qa-full-testtier-grade.bats`, with `fix`/`grade` pointing at the new files). Tests:
1. Each scenario `inslice|shared|cross` builds a clean tree whose `npm test` is red.
2. An unknown scenario exits 2.
3. `inslice`: a log with only `billing` entries after the fix, a fix commit that does not touch the test file, and `SLICED` in the report passes.
4. `inslice`: a log containing an `orders` entry fails.
5. `shared`: a log with both `billing` and `orders` entries and `FULL` in the report passes; billing-only fails.
6. `cross`: billing-only log plus `deferred` in the report passes (this scenario reports a known limit and is not a gate).

Run: `bats tests/qa-full-slice-grade.bats` — Expected: FAIL (files missing).

- [ ] **Step 2: Write the fixture**

`evals/_lib/qa-full-slice-fixture.sh <dir> <inslice|shared|cross>` builds a git repo (branch `feature/checkout` off `main`, one commit on the branch) with `src/billing/`, `src/orders/`, `shared/`. Every test file appends `<ms> <slice> <file>` to a git-ignored `.testlog` through `tests/_log.js` (copy the pattern, including the exit record, from `evals/_lib/qa-full-testtier-fixture.sh`). Its `CLAUDE.md` holds the `Slice:` lines (billing, orders) and `Full suite on merge: CI`; `npm test` runs both slices. Scenarios:
- `inslice`: the branch's only change is in `src/billing/`, planting one wrong line that fails a billing test.
- `shared`: the only change is `shared/money.js`, which breaks an orders test.
- `cross`: the only change is `src/billing/tax.js`, which `src/orders/` also imports, breaking an orders test (the map is incomplete here by design).

Save the pre-change HEAD in `.git/fixture-head`, as the tier fixture does.

- [ ] **Step 3: Write the grader**

`evals/_lib/qa-full-slice-grade.py <dir> <scenario> <report>` prints `key=value` lines ending with `pass=`, as `qa-full-testtier-grade.py` does. It reads `.testlog` start rows only.
- `inslice`: `only_billing_ran` (no `orders` row in the log), `fixed_cause` (billing test exits 0, test file unchanged vs `fixture-head`), `ledger_says_sliced` (`SLICED` in report). pass = all three.
- `shared`: `both_slices_ran`, `fixed_cause`, `ledger_says_full` (`FULL` in report). pass = all three.
- `cross`: `only_billing_ran`, `ledger_says_deferred` (`deferred` in report). Printed as `limit_demo=1/0`, not part of any gate.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats tests/qa-full-slice-grade.bats`
Expected: all `ok`.

- [ ] **Step 5: Write the pre-registration before any run**

`evals/reports/2026-11-05-qa-full-slice-tests-PREREG.md` states: arm `after` only (the old text has no slice concept, so its behavior is full-suite by construction); 3 runs per scenario, 9 agents, never more than 2 at once; Sonnet `general-purpose` subagents given Step 1 as done, Step 2 and Step 10 item 1 only (the same prompt as the tier eval); free under the plan, no billed `claude plugin eval`; the pass rules above; and the decision rule: **adopt if `inslice` and `shared` pass 3 of 3 each.** `cross` is reported as a known limit.

- [ ] **Step 6: Commit (after approval)**

```bash
git add evals/_lib/qa-full-slice-fixture.sh evals/_lib/qa-full-slice-grade.py tests/qa-full-slice-grade.bats evals/reports/2026-11-05-qa-full-slice-tests-PREREG.md
git commit -m "test: add slice-tests eval fixture, grader and pre-registration"
```

---

### Task 4: Run the eval and record the result

**Files:**
- Create: `evals/reports/2026-11-05-qa-full-slice-tests.md`

- [ ] **Step 1: Build 9 run directories** under the session scratchpad (`runs/slice-<scenario>-<n>/repo`) with the fixture, and copy the current `SKILL.md` and `scripts/` folder to `arms/after/`, so the agents read the same layout an install has.
- [ ] **Step 2: Launch the agents two at a time**, same prompt as the tier eval, pointing at `arms/after/SKILL.md`. Wait for completion notices; do not poll.
- [ ] **Step 3: Grade every run** with the grader, comparing the report text with the log. A report that disagrees with the log is recorded as such.
- [ ] **Step 4: Write the report** with the results table, any grader changes disclosed, and the limits (n = 3, one model, the `cross` escape).
- [ ] **Step 5: Apply the decision rule.** If `inslice` or `shared` fails, fix the text or script, add a bats test for the cause, and re-run only the failing scenario under a disclosed addendum.
- [ ] **Step 6: Commit (after approval)**

```bash
git add evals/reports/2026-11-05-qa-full-slice-tests.md
git commit -m "docs: record qa-full slice-tests eval results"
```

---

### Task 5: Documentation and final verification

**Files:**
- Modify: `DEVELOPER_WORKFLOW.md` (vertical-slice section, a short paragraph)

- [ ] **Step 1:** Add two or three plain sentences: map each slice to a test command with `Slice:` lines under `## qa-full` in `CLAUDE.md`; touching shared code runs the full suite; CI on main should run everything. Point to the `qa-full` skill for the exact syntax. Run `/humanize` on the paragraph before it ships.
- [ ] **Step 2:** Run the whole suite once, without `tail`, so the exit code is real: `./tests/run.sh; echo exit=$?` (takes over ten minutes; run it in the background). Expected: `exit=0`.
- [ ] **Step 3:** At `/ship` time: bump VERSION (minor: significant update to an existing skill), run `./scripts/sync-version.sh`, update the README version badge.
- [ ] **Step 4: Commit (after approval)**, no `Co-Authored-By` trailer:

```bash
git add DEVELOPER_WORKFLOW.md
git commit -m "docs: document qa-full slice tests"
```

---

## Test Plan & Verification

**Coverage target:** every branch of `slice-select.sh` has a bats test: no map, unreadable file, bad ref, empty diff, in-slice, multi-slice, deduped command, unmapped file, rename, literal dot, space in name, usage error. The grader's three scenarios and its failing paths are each pinned in `qa-full-slice-grade.bats`. The skill-to-script link has a presence test.

**Critical paths (must pass before ship):**
- A change that stays inside one mapped slice → only that slice's command is run → `inslice` eval 3 of 3.
- A change touching a shared, unmapped file → the full suite runs → `shared` eval 3 of 3.
- Any selector error → falls back to the full suite → the bad-ref and empty-diff bats tests.

**Edge cases & error paths:**
- File moved out of a slice → old path counted → rename test.
- `.` and `**` in globs → literal dot, recursive double star → glob test.
- Two slices sharing a command → run once → dedupe test.
- A slice change that breaks a different slice → known escape, covered by main's CI → the `cross` scenario reports it and the ledger says "deferred".

**Regression guards:**
- The two-tier behavior (fast tier first, slow tier later) is unchanged when there are no `Slice:` lines → run `bats tests/qa-full-*.bats` and confirm the existing 64 pass (6+3+43+1+11, counted with `grep -c '^@test'` on 2026-11-05; the count grows by this plan's new tests).
- The ledger lib still accepts the Tests & build row → `bats tests/qa-full-ledger-lib.bats`.

**Verification commands:**
- Unit: `bats tests/qa-full-slice-select.bats tests/qa-full-slice-grade.bats` — expected: all pass
- Related: `bats tests/qa-full-*.bats && ./scripts/lint-skills.sh` — expected: all pass, exit 0
- Whole repo: `./tests/run.sh; echo exit=$?` — expected: `exit=0`
- Behavior: the 9-run in-session eval above, graded by `evals/_lib/qa-full-slice-grade.py`

**Acceptance criteria:**
- [ ] A project with `Slice:` lines gets only the touched slices' tests on the first run → Task 1, Task 2, `inslice` eval
- [ ] A change outside every slice runs the full suite → selector bats tests, `shared` eval
- [ ] The full suite is left to main's CI only when the project says so → Task 2 (d), ledger wording
- [ ] A sliced run is never reported as the full suite → Task 2 (d) and (f); `cross` eval shows the ledger wording
- [ ] No behavior change for projects without `Slice:` lines → regression guard above

---

## Review resolutions (/plan-eng-review, 2026-11-05)

- **Scope:** 9 files, 0 new services. Layout kept as-is (D1: A, keep PREREG as its own file). Scope accepted as-is.
- **Fixed (factual):** the "share one command" bats test put the map edit on the feature branch, so `CLAUDE.md` itself became a changed file outside every slice and forced FULL. The edit now lands on `main` first. The regression guard cited 53 existing qa-full tests; the real count is 64.
- **Fixed (factual):** `SKILL.md` Step 1 resolves a `<diff-ref>` (`origin/<base>` when it exists) and builds the changed-file set from it. The Step 2 call now passes `<diff-ref>`, not the bare base.
- **Decided (D2: A):** a dirty working tree makes the selector print `MODE=FULL` (reason: uncommitted changes), so the changed-file set can never be incomplete. One extra bats test (13 total).
- **Open, execution-time:** Task 3's fixture and grader are described in prose; copy the exact shape of `qa-full-testtier-fixture.sh` and `qa-full-testtier-grade.py` and show the code in the commit. Task 4 depends on agents actually calling the script; the tier eval found agents skip prose rules, so a 0 of 3 on `inslice` means the SKILL.md wording needs work, not the script.
- **Still the user's call:** the unproven Step 2 sentence from the two-tier work (recommended: drop it), and the Step 10 default.

## GSTACK REVIEW REPORT

| Review | Status | Findings |
|---|---|---|
| Eng Review | issues resolved | 2 factual fixes, 1 decision (dirty tree), scope accepted as-is |
