#!/usr/bin/env bash
# Build the stand-in install a debrief v2 run reads, into <dir>.
# Usage: make_install.sh <dir>   (dir must not exist or must be empty)
# Layout:
#   <dir>/home/.claude/CLAUDE.md            user-level rules
#   <dir>/home/.claude/memory/MEMORY.md     user memory index
#   <dir>/home/.claude/skills/<name>/SKILL.md
#       real copies: tdd, verify, worktrees; synthetic: release-notes, locale-check
#   <dir>/project/                          the acme-invoices git repo (no remote)
# The answer key is never copied.
set -euo pipefail
dir="${1:-}"
if [ -z "$dir" ] || [ "$dir" = "/" ]; then
  echo "usage: make_install.sh <dir>  (dir must be non-empty and not /)" >&2
  exit 2
fi
if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
  echo "refusing: $dir is not empty" >&2
  exit 2
fi
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$dir/home/.claude/skills" "$dir/home/.claude/memory" "$dir/project/tests"

for s in tdd verify worktrees; do
  mkdir -p "$dir/home/.claude/skills/$s"
  cp "$root/skills/$s/SKILL.md" "$dir/home/.claude/skills/$s/SKILL.md"
done

mkdir -p "$dir/home/.claude/skills/release-notes" "$dir/home/.claude/skills/locale-check"
cat > "$dir/home/.claude/skills/release-notes/SKILL.md" <<'SK'
---
name: release-notes
description: Use when cutting release notes for a tag; lists merged pull requests since the last tag and groups them by type.
---

# Release notes

1. Find the last tag.
2. List every merged pull request since that tag.
3. Group them as features, fixes, and chores, one line each.
4. Show the draft to the user before saving it.
SK
cat > "$dir/home/.claude/skills/locale-check/SKILL.md" <<'SK'
---
name: locale-check
description: Use when a language file is added or changed; confirms it has the same keys as the English file.
---

# Locale check

Do these three steps by hand:

1. List the keys in the English file.
2. List the keys in the changed file.
3. Diff the two lists and report any key that is missing or extra.
SK

cat > "$dir/home/.claude/CLAUDE.md" <<'MD'
# User rules
- Ask before spending money or starting anything that keeps running.
- Keep replies plain and direct.
MD
cat > "$dir/home/.claude/memory/MEMORY.md" <<'MD'
- [Editor setup](editor-setup.md): which editor and theme the user runs
- [Package mirror](package-mirror.md): the user prefers the internal mirror for installs
MD

cat > "$dir/project/CLAUDE.md" <<'MD'
# acme-invoices
- Commit messages: imperative, under 72 characters.
- Branch names: kind/short-name, for example fix/rounding.
- Run the tests with pytest from the repo root.
MD
cat > "$dir/project/README.md" <<'MD'
# acme-invoices
Generates invoices. Tests are in tests/ and run with pytest.
MD
printf 'def test_placeholder():\n    assert True\n' > "$dir/project/tests/test_placeholder.py"

(
  cd "$dir/project"
  git init -q
  git config user.name "Eval Fixture"
  git config user.email "fixture@example.invalid"
  printf '.local-notes/\n' >> .git/info/exclude
  git add -A
  git commit -q -m "initial fixture"
)
