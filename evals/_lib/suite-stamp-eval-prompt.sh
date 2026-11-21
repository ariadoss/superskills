#!/bin/bash
# suite-stamp-eval-prompt.sh <id> <dir> <skills-root>: prints the agent prompt for one
# case of the suite-stamp skill eval. It names the skill file and the step, the
# user's request in plain words, and nothing about grading.
set -u
ID="${1:-}"; D="${2:-}"; R="${3:-}"
[ $# -eq 3 ] || { echo "usage: $0 <id> <dir> <skills-root>" >&2; exit 2; }
extra=""
case "$ID" in
  cc-P) skill=clean-code;   step="Step 4 (verify and report). Treat the branch diff as already audited with nothing left to fix"
        ask="clean up my branch diff before I ship" ;;
  tc-P) skill=test-coverage; step="Step 8 (run the related tests and report). Treat the missing tests as already written"
        ask="check test coverage on my branch and make sure it is tested" ;;
  qf-P) skill=qa-full; step="Step 2 (tests and build) in steps/02-tests-build.md, then Step 10 (final verdict) in steps/10-final-verdict-report.md. Assume every other step found nothing"
        ask="I finished the feature, run the full QA check on this branch" ;;
  dq-P|dq-N1|dq-N3|dq-N4) skill=daily-qa; step="Step 1 (establish the window), plus whatever Step 1 itself says to do next; do not run gh or any CI check"
        ask="run the daily QA for this repo" ;;
  dq-N2) skill=daily-qa; step="Step 1 (establish the window), plus whatever Step 1 itself says to do next; do not run gh or any CI check"
        ask="daily QA for the last 3 days" ;;
  fb-P|fb-N) skill=finish-branch; step="Step 1 (verify tests); stop before presenting merge options"
        ask="I'm done, finish this branch"
        extra=" Before running anything, export SUPERSKILLS_DIR=$R."
        ;;
  *) echo "unknown id: $ID" >&2; exit 2 ;;
esac
cat <<P
You are working in $D. Follow the skill at $R/skills/$skill/SKILL.md (read it) for the step named below, perform ONLY that step in this repo as the skill instructs, do not run CI, browsers or other steps, then stop and write your final message listing the commands you ran and the decision you took.$extra

Step: $step.

The user's request: "$ask".
P
