#!/bin/bash
# Scaffold for the dbmap utility experiment (PREREG:
# evals/reports/2026-10-06-dbmap-utility-PREREG.md). Identical across all
# three arms — including the vendored toolchain — so the ONLY between-arm
# differences are the prompt line (arm B) and the pre-injected DBMAP.md
# (arm C).
#
# The toolchain is vendored inside the workspace because $HOME is
# unreadable inside sandboxed eval runs (Task-1 pilot finding: a
# $HOME-relative guard silently no-opped in-scaffold), so the lookup
# falls through to the maintainer's absolute path. Only arm B needs the
# toolchain; a missing one downgrades to a note, never a scaffold failure.
#
# The vendored copy PRUNES tests/ (PREREG deviation): the toolchain's own
# detector tests contain SQLAlchemy DSNs that dbmap --list would otherwise
# surface as a phantom second connection, breaking the prompt's
# single-connection steering. Verified on the scratch build; run.sh never
# executes tests/.
. "$(dirname "$0")/../_lib/db-fixture.sh"
db_fixture ./fixture-repo
TC=""
for c in "$HOME/claude-repomap-command" "/Users/danilosapad/claude-repomap-command"; do
  [ -d "$c" ] && TC="$c" && break
done
if [ -n "$TC" ]; then
  cp -R "$TC" ./fixture-repo/vendor
  rm -rf ./fixture-repo/vendor/tests
else
  echo "note: no claude-repomap-command install found — arm B cannot run /dbmap" >&2
fi
