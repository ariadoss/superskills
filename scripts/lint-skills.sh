#!/usr/bin/env bash
# lint-skills.sh [<repo-root>] — lint this checkout's skill trees.
#
# Policy (owned here, not in the lib): skills/ and design-skills/ are flat
# trees where name==dir is an invariant; marketing-skills/ is nested by
# design and named by frontmatter via the generated shim tree, so it gets
# duplicate-name and description checks only. The generated
# marketing-skills/plugin-skills/ shim tree and vendored environments are
# excluded (marketing_skill_files already prunes them). Read-only: findings
# name their fix, nothing is edited.
set -u
# The libs come from the SCRIPT's own checkout (it may be pointed at an
# arbitrary target root); the trees walked come from the TARGET. Findings
# always name ABSOLUTE paths — a finding about an arbitrary root must be
# unambiguous about which checkout it names.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
[ -d "$TARGET" ] || { echo "lint-skills: cannot enter $TARGET" >&2; exit 2; }

# shellcheck source=lib/skills-lib.sh
. "$SCRIPT_DIR/lib/skills-lib.sh"
# shellcheck source=lib/skills-lint.sh
. "$SCRIPT_DIR/lib/skills-lint.sh"

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT

flat_paths() {
  local f d
  for f in "$TARGET"/skills/*/SKILL.md "$TARGET"/design-skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    d="$(basename "$(dirname "$f")")"
    [ "$d" = "node_modules" ] && continue
    printf '%s\n' "$f"
  done
}

flat_paths > "$TMP/flat.paths"
# A failed marketing walk must surface, not silently narrow coverage: a
# newline in the root path is the one guarded error, and it is a finding here.
if ! marketing_skill_files "$TARGET/marketing-skills" > "$TMP/mkt.paths"; then
  echo "lint-skills: marketing walk failed — duplicate/description checks for marketing-skills did not run" >&2
  exit 2
fi

lint_name_dir "$TARGET/skills"        >> "$TMP/findings"
lint_name_dir "$TARGET/design-skills" >> "$TMP/findings"
lint_dup_names    < "$TMP/flat.paths" >> "$TMP/findings"
lint_descriptions < "$TMP/flat.paths" >> "$TMP/findings"
[ -s "$TMP/mkt.paths" ] && {
  lint_missing_names < "$TMP/mkt.paths" >> "$TMP/findings"
  lint_dup_names     < "$TMP/mkt.paths" >> "$TMP/findings"
  lint_descriptions  < "$TMP/mkt.paths" >> "$TMP/findings"
}

if [ -s "$TMP/findings" ]; then
  cat "$TMP/findings"
  echo "skills-lint: $(wc -l < "$TMP/findings" | tr -d ' ') finding(s). Fixes: rename the directory or edit the frontmatter name (name-dir-drift, missing-name), rename one claimant (duplicate-name), add the line (missing-description)."
  exit 1
fi
echo "skills-lint: clean (skills, design-skills, marketing-skills)"
