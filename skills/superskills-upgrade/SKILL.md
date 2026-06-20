---
name: superskills-upgrade
version: 1.0.0
description: |
  Upgrade superskills to the latest version. Pulls from GitHub, re-runs setup,
  and shows the version change. Use when asked to "upgrade superskills",
  "update superskills", or "get the latest version of superskills".
triggers:
  - upgrade superskills
  - update superskills
  - get latest superskills
allowed-tools:
  - Bash
  - Read
---

# /superskills-upgrade

Upgrade superskills to the latest version.

## Steps

### Step 1: Find the install directory

```bash
if [ -d "$HOME/.claude/skills/superskills/.git" ]; then
  INSTALL_DIR="$HOME/.claude/skills/superskills"
elif [ -d "$HOME/.config/opencode/skills/superskills/.git" ]; then
  INSTALL_DIR="$HOME/.config/opencode/skills/superskills"
else
  echo "ERROR: superskills git install not found"
  echo "Expected: $HOME/.claude/skills/superskills"
  echo "Re-install: git clone https://github.com/ariadoss/superskills.git ~/.claude/skills/superskills && cd ~/.claude/skills/superskills && ./setup"
  exit 1
fi
echo "INSTALL_DIR=$INSTALL_DIR"
REMOTE_URL=$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || echo "unknown")
echo "REMOTE_URL=$REMOTE_URL"
```

### Step 2: Record current version

```bash
OLD_VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
echo "Current version: $OLD_VERSION"
```

### Step 3: Sync to latest and re-run setup

This is written to **always** land on `origin/main`, even if the local clone has
diverged because upstream history was rewritten/force-pushed, or the user made
local edits. A plain `git pull --ff-only` alone is not enough — it aborts on
divergence and on local modifications.

```bash
cd "$INSTALL_DIR"
git fetch origin
REMOTE_VERSION=$(git show origin/main:VERSION 2>/dev/null | tr -d '[:space:]' || echo "unknown")
echo "Remote version: $REMOTE_VERSION"

if [ "$OLD_VERSION" = "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "unknown" ]; then
  echo "ALREADY_LATEST=true"
else
  # 1) Preserve any uncommitted local edits so a hard reset can't lose them.
  STASHED=0
  if ! git diff --quiet || ! git diff --cached --quiet; then
    if git stash push -u -m "superskills-upgrade autostash" >/dev/null 2>&1; then
      STASHED=1
      echo "Stashed local changes before upgrade."
    fi
  fi

  # 2) Try the clean fast-forward first (preserves local commits if any).
  if git pull --ff-only origin main 2>/dev/null; then
    echo "SYNC=fast-forward"
  else
    # 3) Diverged (e.g. upstream was force-pushed) — force-match origin/main.
    echo "Fast-forward not possible; resetting to origin/main."
    git reset --hard origin/main
    echo "SYNC=reset"
  fi

  # 4) Re-apply stashed edits; if they conflict, leave them in the stash.
  if [ "$STASHED" = "1" ]; then
    if git stash pop >/dev/null 2>&1; then
      echo "Re-applied stashed local changes."
    else
      echo "STASH_CONFLICT=true  (your edits are safe in 'git stash list')"
    fi
  fi

  ./setup -q
  NEW_VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
  echo "NEW_VERSION=$NEW_VERSION"
fi
```

### Step 4: Report result

**If `ALREADY_LATEST=true`:** Tell the user:
```
superskills is already up to date (v{OLD_VERSION}).
```

**If upgrade ran:** Tell the user:
```
superskills upgraded: v{OLD_VERSION} → v{NEW_VERSION}
```
If `OLD_VERSION` equals `NEW_VERSION`, note that setup was re-run but the version didn't change (may have picked up skill updates within the same version).

**If `SYNC=reset` appeared:** the local clone had diverged from upstream (usually because published history was rewritten). It was force-matched to `origin/main`. If the user had local *commits*, those were discarded — only uncommitted edits are auto-preserved.

**If `STASH_CONFLICT=true` appeared:** the user's local edits couldn't be re-applied cleanly on top of the new version. Their changes are safe — tell them to recover with:
```bash
cd "$INSTALL_DIR" && git stash list   # find the 'superskills-upgrade autostash' entry
cd "$INSTALL_DIR" && git stash pop     # or: git stash show -p stash@{0} to inspect
```
(use the `INSTALL_DIR` value from Step 1)
