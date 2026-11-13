#!/usr/bin/env bash
# qa-triggers.sh <db|ui> [base-ref]
#
# Decides whether /db-optimize (db) or /qa (ui) is owed for the current branch,
# so /qa-full and /daily-qa never mark them NOT-TRIGGERED on a folder-name miss.
# Looks at file names AND at what the diff adds, in any language or framework.
#
# Compares the working tree (committed + uncommitted + untracked) to
# merge-base(base-ref, HEAD). Docs, tests, vendored trees and prose never count.
#
# Exit 0 = triggered; stdout lists "path: reason" evidence, one per line.
# Exit 1 = not triggered; stdout says what was searched, quote it in the ledger.
# Exit 2 = usage error or unknown ref.
# Tested in tests/qa-triggers.bats.

set -uo pipefail

kind="${1:-}"
ref="${2:-main}"
case "$kind" in
  db | ui) ;;
  *) echo "usage: qa-triggers.sh <db|ui> [base-ref]" >&2; exit 2 ;;
esac
export LC_ALL=C # byte-wise matching: invalid UTF-8 in a changed line must not defeat '.'
case "$ref" in -*) echo "qa-triggers: ref '$ref' looks like an option" >&2; exit 2 ;; esac
top="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$top" ] && cd "$top" || { echo "qa-triggers: not in a git work tree" >&2; exit 2; }
base="$(git merge-base "$ref" HEAD 2>/dev/null)" || { echo "qa-triggers: unknown ref '$ref'" >&2; exit 2; }

IGNORED_PATH='(^|/)(docs?|tests?|__tests__|spec|node_modules|vendor|dist|build|__pycache__|\.git)/|\.pyc$|(^|/)test_[^/]*$|_test\.[a-z]+$|\.(test|spec)\.[a-z]+$|\.(md|txt|rst)$'

DB_PATH_DIR='(^|/)(models?|migrations?|queries|dao|repositor(y|ies))/'
DB_PATH_NAME='(^|/)[^/]*(schema|migrat|statements?|queries|query|repositor|dao)[^/]*\.[a-z]+$|\.sql$'
# Matched case-insensitively (grep -i): lowercase SQL and ORM calls count too.
DB_CONTENT='(^|[^A-Za-z])(SELECT[[:space:]].*[[:space:]]FROM[[:space:]]+[^[:space:]]|INSERT[[:space:]]+INTO|UPDATE[[:space:]]+[A-Za-z_."]+[[:space:]]+SET|DELETE[[:space:]]+FROM|MERGE[[:space:]]+INTO|TRUNCATE[[:space:]]+TABLE|(CREATE|DROP)[[:space:]]+(UNIQUE[[:space:]]+|TEMP(ORARY)?[[:space:]]+)?(TABLE|INDEX)|ALTER[[:space:]]+TABLE)|\.(execute|executemany|executescript)\(|\.(preload|includes|select_related|prefetch_related)\(|\.objects\.|session\.query\(|\.find(Many|All|One|ByPk)\(|\.raw\('

UI_PATH_EXT='\.(tsx|jsx|vue|svelte|astro|css|scss|sass|less|html?|jinja2?|j2|erb|haml|hbs|ejs|liquid|twig)$'
UI_PATH_DIR='(^|/)(components|pages|views|templates|static|public|assets)/'

files="$({ git -c core.quotePath=false diff --name-only "$base"; git -c core.quotePath=false ls-files --others --exclude-standard; } | sort -u | grep -Ev "$IGNORED_PATH")"
n="$(printf '%s' "$files" | grep -c .)"

added_lines() { # path -> lines this branch adds (all of an untracked file)
  [ -f "$1" ] && [ ! -L "$1" ] || return 0
  if git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; then
    git diff --no-color --no-ext-diff --no-textconv -U0 "$base" -- "$1" | awk '/^diff /{h=0;next} /^@@/{h=1;next} h && /^\+/'
  else
    cat -- "$1" 2>/dev/null
  fi
}

evidence=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ "$kind" = db ]; then
    if printf '%s' "$f" | grep -Eiq "$DB_PATH_DIR|$DB_PATH_NAME"; then
      evidence+="$f: database file name"$'\n'
    elif added="$(added_lines "$f")"; grep -Eiq "$DB_CONTENT" <<<"$added"; then # here-string, not a pipe: grep -q would SIGPIPE the producer and pipefail would hide the match
      evidence+="$f: adds SQL or a database call"$'\n'
    fi
  else
    if printf '%s' "$f" | grep -Eiq "$UI_PATH_EXT|$UI_PATH_DIR"; then
      evidence+="$f: UI file"$'\n'
    fi
  fi
done <<<"$files"

if [ -n "$evidence" ]; then
  printf '%s' "$evidence"
  exit 0
fi

if [ "$kind" = db ]; then what="database file names (schema, migration, statements, query, repository, dao, models/, *.sql) and added SQL or database calls"
else what="UI file types (html, jinja, tsx, vue, css, ...) and UI folders (templates, static, components, pages, views)"; fi
echo "not triggered: searched $n changed file(s) against base ${base:0:8} for $what; nothing matched."
exit 1
