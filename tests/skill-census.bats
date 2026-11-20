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
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 1 ]
  [[ "$output" != *"y"$'\t'"marketing-skills"* ]] || false
  [[ "$output" != *"qa"$'\t'"vendor"* ]] || false
}

@test "index: a hostile name never becomes a path" {
  _skill skills/evil "../../etc/x" "does evil things"
  run python3 -I "$CENSUS/skill_index.py" "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skills/evil"* ]] || false
  dircol="$(printf '%s\n' "$output" | cut -f2)"
  [[ "$dircol" != *"../"* ]] || false
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

@test "overlap query: --stdin reads the lesson, quotes and dollar signs included" {
  _skill skills/a-review a-review "review pending code changes for correctness bugs"
  run bash -c 'printf "%s\n" "always review \"code\" changes \$(x) for correctness bugs" | python3 -I "$0" query "$1" --stdin --top 1' "$CENSUS/skill_overlap.py" "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" == a-review* ]] || false
}

@test "overlap query: no lesson text exits 2 with a message" {
  run python3 -I "$CENSUS/skill_overlap.py" query "$FIX"
  [ "$status" -eq 2 ]
  [[ "$output" == *"query needs the lesson text"* ]] || false
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
  [[ "$output" == *"# sessions=2 subagent_files=1"* ]] || false
}

@test "usage: a plugin prefix is stripped when counting" {
  mkdir -p "$BATS_TEST_TMPDIR/pp"
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"plug:review"}}]}}' > "$BATS_TEST_TMPDIR/pp/s.jsonl"
  run python3 -I "$CENSUS/skill_usage.py" "$BATS_TEST_TMPDIR/pp"
  [[ "$output" == *$'review\t1'* ]] || false
}

@test "transcripts: top_level_only skips subagent files, default keeps them" {
  run python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import transcripts as t
d=sys.argv[2]
print(len(t.session_files(d)), len(t.session_files(d, top_level_only=True)))' "$REPO_ROOT/scripts/lib" "$REPO_ROOT/tests/fixtures/census/transcripts"
  [ "$output" = "3 2" ]
}

@test "transcripts: a broken symlink does not raise when a window is set" {
  mkdir -p "$BATS_TEST_TMPDIR/bl"
  ln -s "$BATS_TEST_TMPDIR/nowhere" "$BATS_TEST_TMPDIR/bl/dead.jsonl"
  run python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import transcripts as t
print(len(t.session_files(sys.argv[2], days=30)))' "$REPO_ROOT/scripts/lib" "$BATS_TEST_TMPDIR/bl"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "transcripts: errors policy is a parameter (replace by default, ignore for the miner)" {
  printf '{"a":"x\xffy"}\n' > "$BATS_TEST_TMPDIR/bad.jsonl"
  run python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import transcripts as t
print(next(t.iter_entries(sys.argv[2]))["a"].encode("unicode_escape").decode(), next(t.iter_entries(sys.argv[2], errors="ignore"))["a"])' "$REPO_ROOT/scripts/lib" "$BATS_TEST_TMPDIR/bad.jsonl"
  [ "$output" = 'x\ufffdy xy' ]
}

@test "usage: an unreadable transcript (a directory named *.jsonl) is skipped, not fatal" {
  mkdir -p "$FIX/projects/p/dir.jsonl"
  run python3 -I "$CENSUS/skill_usage.py" "$FIX/projects" --days 90
  [ "$status" -eq 0 ]
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
  [[ "$output" == *"# sessions=1 "* ]] || false
  [[ "$output" != *$'review\t'* ]] || false
}
