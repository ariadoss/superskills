#!/usr/bin/env bats
# Tests for the routing-eval harness: evals/_lib/routing-fixture-extra.sh (the
# extra triggers qa-full-fixture.sh does not plant) and evals/_lib/grade-routing.py
# (the confusion-matrix grader). Hermetic: builds under BATS_TEST_TMPDIR.
#
# The grader tests cover the two bugs that surfaced during the 2026-09-25 run:
# a still-running transcript scored as "no skill fired", and an orchestrator's
# documented fan-out scored as a false positive.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  D="$BATS_TEST_TMPDIR/fx"
  TASKS="$BATS_TEST_TMPDIR/tasks"
  SKILLS="$BATS_TEST_TMPDIR/skills"
  mkdir -p "$TASKS"
}

build() {
  bash "$REPO_ROOT/evals/_lib/qa-full-fixture.sh" "$D"
  bash "$REPO_ROOT/evals/_lib/routing-fixture-extra.sh" "$D"
}

# --- routing-fixture-extra.sh -------------------------------------------------

@test "extra fixture: plants one trigger per routing cluster and commits them" {
  build
  [ -f "$D/src/pricing.js" ]            # clean-code: duplicated tax logic
  [ -f "$D/src/quote.js" ]
  [ -f "$D/src/hotpath.js" ]            # perf-profile: quadratic hot path
  [ -f "$D/web/index.html" ]            # web-perf: render-blocking page
  [ -f "$D/.github/workflows/ci.yml" ]  # iac-scan: untrusted CI trigger
  [ -z "$(git -C "$D" status --porcelain)" ]
  [ "$(git -C "$D" branch --show-current)" = "feature/checkout" ]
}

@test "extra fixture: the duplication is real, so a DRY finding is not a false positive" {
  build
  # Same rate table and same rounding expression in both files.
  grep -q "TAX_RATES" "$D/src/pricing.js"
  grep -q "TAX_RATES" "$D/src/quote.js"
  run bash -c "grep -c 'Math.round' '$D/src/pricing.js' '$D/src/quote.js'"
  [ "$status" -eq 0 ]
}

@test "extra fixture: hot path is quadratic and the page is render-blocking" {
  build
  # A nested loop over the same collection, not just two loops in the file.
  run python3 - "$D/src/hotpath.js" <<'PY'
import re, sys
body = open(sys.argv[1]).read()
inner = body.index("for (const b of orders)")
outer = body.index("for (const a of orders)")
sys.exit(0 if outer < inner else 1)
PY
  [ "$status" -eq 0 ]
  # Two head scripts with neither async nor defer.
  run bash -c "grep -c '<script src=\"https://cdn.example.test' '$D/web/index.html'"
  [ "$output" = "2" ]
  run grep -q 'defer\|async' "$D/web/index.html"
  [ "$status" -ne 0 ]
}

@test "extra fixture: is idempotent on a rebuild" {
  build
  local first; first="$(git -C "$D" rev-parse 'HEAD^{tree}')"
  build
  [ "$(git -C "$D" rev-parse 'HEAD^{tree}')" = "$first" ] || { echo "rebuild produced a different tree"; return 1; }
  [ -z "$(git -C "$D" status --porcelain)" ]
  # Rebuilt from scratch, so the tree matches even if the SHA differs.
  run git -C "$D" log --oneline
  printf '%s\n' "$output" | grep -q 'pricing/quote tax, hot path, checkout page, ci workflow'
}

# --- grade-routing.py --------------------------------------------------------

# fake_skills <name...> — a skills dir the grader can treat as "owned".
fake_skills() {
  local n
  for n in "$@"; do
    mkdir -p "$SKILLS/$n"
    printf -- '---\nname: %s\n---\nbody\n' "$n" > "$SKILLS/$n/SKILL.md"
  done
}

# transcript <file> <case> <handback|running> [skill...] — a minimal JSONL
# transcript: the opening user turn naming the fixture, then Skill calls.
transcript() {
  local out="$TASKS/$1.output" case="$2" mode="$3"; shift 3
  python3 - "$out" "$case" "$mode" "$@" <<'PY'
import json, sys
out, case, mode = sys.argv[1], sys.argv[2], sys.argv[3]
skills = sys.argv[4:]
recs = [{"type": "user", "message": {"content":
         f"Your project root for this task is /tmp/runs/before-{case}. "
         "Work there; ignore the directory this session started in. Do the thing."}}]
content = [{"type": "tool_use", "name": "Skill", "input": {"skill": s}} for s in skills]
if mode == "handback":
    content.append({"type": "tool_use", "name": "SubagentHandback",
                    "input": {"message": "Done. Next step is /test-coverage."}})
recs.append({"type": "assistant", "message": {"content": content}})
with open(out, "w") as fh:
    for r in recs:
        fh.write(json.dumps(r) + "\n")
PY
}

grade() {
  python3 "$REPO_ROOT/evals/_lib/grade-routing.py" "$TASKS" "$SKILLS" before
}

@test "grader: a transcript with no handback is EXCLUDED, not scored as a miss" {
  fake_skills debug test-coverage verify tdd
  transcript run1 A1-r1 running
  run grade
  # Non-zero: there is nothing gradeable yet, which must not look like a clean run.
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep -q 'EXCLUDED (still running, no handback): A1-r1'
  printf '%s\n' "$output" | grep -q 'no before runs found'
}

@test "grader: counts the intended skill as a TP and reports no false positive" {
  fake_skills debug test-coverage verify tdd
  transcript run1 A1-r1 handback debug
  run grade
  printf '%s\n' "$output" | grep -qE 'TP \(intended fired\) +1 / 1'
  printf '%s\n' "$output" | grep -qE 'FP \(wrong owned skill\) +0'
}

