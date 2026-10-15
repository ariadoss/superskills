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

# lint_missing_names — SKILL.md paths on stdin; every skill needs a literal
# frontmatter `name:` line. For flat trees lint_name_dir already covers this
# (its missing-name kind); this predicate serves the marketing tree, where
# the batch parsers' directory-name fallback would otherwise silently stand
# in for a missing name (codex outside-review finding, 2026-10-15).
lint_missing_names() {
  local path
  while IFS= read -r path; do
    if ! grep -q -m1 '^name:' "$path" 2>/dev/null; then
      _lint_emit missing-name "$path" "no frontmatter name line" \
        "add 'name: <slug>' — the shim tree and duplicate check key on it"
    fi
  done
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
