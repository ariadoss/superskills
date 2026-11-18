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
  [[ "$output" == *"alpha"* ]]
  [[ "$output" != *"vendored upstream"* ]]
  [[ "$output" != *"generated shim"* ]]
}

@test "index: a hostile name never becomes a path" {
  _skill skills/evil "../../etc/x" "does evil things"
  run python3 -I "$CENSUS/skill_index.py" "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skills/evil"* ]]
}

@test "index: agrees with the bash parser on the real repo" {
  . "$REPO_ROOT/scripts/lib/skills-lib.sh"
  for f in "$REPO_ROOT"/skills/*/SKILL.md; do
    d="$(basename "$(dirname "$f")")"
    bash_name="$(skill_name_from "$f" "$d")"
    py_name="$(python3 -I "$CENSUS/skill_index.py" "$REPO_ROOT" | awk -F'\t' -v d="$d" '$2=="skills/"d{print $1}')"
    [ "$bash_name" = "$py_name" ] || { echo "$d: bash=$bash_name py=$py_name"; return 1; }
  done
}
