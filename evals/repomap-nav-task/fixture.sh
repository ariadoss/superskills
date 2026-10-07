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
# Vendored repomap toolchain (guarded so the case still builds for
# maintainers without ~/claude-repomap-command; only arm B needs it).
if [ -d "$HOME/claude-repomap-command" ]; then
  cp -R "$HOME/claude-repomap-command" ./fixture-repo/vendor
else
  echo "note: ~/claude-repomap-command not found — arm B cannot run /repomap" >&2
fi
