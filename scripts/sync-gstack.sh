#!/usr/bin/env bash
# Refresh vendor/gstack/ from a gstack git checkout.
#
# gstack (github.com/garrytan/gstack) is installed at runtime by ./setup into
# ~/.claude/skills/gstack. This repo keeps a markdown-only snapshot of its skill
# definitions in vendor/gstack/ so the skills stay readable (and the docs stay
# accurate) even if the upstream disappears. The snapshot is the instruction
# content only — SKILL.md files plus the sections/, specialists/, templates/,
# references/ and checklist markdown those bodies load at runtime, VERSION,
# CLAUDE.md, docs/*.md, and gstack's own `setup` script (this repo's ./setup
# runs it from the vendor copy when the upstream clone fails). Other code,
# build output, scripts and node_modules are never vendored.
#
# Run this whenever the live install moves ahead of the snapshot, before
# bumping VERSION. Syncing is an explicit maintainer step; setup never touches
# the source tree.
#
# Usage: scripts/sync-gstack.sh [--upstream <path>] [--vendor <path>]
#   --upstream  gstack git checkout (default: $GSTACK_HOME or ~/.claude/skills/gstack)
#   --vendor    snapshot directory  (default: <repo>/vendor/gstack)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

UPSTREAM="${GSTACK_HOME:-$HOME/.claude/skills/gstack}"
VENDOR="$REPO_ROOT/vendor/gstack"

while [ $# -gt 0 ]; do
    case "$1" in
        --upstream) UPSTREAM="$2"; shift 2 ;;
        --vendor)   VENDOR="$2";   shift 2 ;;
        *) echo "error: unknown argument: $1" >&2; exit 2 ;;
    esac
done

if ! git -C "$UPSTREAM" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: $UPSTREAM is not a git checkout of gstack." >&2
    echo "       git clone https://github.com/garrytan/gstack.git ~/.claude/skills/gstack" >&2
    exit 1
fi

# Tracked markdown that belongs to a skill directory (any top-level dir that
# has a SKILL.md), plus docs/*.md, VERSION and CLAUDE.md. Tracked-only, so
# local scratch files in the install never leak into the snapshot.
skill_dirs="$(git -C "$UPSTREAM" ls-tree -r --name-only HEAD | grep -E '^[^/]+/SKILL\.md$' | cut -d/ -f1 | sort -u)"

is_skill_dir() {
    printf '%s\n' "$skill_dirs" | grep -qx "$1"
}

select_files() {
    local f top
    git -C "$UPSTREAM" ls-tree -r --name-only HEAD | while IFS= read -r f; do
        case "$f" in
            VERSION|CLAUDE.md|SKILL.md|setup|docs/*.md) echo "$f" ;;
            *.md)
                top="${f%%/*}"
                if is_skill_dir "$top"; then echo "$f"; fi ;;
        esac
    done
}
files="$(select_files)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf '%s\n' "$files" | git -C "$UPSTREAM" archive HEAD --format=tar -- $(cat) | tar -x -C "$tmp"

rm -rf "$VENDOR"
mkdir -p "$(dirname "$VENDOR")"
mv "$tmp" "$VENDOR"
trap - EXIT

version="$(cat "$VENDOR/VERSION" 2>/dev/null || echo unknown)"
count="$(printf '%s\n' "$skill_dirs" | grep -c .)"
echo "vendor/gstack synced to gstack $version ($count skills, $(printf '%s\n' "$files" | grep -c .) files)"
