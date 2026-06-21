#!/usr/bin/env bash
# Run the superskills shell test suite (bats). This is the verification command
# referenced by ENGINEERING_STANDARDS.md and CLAUDE.md — run it before every
# commit that touches setup, scripts/, or the test fixtures.
set -e

cd "$(dirname "$0")/.."

if ! command -v bats >/dev/null 2>&1; then
  echo "bats is not installed. Install it with:  brew install bats-core" >&2
  echo "(see https://github.com/bats-core/bats-core)" >&2
  exit 127
fi

echo "Running shell tests (bats)..."
bats tests/*.bats
