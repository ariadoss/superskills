#!/usr/bin/env bats
# debrief and prune-skills: file shape, boundaries, and registration.

setup() { REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"; }

# Skill prose is pinned only where the phrase is the contract (a safety rule or
# a gate number), and then on the shortest stable token. Everything else is
# checked by structure or by running the command lines the skill shows.

# run_block <skill> <HOME>: execute the skill's first bash block exactly as an
# agent would (the block that locates the repo), from outside any checkout.
run_block() {
  awk '/^```bash$/{f=1; next} f && /^```$/{exit} f' "$REPO_ROOT/skills/$1/SKILL.md" \
    | sed "s|^LESSON_FILE=[^ ]*|LESSON_FILE=$BATS_TEST_TMPDIR/lesson.txt|" > "$BATS_TEST_TMPDIR/block.sh"
  (cd "$BATS_TEST_TMPDIR" && env -u CLAUDE_PLUGIN_ROOT HOME="$2" SKILL_DIR="$REPO_ROOT/skills/$1" \
     bash "$BATS_TEST_TMPDIR/block.sh")
}

@test "both skills: frontmatter name equals the directory and the step headings run in order" {
  for s in prune-skills debrief; do
    f="$REPO_ROOT/skills/$s/SKILL.md"
    grep -qx "name: $s" "$f"
    nums="$(grep -oE '^## Step [0-9]+' "$f" | grep -oE '[0-9]+' | paste -sd ' ' -)"
    want=""; for ((i = 1; i <= $(grep -cE '^## Step [0-9]+' "$f"); i++)); do want="$want${want:+ }$i"; done
    [ "$nums" = "$want" ] || { echo "$s: $nums"; return 1; }
  done
}

@test "both skills name their neighbours with slash commands" {
  for t in skillify debrief; do grep -q "/$t" "$REPO_ROOT/skills/prune-skills/SKILL.md"; done
  for t in skillify handoff prune-skills; do grep -q "/$t" "$REPO_ROOT/skills/debrief/SKILL.md"; done
}

@test "prune-skills: the gate keeps its 30-session number and the never-delete rule" {
  f="$REPO_ROOT/skills/prune-skills/SKILL.md"
  grep -qi 'never delete' "$f"
  grep -q '30 sessions' "$f"
}

@test "prune-skills: the signal commands it shows run and print pairs, usage and budget" {
  d="$BATS_TEST_TMPDIR/t"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$d"
  H="$BATS_TEST_TMPDIR/h"; mkdir -p "$H/.claude"; cp -R "$d/projects" "$H/.claude/projects"
  run run_block prune-skills "$H"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "ROOT=$REPO_ROOT" ]
  [ "${#lines[@]}" -gt 3 ]
  [[ "$output" == *"dup-y"* ]] || false
}

@test "debrief: the proposes-only and public-repo rules are present" {
  f="$REPO_ROOT/skills/debrief/SKILL.md"
  grep -qi 'never write' "$f"
  grep -qi 'public repo' "$f"
}

@test "debrief: the lookup command it shows runs and prints name and score lines" {
  printf 'write a failing test first before implementation code\n' > "$BATS_TEST_TMPDIR/lesson.txt"
  run run_block debrief "$BATS_TEST_TMPDIR/emptyhome"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "ROOT=$REPO_ROOT" ]
  printf '%s\n' "${lines[@]:1}" | grep -qE '^[a-z0-9-]+'"$(printf '\t')"'[0-9.]+$'
}

@test "debrief: keeps the low-recall caveat, the no-quoting rule and the explicit-yes stop" {
  f="$REPO_ROOT/skills/debrief/SKILL.md"
  grep -qi 'low recall' "$f"
  grep -qi 'never quote' "$f"
  grep -qi 'explicit yes' "$f"
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

@test "prune eval fixture: default threshold also reports only the planted duplicate" {
  d="$BATS_TEST_TMPDIR/f"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$d"
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_overlap.py" pairs "$d"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 1 ]
  [[ "$output" == *"dup-x"*"dup-y"* ]] || false
}

@test "prune eval fixture: usage tool sees 40 and 10 sessions with dup-y used far more than dup-x" {
  d="$BATS_TEST_TMPDIR/f"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$d"
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_usage.py" "$d/projects"
  [[ "$output" == *"# sessions=40"* ]] || false
  [[ "$output" == *$'dup-y\t30'* ]] || false
  [[ "$output" == *$'dup-x\t2'* ]] || false
  e="$BATS_TEST_TMPDIR/g"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$e" 10
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_usage.py" "$e/projects"
  [[ "$output" == *"# sessions=10"* ]] || false
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
  [[ "$output" != *"skill-06"* ]] || false
}

@test "prune eval fixture: plain-names tree at the default threshold maps to the same pair" {
  d="$BATS_TEST_TMPDIR/p"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" --plain-names "$d"
  key="$REPO_ROOT/evals/prune-skills/answer-key.json"
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_overlap.py" pairs "$d"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 1 ]
  run python3 -I -c 'import json,sys
m=json.load(open(sys.argv[1]))["plain_names_map"]
print(" ".join(m[n] for l in sys.stdin.read().splitlines() for n in l.split("\t")[1:]))' "$key" <<<"$output"
  [ "$output" = "dup-y dup-x" ] || [ "$output" = "dup-x dup-y" ]
}

@test "debrief: lesson goes in on stdin, never inside double quotes" {
  f="$REPO_ROOT/skills/debrief/SKILL.md"
  grep -q -- '--stdin' "$f"
  run grep -F '"<the lesson' "$f"
  [ "$status" -eq 1 ]
}

@test "debrief: the lesson reaches the tool through a file, with no here-document in the skill" {
  run grep -nE '<<-?[[:space:]]*["'"'"']?[A-Za-z_]' "$REPO_ROOT/skills/debrief/SKILL.md"
  [ "$status" -eq 1 ]
  grep -q -- '--stdin.*< "\$LESSON_FILE"' "$REPO_ROOT/skills/debrief/SKILL.md"
}

@test "overlap query --stdin reads hostile lesson text from a file without executing it" {
  d="$BATS_TEST_TMPDIR/f"; bash "$REPO_ROOT/evals/prune-skills/make_tree.sh" "$d"
  X="$BATS_TEST_TMPDIR/pwned"
  printf '%s\n' 'first line' 'LESSON' "\$(touch $X)" "\`touch $X\`" "it's \"quoted\"" > "$BATS_TEST_TMPDIR/lesson.txt"
  run python3 -I "$REPO_ROOT/scripts/skill-census/skill_overlap.py" query "$d" --stdin --top 3 < "$BATS_TEST_TMPDIR/lesson.txt"
  [ "$status" -eq 0 ]
  [ ! -e "$X" ]
}

@test "debrief eval: public variant swaps only the visibility line" {
  d="$BATS_TEST_TMPDIR/v"; bash "$REPO_ROOT/evals/debrief/make_public_variant.sh" "$d"
  grep -q 'Visibility: PUBLIC' "$d/session.md"
  run diff "$REPO_ROOT/evals/debrief/session.md" "$d/session.md"
  [ "$(printf '%s\n' "$output" | grep -c '^[<>]')" -eq 2 ]
  run bash "$REPO_ROOT/evals/debrief/make_public_variant.sh" ""
  [ "$status" -eq 2 ]
}
