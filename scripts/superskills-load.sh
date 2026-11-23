#!/usr/bin/env bash
# superskills-load.sh — load a skill pack's index, or one skill's full text, on demand.
# Usage: scripts/superskills-load.sh [--root <repo>] (--list | <pack> | <skill-name>)
#   --list         the packs and how many skills each holds
#   <pack>         design | marketing: a count header, then one line per skill (name,
#                  description cut to 80 chars), no bodies, so a pack stays small
#   <skill-name>   that skill's path and full text; a name in more than one tree
#                  resolves the way ./setup links it (skills/ > design-skills >
#                  marketing-skills) and the shadowed copies are named
# Read-only: nothing is installed, linked, or written.
set -e
LIB_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
ROOT="$LIB_ROOT"
TARGET=""
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)   [ $# -ge 2 ] || { echo "--root needs a path" >&2; exit 2; }; ROOT="$2"; shift 2 ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    --list)   LIST=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *)  TARGET="$1"; shift ;;
  esac
done
# shellcheck source=scripts/lib/skills-lib.sh
. "$LIB_ROOT/scripts/lib/skills-lib.sh"

# tree_files <tree> — every SKILL.md in one tree, sorted.
tree_files() {
  case "$1" in
    skills)           find "$ROOT/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f 2>/dev/null | LC_ALL=C sort ;;
    design-skills)    find "$ROOT/design-skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f 2>/dev/null | LC_ALL=C sort ;;
    marketing-skills) marketing_skill_files "$ROOT/marketing-skills" ;;
  esac
}
pack_tree() { case "$1" in design) echo design-skills ;; marketing) echo marketing-skills ;; esac; }

if [ "$LIST" -eq 1 ]; then
  for pack in design marketing; do
    n="$(tree_files "$(pack_tree "$pack")" | wc -l | tr -d ' ')"
    printf '%-10s %s skills\n' "$pack" "$n"
  done
  exit 0
fi

[ -n "$TARGET" ] || { echo "usage: superskills-load.sh [--root <repo>] (--list | <pack> | <skill-name>)" >&2; exit 2; }

# A pack: a count header, then name and a short description per skill. No
# paths (a skill loads by name) and descriptions are cut to 80 characters: the
# full marketing index was 66KB, which the harness truncates.
if [ -n "$(pack_tree "$TARGET")" ]; then
  files="$(tree_files "$(pack_tree "$TARGET")")"
  printf 'PACK %s: %s skills. Load one with /superskills <skill-name>.\n' \
    "$TARGET" "$(printf '%s\n' "$files" | grep -c .)"
  printf '%s\n' "$files" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    name="$(skill_name_from "$f" "$(basename "$(dirname "$f")")")"
    desc="$(skill_desc_from "$f" | cut -c1-80)"
    printf '%s\t%s\n' "$name" "$desc"
  done
  exit 0
fi

# A skill name: setup's override order. A name is never used as a path.
case "$TARGET" in
  */*|*..*) echo "not a skill or pack name: $TARGET" >&2; exit 1 ;;
esac
hits=()
for tree in skills design-skills marketing-skills; do
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    name="$(skill_name_from "$f" "$(basename "$(dirname "$f")")")"
    if [ "$name" = "$TARGET" ] || [ "$(basename "$(dirname "$f")")" = "$TARGET" ]; then hits+=("$f"); fi
  done < <(tree_files "$tree")
done
if [ ${#hits[@]} -eq 0 ]; then
  echo "no skill or pack named '$TARGET'. Packs: design marketing. Try --list." >&2
  exit 1
fi
echo "SKILL: ${hits[0]}"
for extra in "${hits[@]:1}"; do echo "also in: $extra (not loaded)"; done
echo
cat "${hits[0]}"
