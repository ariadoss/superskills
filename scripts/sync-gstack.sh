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
# Usage: scripts/sync-gstack.sh [--upstream <path>] [--vendor <path>] [--basic-review <path>]
#   --upstream  gstack git checkout (default: $GSTACK_HOME or ~/.claude/skills/gstack)
#   --vendor    snapshot directory  (default: <repo>/vendor/gstack)
#   --basic-review  where /basic-review's copy of review/checklist.md goes
#               (default: skills/basic-review/checklist.md, only when --vendor is
#               the default, so a test snapshot never overwrites the real copy)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

UPSTREAM="${GSTACK_HOME:-$HOME/.claude/skills/gstack}"
VENDOR="$REPO_ROOT/vendor/gstack"
DEFAULT_VENDOR="$VENDOR"
BASIC_REVIEW=""

while [ $# -gt 0 ]; do
    case "$1" in
        --upstream) UPSTREAM="$2"; shift 2 ;;
        --vendor)   VENDOR="$2";   shift 2 ;;
        --basic-review) BASIC_REVIEW="$2"; shift 2 ;;
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

# /basic-review ships its own copy of gstack's review checklist so it works
# where gstack is not installed. It is regenerated here, never edited by hand;
# tests/basic-review.bats fails if it drifts from the snapshot.
[ -z "$BASIC_REVIEW" ] && [ "$VENDOR" = "$DEFAULT_VENDOR" ] && BASIC_REVIEW="$REPO_ROOT/skills/basic-review/checklist.md"
if [ -n "$BASIC_REVIEW" ] && [ -f "$VENDOR/review/checklist.md" ]; then
    # An `a && b` list is exempt from `set -e`, so a failed write must be caught
    # explicitly or the run reports success over a stale checklist.
    # mktemp, like the installer: an exclusive new file, never a fixed name that a
    # leftover or planted path could occupy. A missing target dir fails right here.
    tmp="$(mktemp "$BASIC_REVIEW.XXXXXX" 2>/dev/null)" || {
        echo "sync-gstack: could not write $BASIC_REVIEW" >&2
        exit 1
    }
    if ! {
        echo "<!-- Vendored from garrytan/gstack review/checklist.md (MIT, Copyright (c) 2026 Garry Tan),"
        echo "     gstack $version. Refreshed by scripts/sync-gstack.sh; do not edit here."
        echo "-->"
        echo
        cat "$VENDOR/review/checklist.md"
    } 2>/dev/null > "$tmp" || ! chmod 644 "$tmp" || ! mv "$tmp" "$BASIC_REVIEW"; then
        rm -f "$tmp" 2>/dev/null
        echo "sync-gstack: could not write $BASIC_REVIEW" >&2
        exit 1
    fi
fi
count="$(printf '%s\n' "$skill_dirs" | grep -c .)"
echo "vendor/gstack synced to gstack $version ($count skills, $(printf '%s\n' "$files" | grep -c .) files)"
