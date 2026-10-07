#!/bin/bash
set -e
mkdir -p ./fixture-repo
git -C "$HOME/Sites/ats" archive HEAD | tar -x -C ./fixture-repo
cp "$HOME/Sites/ats/backups/local_backup_20250818_142316.db" ./fixture-repo/app.db
printf 'DATABASE_URL=sqlite:///%s/fixture-repo/app.db\n' "$PWD" > ./fixture-repo/.env
cp -R "$HOME/claude-repomap-command" ./toolchain
