#!/bin/bash
# Scaffold for the repomap utility experiment (PREREG:
# evals/reports/2026-10-06-repomap-utility-PREREG.md). Identical across all
# three arms — including the vendored toolchain — so the ONLY between-arm
# differences are the prompt line (arm B) and the pre-injected map (arm C).
#
# The toolchain is vendored at ./fixture-repo/vendor because $HOME is
# unreadable inside sandboxed eval runs (evals/RUBRIC.md, Known limits), so
# the agent's only path to the tool is inside the workspace. "vendor" is in
# the repomap tool's own EXCLUDED_DIRS (repomap/mapper.py), so the vendored
# copy never pollutes a generated map — arm B's on-demand map has the same
# scope as arm C's pre-generated artifact. The arm-B prompt points
# REPOMAP_HOME=$PWD/fixture-repo/vendor at it.
. "$(dirname "$0")/../_lib/nav-fixture.sh"
nav_fixture ./fixture-repo
# Vendored repomap toolchain. The eval harness runs this scaffold with a
# sealed fake $HOME (2026-10-06 pilot finding: a $HOME-relative guard
# silently no-opped in-scaffold, so the pilot ran with no toolchain), so
# the lookup falls through to the maintainer's absolute path. Only arm B
# needs the toolchain; a missing one downgrades to a note, never a
# scaffold failure.
TC=""
for c in "$HOME/claude-repomap-command" "/Users/danilosapad/claude-repomap-command"; do
  [ -d "$c" ] && TC="$c" && break
done
if [ -n "$TC" ]; then
  cp -R "$TC" ./fixture-repo/vendor
else
  echo "note: no claude-repomap-command install found — arm B cannot run /repomap" >&2
fi
