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

### Step 3: Pull latest and re-run setup

```bash
cd "$INSTALL_DIR"
git fetch origin
REMOTE_VERSION=$(git show origin/main:VERSION 2>/dev/null | tr -d '[:space:]' || echo "unknown")
echo "Remote version: $REMOTE_VERSION"

if [ "$OLD_VERSION" = "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "unknown" ]; then
  echo "ALREADY_LATEST=true"
else
  git pull --ff-only origin main
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

If `git pull` fails due to local modifications, tell the user to run:
```bash
cd "$INSTALL_DIR" && git stash && git pull origin main && ./setup -q
```
(use the `INSTALL_DIR` value from Step 1)
