#!/bin/bash
set -e
mkdir -p ./fixture-repo
git -C "$HOME/Sites/otwarchive" archive HEAD | tar -x -C ./fixture-repo
cp -R "$HOME/claude-repomap-command" ./toolchain
