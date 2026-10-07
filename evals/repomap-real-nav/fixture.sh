#!/bin/bash
set -e
mkdir -p ./fixture-repo
git -C "$HOME/Sites/payroll-next" archive HEAD | tar -x -C ./fixture-repo
cp -R "$HOME/claude-repomap-command" ./toolchain
