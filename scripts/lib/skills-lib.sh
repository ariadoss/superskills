#!/usr/bin/env bash
# skills-lib.sh — pure, sourceable helpers for resolving and linking skills.
#
# Extracted from setup so the linking logic has a single source of truth (DRY)
# and one responsibility per function (SOLID), and can be unit-tested in
# isolation without running the full installer (which clones gstack, installs
# bun, etc.). See tests/skills-lib.bats.
#
# These functions never mutate the source tree. link_skill_into only writes
# symlinks under the target dir it is given.

# skill_name_from <skill_md> [fallback]
# Echo a skill's canonical name from its `name:` frontmatter, else the fallback.
# Echoes empty string if neither is available.
skill_name_from() {
  local skill_md="$1" fallback="${2:-}" name
  name=$(grep -m1 '^name:' "$skill_md" 2>/dev/null | sed 's/^name:[[:space:]]*//' | tr -d '[:space:]')
  [ -z "$name" ] && name="$fallback"
  printf '%s' "$name"
}

# skill_desc_from <skill_md>
# Echo the first line of a skill's description (single-line or block form).
# Falls back to "skill" if none is found.
skill_desc_from() {
  local skill_md="$1" desc
  desc=$(grep -m1 '^description:' "$skill_md" 2>/dev/null \
        | sed 's/^description:[[:space:]]*//' \
        | sed 's/[[:space:]]*|[[:space:]]*$//')
  if [ -z "$desc" ] || [ "$desc" = "|" ]; then
    desc=$(awk '
      /^description:/ { found=1; next }
      found && /^[[:space:]]/ { gsub(/^[[:space:]]+/, ""); if (length > 0) { print; exit } }
      found && /^[^[:space:]]/ { exit }
    ' "$skill_md" 2>/dev/null)
  fi
  printf '%s' "${desc:-skill}"
}

# skill_body_from <skill_md>
# Echo the markdown body (everything after the second `---` frontmatter fence).
skill_body_from() {
  awk 'BEGIN{n=0}/^---/{n++;next}n>=2{print}' "$1"
}

# link_skill_into <base_dir> <skill_md> [fallback] [link_extras] [name_prefix]
# Symlink a skill's SKILL.md (and, when link_extras=1, its sibling files) into
# <base_dir>/<name_prefix><name>. Echoes the resolved name on success.
# Returns 1 (no output) when the skill has no resolvable name.
#   link_extras : 1 (default) also links sibling files; 0 links only SKILL.md
#   name_prefix : optional prefix on the target dir name (e.g. "superskills-")
link_skill_into() {
  local base_dir="$1" skill_md="$2" fallback="${3:-}" link_extras="${4:-1}" name_prefix="${5:-}"
  local skill_dir name target extra extra_name
  skill_dir="$(dirname "$skill_md")"
  name="$(skill_name_from "$skill_md" "$fallback")"
  [ -z "$name" ] && return 1
  target="$base_dir/${name_prefix}${name}"
  mkdir -p "$target"
  [ -L "$target/SKILL.md" ] && rm "$target/SKILL.md"
  ln -snf "$skill_md" "$target/SKILL.md"
  if [ "$link_extras" = "1" ]; then
    for extra in "$skill_dir"/*; do
      extra_name="$(basename "$extra")"
      [ "$extra_name" = "SKILL.md" ] && continue
      [ -L "$target/$extra_name" ] && rm "$target/$extra_name"
      ln -snf "$extra" "$target/$extra_name"
    done
  fi
  printf '%s' "$name"
}
