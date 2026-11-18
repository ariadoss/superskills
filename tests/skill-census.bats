#!/usr/bin/env bats
# skill-census: the shared skill loader, overlap scorer and usage counter.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CENSUS="$REPO_ROOT/scripts/skill-census"
  FIX="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$FIX/skills" "$FIX/vendor/gstack/qa" "$FIX/marketing-skills/x"
}

_skill() { # <root-relative dir> <name> <description>
  mkdir -p "$FIX/$1"
  printf -- '---\nname: %s\ndescription: |\n  %s\n---\nbody\n' "$2" "$3" > "$FIX/$1/SKILL.md"
}

@test "index: loads flat skills, excludes vendor and marketing" {
  _skill skills/alpha alpha "reviews diffs for bugs"
  _skill vendor/gstack/qa qa "vendored upstream skill"
  _skill marketing-skills/x/y y "generated shim"
  run python3 -I "$CENSUS/skill_index.py" "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alpha"* ]] || false
  [[ "$output" != *"vendored"* ]] || false
  [[ "$output" != *"y"$'\t'"marketing-skills"* ]] || false
  [[ "$output" != *"qa"$'\t'"vendor"* ]] || false
}

@test "index: a hostile name never becomes a path" {
  _skill skills/evil "../../etc/x" "does evil things"
  run python3 -I "$CENSUS/skill_index.py" "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skills/evil"* ]]
}

_raw() { # <root-relative dir> <full SKILL.md content>
  mkdir -p "$FIX/$1"
  printf '%s\n' "$2" > "$FIX/$1/SKILL.md"
}

@test "index: agrees with the bash parser on name and description, skills and design-skills" {
  . "$REPO_ROOT/scripts/lib/skills-lib.sh"
  out="$(python3 -I "$CENSUS/skill_index.py" "$REPO_ROOT")"
  for f in "$REPO_ROOT"/skills/*/SKILL.md "$REPO_ROOT"/design-skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    d="$(basename "$(dirname "$f")")"
    tree="$(basename "$(dirname "$(dirname "$f")")")"
    bash_name="$(skill_name_from "$f" "$d")"
    py_name="$(printf '%s\n' "$out" | awk -F'\t' -v d="$tree/$d" '$2==d{print $1}')"
    [ "$bash_name" = "$py_name" ] || { echo "$tree/$d: bash=$bash_name py=$py_name"; return 1; }
    bash_desc="$(skill_desc_from "$f")"
    py_desc="$(python3 -I -c '
import sys
sys.path.insert(0, sys.argv[1])
import skill_index
for s in skill_index.load_skills(sys.argv[2]):
    if s["dir"] == sys.argv[3]:
        print(s["description"])
' "$CENSUS" "$REPO_ROOT" "$tree/$d")"
    # bash returns the first description line; python joins all lines.
    [[ "$py_desc" == "$bash_desc"* ]] || { echo "$tree/$d: bash=[$bash_desc] py=[$py_desc]"; return 1; }
  done
}

@test "index: empty name falls back to the directory name" {
  _raw skills/dirname $'---\nname:\ndescription: x\n---\nbody'
  run python3 -I "$CENSUS/skill_index.py" "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" == "dirname"$'\t'"skills/dirname"* ]] || false
}

@test "index: internal whitespace in name is removed, like bash" {
  _raw skills/ws $'---\nname: a b  c\ndescription: x\n---\nbody'
  run python3 -I "$CENSUS/skill_index.py" "$FIX"
  [[ "$output" == "abc"$'\t'"skills/ws"* ]] || false
}

# Accepted divergences from bash (pinned so a change is deliberate).
@test "index: quoted name is unquoted (bash keeps the quotes)" {
  _raw skills/q $'---\nname: "quoted"\ndescription: x\n---\nbody'
  run python3 -I "$CENSUS/skill_index.py" "$FIX"
  [[ "$output" == "quoted"$'\t'"skills/q"* ]] || false
}

@test "index: a name: line outside frontmatter is ignored (bash greps the whole file)" {
  _raw skills/body $'---\ndescription: x\n---\nname: sneaky'
  run python3 -I "$CENSUS/skill_index.py" "$FIX"
  [[ "$output" == "body"$'\t'"skills/body"* ]] || false
}

@test "overlap pairs: a near-duplicate pair is reported, an unrelated one is not" {
  _skill skills/a-review a-review "review pending code changes for correctness bugs and security risks before merge"
  _skill skills/b-review b-review "review pending code changes for correctness bugs and security issues before merge"
  _skill skills/c-pricing c-pricing "set subscription pricing tiers and packaging for a startup"
  run python3 -I "$CENSUS/skill_overlap.py" pairs "$FIX" --threshold 0.5
  [ "$status" -eq 0 ]
  [[ "$output" == *"a-review"*"b-review"* ]] || false
  [[ "$output" != *"c-pricing"* ]] || false
}

@test "overlap query: a lesson ranks the skill that already covers it first" {
  _skill skills/a-review a-review "review pending code changes for correctness bugs"
  _skill skills/c-pricing c-pricing "set subscription pricing tiers"
  run python3 -I "$CENSUS/skill_overlap.py" query "$FIX" "always review code changes for correctness bugs" --top 1
  [ "$status" -eq 0 ]
  [[ "$output" == a-review* ]] || false
}

@test "overlap: empty tree prints nothing and exits 0" {
  run python3 -I "$CENSUS/skill_overlap.py" pairs "$FIX"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "usage: counts Skill calls and typed commands per skill" {
  run python3 -I "$CENSUS/skill_usage.py" "$REPO_ROOT/tests/fixtures/census/transcripts" --days 3650
  [ "$status" -eq 0 ]
  [[ "$output" == *$'review\t2'* ]] || false
  [[ "$output" == *$'qa-full\t1'* ]] || false
  [[ "$output" == *$'clean-code\t1'* ]] || false
}

@test "usage: reports how many sessions it scanned" {
  run python3 -I "$CENSUS/skill_usage.py" "$REPO_ROOT/tests/fixtures/census/transcripts" --days 3650
  [[ "$output" == *"# sessions=2"* ]] || false
}

@test "usage: never prints message content" {
  run python3 -I "$CENSUS/skill_usage.py" "$REPO_ROOT/tests/fixtures/census/transcripts" --days 3650
  [ "$status" -eq 0 ]
  [[ "$output" != *"hunter2"* ]] || false
  [[ "$output" != *"password"* ]] || false
}

@test "usage: files older than the window are ignored" {
  cp -r "$REPO_ROOT/tests/fixtures/census/transcripts" "$BATS_TEST_TMPDIR/t"
  touch -t 202001010000 "$BATS_TEST_TMPDIR/t/s1.jsonl"
  run python3 -I "$CENSUS/skill_usage.py" "$BATS_TEST_TMPDIR/t" --days 30
  [ "$status" -eq 0 ]
  [[ "$output" == *"# sessions=1"* ]] || false
  [[ "$output" != *$'review\t'* ]] || false
}
