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
  [ "$status" -eq 2 ]
  run bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "/"
  [ "$status" -eq 2 ]
  [[ "$output" == *usage* ]] || false
  [ ! -e "/skills" ]
  [ ! -e "/projects" ]
  run bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" --plain-names "/"
  [ "$status" -eq 2 ]
  mkdir -p "$BATS_TEST_TMPDIR/full"; touch "$BATS_TEST_TMPDIR/full/x"
  run bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$BATS_TEST_TMPDIR/full"
  [ "$status" -eq 2 ]
  [ ! -e "$BATS_TEST_TMPDIR/full/skills" ]
}

@test "prune eval fixture: plain-names tree hides roles and maps back to the same results" {
  d="$BATS_TEST_TMPDIR/p"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" --plain-names "$d"
  run grep -rliE 'dup|filler|quiet|neighbour|vend-|synthetic' "$d"
  [ "$status" -eq 1 ]
  [ -f "$d/vendor/skill-05/SKILL.md" ]
  key="$REPO_ROOT/evals/prune-skills/answer-key.json"
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_overlap.py" pairs "$d" --threshold 0.35
  [ "$status" -eq 0 ]
  run python3 -I -c 'import json,sys
m=json.load(open(sys.argv[1]))["plain_names_map"]
print(" ".join(m[n] for l in sys.stdin.read().splitlines() for n in l.split("\t")[1:]))' "$key" <<<"$output"
  [ "$output" = "dup-y dup-x" ] || [ "$output" = "dup-x dup-y" ]
  [ "$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["plain_names_map"]["skill-05"])' "$key")" = "vend-logs" ]
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_usage.py" "$d/projects"
  [[ "$output" == *$'skill-02\t30'* ]] || false
  [[ "$output" == *$'skill-08\t2'* ]] || false
  [[ "$output" != *"skill-06"* ]]
}

@test "debrief eval: public variant swaps only the visibility line" {
  d="$BATS_TEST_TMPDIR/v"; bash "$REPO_ROOT/evals/debrief/make_public_variant.sh" "$d"
  grep -q 'Visibility: PUBLIC' "$d/session.md"
  run diff "$REPO_ROOT/evals/debrief/session.md" "$d/session.md"
  [ "$(printf '%s\n' "$output" | grep -c '^[<>]')" -eq 2 ]
  run bash "$REPO_ROOT/evals/debrief/make_public_variant.sh" ""
  [ "$status" -eq 2 ]
}