@test "grader: a genuine misroute IS counted as a false positive" {
  fake_skills debug test-coverage verify tdd
  transcript run1 A1-r1 handback test-coverage
  run grade
  printf '%s\n' "$output" | grep -qE 'FP \(wrong owned skill\) +1'
  printf '%s\n' "$output" | grep -q 'intended=debug'
}

@test "grader: an orchestrator's documented fan-out is not a false positive" {
  fake_skills qa-full clean-code iac-scan daily-qa finish-branch
  # clean-code and iac-scan are in the grader's hard-coded FANOUT["qa-full"];
  # the fake SKILL.md body is irrelevant, only its existence makes them owned.
  transcript run1 C3-r1 handback qa-full clean-code iac-scan
  run grade
  printf '%s\n' "$output" | grep -qE 'TP \(intended fired\) +1 / 1'
  printf '%s\n' "$output" | grep -qE 'FP \(wrong owned skill\) +0'
}

@test "grader: skills loaded after the first handback are ignored (Stop-hook turns)" {
  fake_skills qa-full clean-code iac-scan daily-qa finish-branch
  # A second assistant turn, after the handback, loading an unrelated skill.
  transcript run1 C3-r1 handback qa-full
  python3 - "$TASKS/run1.output" <<'PY'
import json, sys
rec = {"type": "assistant", "message": {"content": [
    {"type": "tool_use", "name": "Skill", "input": {"skill": "daily-qa"}}]}}
with open(sys.argv[1], "a") as fh:
    fh.write(json.dumps(rec) + "\n")
PY
  run grade
  printf '%s\n' "$output" | grep -qE 'FP \(wrong owned skill\) +0'
  printf '%s\n' "$output" | grep -q 'C3-r1 .*qa-full'
}

# child_transcript <file> <case> — shaped like a subagent the skill under test
# spawned: it names the fixture dir but lacks the launcher's marker sentence.
child_transcript() {
  python3 -c '
import json, sys
out, case = sys.argv[1], sys.argv[2]
recs = [{"type": "user", "message": {"content":
         "Repo: /tmp/runs/before-" + case + ". Audit it for security issues."}},
        {"type": "assistant", "message": {"content": [
            {"type": "tool_use", "name": "Skill", "input": {"skill": "defense"}},
            {"type": "tool_use", "name": "SubagentHandback", "input": {"message": "done"}}]}}]
with open(out, "w") as fh:
    for r in recs:
        fh.write(json.dumps(r) + "\n")
' "$TASKS/$1.output" "$2"
}

@test "grader: a spawned subagent's transcript is not counted as a run of the case" {
  fake_skills daily-qa qa-full defense clean-code test-coverage
  transcript parent C2-r1 handback daily-qa
  # The parent fanned out; each child's prompt repeats the same fixture dir.
  child_transcript child1 C2-r1
  child_transcript child2 C2-r1
  run grade
  # One run, not three, and the children's own Skill calls are not scored.
  printf '%s\n' "$output" | grep -qE '^arm=before  runs=1$'
  printf '%s\n' "$output" | grep -qE 'TP \(intended fired\) +1 / 1'
  printf '%s\n' "$output" | grep -qE 'FP \(wrong owned skill\) +0'
}

@test "grader: a run set with only no-intended-skill cases does not divide by zero" {
  # B2's intended target is not an owned skill, so pos == 0. The awareness
  # lines divided by pos unguarded and crashed the whole report.
  fake_skills clean-code qa-full defense debug
  transcript run1 B2-r1 handback
  run grade
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -q 'Reply NAMES intended skill' || { echo "$output"; return 1; }
}

@test "grader: a skill merely MENTIONED by the intended skill is still a false positive" {
  # Fan-out must be real invocation, not any slash-mention: test-coverage's
  # SKILL.md names /debug as a neighbour, but it never invokes it, so debug
  # firing on a test-coverage case is a misroute that must be counted.
  fake_skills test-coverage debug tdd verify
  printf -- '---\nname: test-coverage\n---\nFor a failing test use /debug instead.\n' > "$SKILLS/test-coverage/SKILL.md"
  transcript run1 A2-r1 handback debug
  run grade
  printf '%s\n' "$output" | grep -qE 'FP \(wrong owned skill\) +1' || { echo "$output"; return 1; }
}

@test "grader: every FANOUT entry is a sub-skill its orchestrator's SKILL.md names" {
  # FANOUT is transcribed by hand; this stops it claiming fan-out the
  # orchestrator's own spec never mentions, which would hide real misroutes.
  run python3 - "$REPO_ROOT" <<'PY'
import importlib.util, os, re, sys
root = sys.argv[1]
spec = importlib.util.spec_from_file_location("g", os.path.join(root, "evals/_lib/grade-routing.py"))
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
bad = []
for orch, subs in g.FANOUT.items():
    body = open(os.path.join(root, "skills", orch, "SKILL.md")).read()
    bad += [f"{orch}->{s}" for s in sorted(subs) if not re.search(rf"/{re.escape(s)}\b", body)]
print(" ".join(bad))
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ -z "$output" ] || { echo "FANOUT entries missing from SKILL.md: $output"; return 1; }
}

@test "grader: a case id outside the suite is excluded, not a crash" {
  fake_skills debug test-coverage verify tdd
  transcript run1 A1-r1 handback debug
  transcript run2 A9-r1 handback debug
  run grade
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"A9-r1"* && "$output" == *"unknown case"* ]] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qE 'TP \(intended fired\) +1 / 1'
}

@test "grader: a single owned skill (no negative cells) reports n/a, not a crash" {
  fake_skills debug
  transcript run1 A1-r1 handback debug
  run grade
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qE 'TNR \(pooled over skills\) +n/a' || { echo "$output"; return 1; }
}
