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

Two install shapes are supported:

- **Canonical install** — the repo is cloned at `~/.claude/skills/superskills`
  (or the OpenCode equivalent) and `./setup` ran from there.
- **Dev-repo install** — the repo lives somewhere else (e.g. `~/Sites/superskills`)
  and `./setup` symlinked the skills back into the tools. Common for maintainers
  and contributors. There is no clone under `~/.claude/skills/superskills`; we
  recover the real repo by resolving a skill symlink back to its source.

```bash
INSTALL_DIR=""
INSTALL_KIND=""

if [ -d "$HOME/.claude/skills/superskills/.git" ]; then
  INSTALL_DIR="$HOME/.claude/skills/superskills"; INSTALL_KIND="canonical"
elif [ -d "$HOME/.config/opencode/skills/superskills/.git" ]; then
  INSTALL_DIR="$HOME/.config/opencode/skills/superskills"; INSTALL_KIND="canonical"
else
  # Dev-repo install: follow a known skill symlink back to its source checkout.
  for probe in "$HOME/.claude/skills/superskills-upgrade/SKILL.md" \
               "$HOME/.config/opencode/skills/superskills-upgrade/SKILL.md"; do
    [ -L "$probe" ] || continue
    target=$(readlink "$probe")
    # Resolve relative symlink targets against the link's own directory.
    case "$target" in /*) : ;; *) target="$(dirname "$probe")/$target" ;; esac
    root=$(git -C "$(dirname "$target")" rev-parse --show-toplevel 2>/dev/null) || continue
    if [ -f "$root/setup" ] && [ -f "$root/VERSION" ]; then
      INSTALL_DIR="$root"; INSTALL_KIND="dev-repo"; break
    fi
  done
fi

if [ -z "$INSTALL_DIR" ]; then
  echo "ERROR: superskills git install not found"
  echo "Expected a clone at $HOME/.claude/skills/superskills, or skills symlinked from a source checkout."
  echo "Re-install: git clone https://github.com/ariadoss/superskills.git ~/.claude/skills/superskills && cd ~/.claude/skills/superskills && ./setup"
  exit 1
fi
echo "INSTALL_DIR=$INSTALL_DIR"
echo "INSTALL_KIND=$INSTALL_KIND"
REMOTE_URL=$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || echo "unknown")
echo "REMOTE_URL=$REMOTE_URL"
```

### Step 2: Record current version

```bash
OLD_VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
echo "Current version: $OLD_VERSION"
```

### Step 3: Sync to latest and re-run setup

Behavior depends on `INSTALL_KIND`:

- **`canonical`** — a managed clone the user doesn't develop in. Written to
  **always** land on `origin/main`, even if history was rewritten/force-pushed
  or the user edited skills in place. A plain `git pull --ff-only` is not enough
  (it aborts on divergence and on local modifications), so a hard-reset fallback
  guarantees the sync.
- **`dev-repo`** — the user's own working checkout. Treated **gently**: never
  hard-reset and never discard commits. Only uncommitted changes are stashed
  around a clean fast-forward; if the branch has diverged, stop and let the user
  resolve it by hand.

```bash
cd "$INSTALL_DIR"
git fetch origin
REMOTE_VERSION=$(git show origin/main:VERSION 2>/dev/null | tr -d '[:space:]' || echo "unknown")
echo "Remote version: $REMOTE_VERSION"

if [ "$OLD_VERSION" = "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "unknown" ]; then
  echo "ALREADY_LATEST=true"
  # Still re-link in case new skills were added within the same version.
  ./setup -q
else
  # Preserve uncommitted local edits so nothing is lost.
  STASHED=0
  if ! git diff --quiet || ! git diff --cached --quiet; then
    if git stash push -u -m "superskills-upgrade autostash" >/dev/null 2>&1; then
      STASHED=1
      echo "Stashed local changes before upgrade."
    fi
  fi

  # Try the clean fast-forward first (preserves local commits if any).
  if git pull --ff-only origin main 2>/dev/null; then
    echo "SYNC=fast-forward"
  elif [ "$INSTALL_KIND" = "dev-repo" ]; then
    # Maintainer's working repo — do NOT discard their commits.
    echo "SYNC=diverged-dev"
    echo "Your dev checkout has diverged from origin/main and can't fast-forward."
    echo "Resolve manually (e.g. 'git rebase origin/main' or 'git merge origin/main'), then re-run ./setup."
    [ "$STASHED" = "1" ] && git stash pop >/dev/null 2>&1 && echo "Restored stashed changes."
    exit 0
  else
    # Canonical install — force-match origin/main (handles force-pushed history).
    echo "Fast-forward not possible; resetting to origin/main."
    git reset --hard origin/main
    echo "SYNC=reset"
  fi

  # Re-apply stashed edits; if they conflict, leave them in the stash.
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

**If `SYNC=reset` appeared:** the local clone had diverged from upstream (usually because published history was rewritten). It was force-matched to `origin/main`. If the user had local *commits*, those were discarded — only uncommitted edits are auto-preserved. (Only happens for a `canonical` install.)

**If `SYNC=diverged-dev` appeared:** this is a `dev-repo` install (the user's own checkout) that has commits not on `origin/main`, so it can't fast-forward. Nothing was discarded. Tell the user to reconcile their branch themselves, then re-run setup:
```bash
cd "$INSTALL_DIR" && git rebase origin/main   # or: git merge origin/main
cd "$INSTALL_DIR" && ./setup -q
```
(use the `INSTALL_DIR` value from Step 1)

**If `STASH_CONFLICT=true` appeared:** the user's local edits couldn't be re-applied cleanly on top of the new version. Their changes are safe — tell them to recover with:
```bash
cd "$INSTALL_DIR" && git stash list   # find the 'superskills-upgrade autostash' entry
cd "$INSTALL_DIR" && git stash pop     # or: git stash show -p stash@{0} to inspect
```
(use the `INSTALL_DIR` value from Step 1)
