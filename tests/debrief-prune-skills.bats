#!/usr/bin/env bats
# debrief and prune-skills: file shape, boundaries, and registration.

setup() { REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"; }

@test "prune-skills: name equals directory and a boundary names the neighbours" {
  f="$REPO_ROOT/skills/prune-skills/SKILL.md"
  [ -f "$f" ]
  grep -q '^name: prune-skills$' "$f"
  grep -q '/skillify' "$f"
  grep -q '/debrief' "$f"
}

@test "prune-skills: refuses to delete without overlap evidence and a usage window" {
  f="$REPO_ROOT/skills/prune-skills/SKILL.md"
  grep -qi 'never delete' "$f"
  grep -q '30 sessions' "$f"
}

@test "debrief: name equals directory and boundaries name the neighbours" {
  f="$REPO_ROOT/skills/debrief/SKILL.md"
  [ -f "$f" ]
  grep -q '^name: debrief$' "$f"
  grep -q '/skillify' "$f"
  grep -q '/handoff' "$f"
  grep -q '/prune-skills' "$f"
}

@test "debrief: proposes only and protects public repos" {
  f="$REPO_ROOT/skills/debrief/SKILL.md"
  grep -qi 'never write' "$f"
  grep -qi 'public repo' "$f"
}

@test "debrief: checks existing coverage with the overlap tool" {
  grep -q 'skill_overlap.py" query' "$REPO_ROOT/skills/debrief/SKILL.md"
}

@test "debrief: states the low-recall limit and the no-quoting rule" {
  f="$REPO_ROOT/skills/debrief/SKILL.md"
  grep -qi 'low recall' "$f"
  grep -qi 'does NOT mean no skill covers' "$f"
  grep -qi 'never quote' "$f"
  grep -qi 'explicit yes' "$f"
}

@test "prune eval fixture: overlap tool finds the planted duplicate and not the decoys" {
  d="$BATS_TEST_TMPDIR/f"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$d"
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_overlap.py" pairs "$d" --threshold 0.35
  [[ "$output" == *"dup-x"*"dup-y"* ]] || false
  [[ "$output" != *"quiet-unique"* ]] || false
  [[ "$output" != *"neighbour"* ]] || false
}

@test "prune eval fixture: usage tool sees 40 and 10 sessions with dup-y used far more than dup-x" {
  d="$BATS_TEST_TMPDIR/f"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$d"
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_usage.py" "$d/projects"
  [[ "$output" == *"# sessions=40"* ]] || false
  [[ "$output" == *$'dup-y\t30'* ]] || false
  [[ "$output" == *$'dup-x\t2'* ]] || false
  e="$BATS_TEST_TMPDIR/g"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$e" 10
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_usage.py" "$e/projects"
  [[ "$output" == *"# sessions=10"* ]]
}

@test "prune eval fixture: builder refuses an empty target, root and a non-empty directory" {
  run bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" ""
  [ "$status" -ne 0 ]
  run bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "/"
  [ "$status" -ne 0 ]
  mkdir -p "$BATS_TEST_TMPDIR/full"; touch "$BATS_TEST_TMPDIR/full/x"
  run bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$BATS_TEST_TMPDIR/full"
  [ "$status" -ne 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/full/skills" ]
}
