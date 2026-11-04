#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
. "$SCRIPT_DIR/lib/skills-lib.sh"
rows="$(mktemp)"; trap 'rm -f "$rows"' EXIT
for f in "$TARGET"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  name="$(skill_name_from "$f" "$(basename "$(dirname "$f")")")"
  fm="$(skill_frontmatter_from "$f" | wc -c | tr -d ' ')"
  bd="$(skill_body_from "$f" | wc -c | tr -d ' ')"
  sd="$(find "$(dirname "$f")" -type f ! -name SKILL.md -exec cat {} + 2>/dev/null | wc -c | tr -d ' ')"
  printf '%s\t%s\t%s\t%s\n' "$name" "$fm" "$bd" "$sd"
done | sort > "$rows"
printf 'skill\tfrontmatter\tbody\tside\n'
cat "$rows"
awk -F'\t' '{f+=$2;b+=$3;s+=$4}END{printf "TOTAL\t%d\t%d\t%d\n",f,b,s}' "$rows"
