#!/usr/bin/env bash
# Build the synthetic prune-skills fixture under a directory you give it.
# Usage: make_tree.sh <dir> [40|10]
#   <dir>/skills/<name>/SKILL.md   12 flat skills (superskills layout)
#   <dir>/vendor/<name>/SKILL.md   1 vendored skill (the tools never walk vendor/)
#   <dir>/projects/proj/sNN.jsonl  N synthetic sessions (40 by default, or 10)
# Writes only under <dir>. Refuses an empty or "/" target or a non-empty one.
# Every name and line is invented; nothing is copied from a real transcript.
set -euo pipefail

dir="${1:-}"
sessions="${2:-40}"
if [ -z "$dir" ] || [ "$dir" = "/" ]; then
  echo "usage: make_tree.sh <dir> [40|10]  (dir must be non-empty and not /)" >&2
  exit 2
fi
case "$sessions" in 40 | 10) ;; *) echo "sessions must be 40 or 10" >&2; exit 2 ;; esac
if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
  echo "refusing to write into non-empty $dir" >&2
  exit 2
fi

skill() { # tree name description
  mkdir -p "$dir/$1/$2"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n# %s\n\nSynthetic fixture skill.\n' \
    "$2" "$3" "$2" > "$dir/$1/$2/SKILL.md"
}

# The planted duplicate: same job, near-identical wording.
skill skills dup-x "Rotate application log files: compress old logs, delete archives older than thirty days, and report the disk space freed."
skill skills dup-y "Rotate application log files: compress old logs, delete archives older than thirty days, and report disk space freed."
# Decoy: similar words, different jobs.
skill skills neighbour-a "Render invoice templates into printable documents with line items, totals and tax rows for customers."
skill skills neighbour-b "Parse invoice emails into structured ledger entries with vendor, amount and due date fields."
# Decoy: unique and never used.
skill skills quiet-unique "Calibrate telescope mirrors by measuring star trail drift across long exposures."
# Distinct filler.
skill skills filler-garden "Plan seasonal vegetable beds, companion planting and watering schedules."
skill skills filler-recipe "Scale cooking recipes by serving count and convert metric to imperial measures."
skill skills filler-chess "Analyse chess openings and suggest tactical puzzles by difficulty."
skill skills filler-travel "Build travel itineraries with transit times, lodging and budget breakdowns."
skill skills filler-music "Transpose sheet music between keys and annotate chord progressions."
skill skills filler-fitness "Design weekly strength training splits with progressive overload targets."
skill skills filler-poetry "Draft sonnets and haiku with syllable counting and rhyme scheme checks."
# Vendored skill that overlaps heavily with dup-x. Lives outside the flat trees.
skill vendor vend-logs "Rotate application log files: compress old logs, delete archives older than thirty days, and report the disk space freed."

proj="$dir/projects/proj"
mkdir -p "$proj"
call() { printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"%s"}}]}}\n' "$1"; }
typed() { printf '{"type":"user","message":{"role":"user","content":"<command-message>%s</command-message>\\n<command-name>/%s</command-name>"}}\n' "$1" "$1"; }
chat() { printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$1"; }

others=(filler-garden filler-recipe filler-chess filler-travel filler-music filler-fitness filler-poetry neighbour-a neighbour-b)
for ((i = 1; i <= sessions; i++)); do
  f=$(printf '%s/s%02d.jsonl' "$proj" "$i")
  {
    chat "synthetic request number $i"
    # dup-y is used in most sessions; dup-x in only two. quiet-unique never.
    if ((i % 4 != 0)); then call dup-y; fi
    if ((i == 3 || i == 17)); then typed dup-x; fi
    call "${others[$((i % ${#others[@]}))]}"
  } > "$f"
done
