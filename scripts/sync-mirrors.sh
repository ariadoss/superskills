#!/usr/bin/env bash
# Sync the in-tree mirrors of upstream slash commands into skills/<name>/SKILL.md.
#
# The dbmap/repomap skills live in their own upstream repo
# (github.com/ariadoss/repomap, cloned to ~/claude-repomap-command by default).
# This repo keeps an in-tree copy of each slash command file as
# skills/<name>/SKILL.md so the skills work even if the upstream is removed.
#
# Run this whenever the upstream changes, before bumping VERSION. CI / setup
# does not auto-modify the source tree, so syncing is an explicit maintainer
# step.
#
# Resolves the upstream location from (in order):
#   1. $REPOMAP_HOME
#   2. $HOME/claude-repomap-command
#   3. $HOME/.claude-repomap-command
#   4. $HOME/.local/share/claude-repomap-command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

find_upstream() {
    local candidates=(
        "${REPOMAP_HOME:-}"
        "$HOME/claude-repomap-command"
        "$HOME/.claude-repomap-command"
        "$HOME/.local/share/claude-repomap-command"
    )
    for path in "${candidates[@]}"; do
        if [ -n "$path" ] && [ -f "$path/dbmap.md" ]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

UPSTREAM="$(find_upstream)" || {
    echo "error: could not find the repomap upstream clone." >&2
    echo "       set \$REPOMAP_HOME, or clone it to one of:" >&2
    echo "         ~/claude-repomap-command" >&2
    echo "         ~/.claude-repomap-command" >&2
    echo "         ~/.local/share/claude-repomap-command" >&2
    echo "" >&2
    echo "       git clone https://github.com/ariadoss/repomap.git ~/claude-repomap-command" >&2
    exit 1
}

echo "upstream: $UPSTREAM"

# Optionally pull latest before mirroring. Skip if --no-pull is passed or the
# upstream isn't a git checkout (e.g. snapshot install).
if [ "${1:-}" != "--no-pull" ] && [ -d "$UPSTREAM/.git" ]; then
    echo "pulling latest upstream..."
    git -C "$UPSTREAM" pull --ff-only --quiet || {
        echo "warn: git pull failed; mirroring whatever is on disk." >&2
    }
fi

MIRRORS=(
    dbmap
    repomap
    dbmap-auto-on
    dbmap-auto-off
    repomap-auto-on
    repomap-auto-off
)

changed=0
for name in "${MIRRORS[@]}"; do
    src="$UPSTREAM/$name.md"
    dst="$REPO_ROOT/skills/$name/SKILL.md"

    if [ ! -f "$src" ]; then
        echo "skip:  $name (no upstream file at $src)"
        continue
    fi
    if [ ! -d "$REPO_ROOT/skills/$name" ]; then
        echo "skip:  $name (no skills/$name dir — add it before syncing)"
        continue
    fi

    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        echo "ok:    $name"
    else
        cp "$src" "$dst"
        echo "sync:  $name"
        changed=$((changed + 1))
    fi
done

echo ""
if [ "$changed" -gt 0 ]; then
    echo "$changed mirror(s) updated. Review with 'git diff', then bump VERSION."
else
    echo "all mirrors in sync."
fi
