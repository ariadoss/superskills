#!/usr/bin/env bats
# skills-lint — the skill-tree lint checks (name/dir drift, duplicate
# frontmatter names, missing descriptions), hermetic over fixture trees,
# plus the runner's clean/dirty/error paths and the live-repo assertion.

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
  out="$(printf '%s\n%s\n' "$FIX/alpha/SKILL.md" "$FIX/beta/SKILL.md" | lint_name_dir)" || false
  [ -z "$out" ] || false
}

@test "name-dir: frontmatter name differing from directory is drift with remediation" {
  _make_skill alpha alpha-x "does alpha things"
  out="$(printf '%s\n' "$FIX/alpha/SKILL.md" | lint_name_dir)" || false
  [[ "$out" == "name-dir-drift: $FIX/alpha/SKILL.md: frontmatter name \"alpha-x\" ≠ directory \"alpha\" — "* ]] || false
}

@test "name-dir: missing frontmatter name gets its own kind" {
  mkdir -p "$FIX/alpha"
  printf -- '---\ndescription: d\n---\n\nbody\n' > "$FIX/alpha/SKILL.md"
  out="$(printf '%s\n' "$FIX/alpha/SKILL.md" | lint_name_dir)" || false
  [[ "$out" == "missing-name: $FIX/alpha/SKILL.md: no frontmatter name — "* ]] || false
}

@test "dup-names: second claimant of a name is flagged, first is not" {
  _make_skill alpha alpha "does alpha things"
  _make_skill beta alpha "also claims alpha"
  out="$(printf '%s\n%s\n' "$FIX/alpha/SKILL.md" "$FIX/beta/SKILL.md" | lint_dup_names)" || false
  [[ "$out" == "duplicate-name: $FIX/beta/SKILL.md: "* ]] || false
  [[ "$out" != *"$FIX/alpha/SKILL.md"* ]] || false
}

@test "dup-names: a triple emits for 2nd and 3rd, first stays canonical" {
  _make_skill alpha alpha "a"
  _make_skill beta alpha "b"
  _make_skill gamma alpha "c"
  out="$(printf '%s\n%s\n%s\n' "$FIX/alpha/SKILL.md" "$FIX/beta/SKILL.md" "$FIX/gamma/SKILL.md" | lint_dup_names)" || false
  [ "$(printf '%s\n' "$out" | grep -c 'duplicate-name:')" -eq 2 ] || false
  [[ "$out" != *"$FIX/alpha/SKILL.md"* ]] || false
}

@test "dup-names: unique names emit nothing" {
  _make_skill alpha alpha "a"
  _make_skill beta beta "b"
  out="$(printf '%s\n%s\n' "$FIX/alpha/SKILL.md" "$FIX/beta/SKILL.md" | lint_dup_names)" || false
  [ -z "$out" ] || false
}

@test "missing-names: marketing skill with no name line is flagged" {
  _make_skill alpha alpha "does alpha things"
  rm "$FIX/alpha/SKILL.md"
  printf -- '---\ndescription: d\n---\n\nbody\n' > "$FIX/alpha/SKILL.md"
  out="$(printf '%s\n' "$FIX/alpha/SKILL.md" | lint_missing_names)" || false
  [[ "$out" == "missing-name: $FIX/alpha/SKILL.md: "* ]] || false
}

@test "missing-names: present name line emits nothing" {
  _make_skill alpha alpha "does alpha things"
  out="$(printf '%s\n' "$FIX/alpha/SKILL.md" | lint_missing_names)" || false
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

@test "runner: marketing skill without a description is flagged (positive pin of the description check)" {
  mkdir -p "$ROOT/marketing-skills/seo/one" "$ROOT/marketing-skills/seo/two"
  _make_skill_at "$ROOT/marketing-skills/seo/one" one "has a description"
  mkdir -p "$ROOT/marketing-skills/seo/two"
  printf -- '---\nname: two\n---\n\nbody\n' > "$ROOT/marketing-skills/seo/two/SKILL.md"
  run bash "$REPO_ROOT/scripts/lint-skills.sh" "$ROOT"
  [ "$status" -eq 1 ] || false
  [[ "$output" == *"missing-description: $ROOT/marketing-skills/seo/two/SKILL.md: "* ]] || false
}

@test "runner: a newline in the target root fails the marketing walk loudly (exit 2)" {
  BAD="$BATS_TEST_TMPDIR/bad"$'\n'"root"
  mkdir -p "$BAD/skills/alpha"
  _make_skill_at "$BAD/skills/alpha" alpha "does alpha"
  run bash "$REPO_ROOT/scripts/lint-skills.sh" "$BAD"
  [ "$status" -eq 2 ] || false
  [[ "$output" == *"marketing walk failed"* ]] || false
}

@test "runner: a nonexistent target root exits 2 with the guard line" {
  run bash "$REPO_ROOT/scripts/lint-skills.sh" "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 2 ] || false
  [[ "$output" == *"cannot enter"* ]] || false
}

@test "the repo's own skill trees lint clean" {
  run bash "$REPO_ROOT/scripts/lint-skills.sh"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"skills-lint: clean"* ]] || false
}
