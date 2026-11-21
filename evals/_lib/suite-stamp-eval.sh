#!/bin/bash
# suite-stamp-eval.sh: fixtures and graders for the suite-stamp skill eval,
# pre-registered in evals/reports/2026-11-21-suite-stamp-skills-PREREG.md.
#
#   suite-stamp-eval.sh fixture <id> <dir>                  build a fresh repo
#   suite-stamp-eval.sh grade <id> <dir> <final-message>    print key=value lines, then pass=1|0
#
# ids: cc-P tc-P dq-P dq-N1 dq-N2 dq-N3 dq-N4 fb-P fb-N qf-P
#
# Fixture: a small module (src/pricing.sh, src/format.sh) with tests; ./run-all-tests.sh
# appends FULL to .testlog; ./run-test.sh <name> appends "RELATED <name>". .testlog,
# .daily-qa-last-run and .eval-skills-root are git-ignored so the tree stays clean.
# fb-P records a real stamp by running scripts/suite-stamp.sh run once from the tree
# under test (SKILLS_ROOT, default: the tree this script lives in), then truncates .testlog.
#
# Grader ambiguity rulings (the PREREG leaves these open):
#  1. cc-P/tc-P: PASS = zero FULL lines and at least one RELATED line. Which test
#     ran is not checked; any related run counts.
#  2. qf-P: PASS = zero FULL, no whole-suite question (same patterns as
#     qa-full-closing-grade.sh), and the closing sentence recognised by its
#     meaning tokens ("no whole-suite gate" or "suite-stamp.sh init"), not its exact text.
#     A related run is reported but not required (the probe may skip the build).
#  3. dq skip path = the message says "no new commits since" AND shows no Step 3 work
#     (no `git show`, `git diff`, ranged or --since `git log`, and no untracked files or
#     new commits in the repo) AND the agent did not say it declined to skip
#     ("did not skip", "not skip", "ran normally", "run normally").
#     A plain `git log -1` or `rev-parse` used to read HEAD is not Step 3 work.
#  4. dq-P PASS = skip path taken, repo has no untracked files and HEAD unchanged.
#     The one-line report may be in the message or a file; the message marker is required.
#  5. dq-N* PASS = skip path NOT taken. dq-N4 additionally requires no crash tokens
#     (fatal, traceback, unbound variable, syntax error, command not found).
#  6. fb-P: PASS = zero FULL, stamp for HEAD tree still on file, and the message
#     mentions it (stamp / already passed / skipping / skipped).
#  7. fb-N: PASS = exactly one FULL and a stamp for HEAD tree now on file. "Via ensure"
#     is not provable from state; the stamp's existence is the evidence.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT_DEFAULT="$(cd "$HERE/../.." && pwd)"

die() { echo "suite-stamp-eval: $*" >&2; exit 2; }

valid_id() { case "$1" in cc-P|tc-P|dq-P|dq-N1|dq-N2|dq-N3|dq-N4|fb-P|fb-N|qf-P) return 0;; *) return 1;; esac; }

git_q() { git -C "$D" "$@"; }

build_base() {
  rm -rf "$D"; mkdir -p "$D/src" "$D/tests" "$D.origin.git"
  git init -q --bare "$D.origin.git"
  cd "$D" || die "cannot enter $D"
  git init -q -b main
  git config user.email eval@example.test; git config user.name "Eval Fixture"
  git remote add origin "$D.origin.git"
  printf '.testlog\n.daily-qa-last-run\n.eval-skills-root\n' > .gitignore
  cat > src/pricing.sh <<'S'
#!/bin/bash
# total <price> <qty>
total() { echo $(( $1 * $2 )); }
discount() { echo $(( $1 - $1 * $2 / 100 )); }
S
  cat > src/format.sh <<'S'
#!/bin/bash
money() { printf '$%d.%02d\n' $(( $1 / 100 )) $(( $1 % 100 )); }
S
  cat > tests/pricing_test.sh <<'S'
#!/bin/bash
. "$(dirname "$0")/../src/pricing.sh"
[ "$(total 3 4)" = 12 ] && [ "$(discount 200 10)" = 180 ]
S
  cat > run-all-tests.sh <<'S'
#!/bin/bash
cd "$(dirname "$0")" || exit 1
echo FULL >> .testlog
for t in tests/*_test.sh; do bash "$t" || exit 1; done
exit 0
S
  cat > run-test.sh <<'S'
#!/bin/bash
cd "$(dirname "$0")" || exit 1
echo "RELATED $1" >> .testlog
bash "tests/$1_test.sh"
S
  cat > README.md <<'S'
# pricing-fixture
Whole suite: `./run-all-tests.sh`. One test by name: `./run-test.sh <name>` (names: pricing).
S
  chmod +x run-all-tests.sh run-test.sh
  git add -A; git commit -qm "initial module and test"
  git push -q origin main 2>/dev/null
  printf '%s\n' "${SKILLS_ROOT:-$ROOT_DEFAULT}" > .eval-skills-root
}

add_feature_branch() {
  git checkout -q -b feature/bulk-pricing
  cat >> src/pricing.sh <<'S'
bulk_total() { echo $(( $1 * $2 - $1 * $2 * $3 / 100 )); }
bulk_discount() { echo $(( $1 - $1 * $2 / 100 )); }
S
  git add -A; git commit -qm "feat: bulk pricing helpers"
}

build_dq() {
  git checkout -q -b main 2>/dev/null
  for n in 1 2 3; do echo "# change $n" >> src/format.sh; git add -A; git commit -qm "chore: tweak $n"; done
  local head ts; head="$(git rev-parse HEAD)"; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  case "$ID" in
    dq-P|dq-N1|dq-N2) echo "$ts $head" > .daily-qa-last-run ;;
    dq-N3) echo "$ts $(git rev-parse HEAD~1)" > .daily-qa-last-run ;;
    dq-N4) echo "$ts" > .daily-qa-last-run ;;
  esac
  [ "$ID" = dq-N1 ] && echo '# uncommitted edit' >> src/pricing.sh
  return 0
}

fixture() {
  valid_id "$ID" || die "unknown id: $ID"
  mkdir -p "$(dirname "$D")"; D="$(cd "$(dirname "$D")" && pwd)/$(basename "$D")"
  build_base
  case "$ID" in
    cc-P|tc-P|qf-P) add_feature_branch ;;
    dq-*) build_dq ;;
    fb-P|fb-N)
      add_feature_branch
      git config --local superskills.suiteCommand ./run-all-tests.sh
      if [ "$ID" = fb-P ]; then
        "${SKILLS_ROOT:-$ROOT_DEFAULT}/scripts/suite-stamp.sh" run </dev/null >/dev/null 2>&1 \
          || die "could not record the stamp for fb-P"
      fi ;;
  esac
  : > "$D/.testlog"
  git_q rev-parse HEAD > "$D/.git/fixture-head"
}

# ---- grading ----
count_log() { local n; n="$(grep -c "$1" "$D/.testlog" 2>/dev/null)"; echo "${n:-0}"; }

stamped_head() {
  local tree c f
  tree="$(git_q rev-parse 'HEAD^{tree}')"
  f="$(git_q rev-parse --path-format=absolute --git-common-dir)/suite-stamps"
  [ -f "$f" ] && awk -F'\t' -v t="$tree" '$1 == t { found = 1 } END { exit !found }' "$f"
}

b() { if "$@"; then echo 1; else echo 0; fi; }   # command status to 1/0

msg_has() { grep -Eiq "$1" "$MSG"; }

skip_taken() {
  local marker=0 work=0 declined=0
  msg_has 'no new commits since' && marker=1
  msg_has 'git (show|diff)|git log[^[:cntrl:]]*(\.\.|--since|--after)' && work=1
  [ -n "$(git_q status --porcelain --untracked-files=all | grep '^??')" ] && work=1
  [ "$(git_q rev-parse HEAD)" != "$(cat "$D/.git/fixture-head" 2>/dev/null)" ] && work=1
  msg_has 'did not skip|not skip|ran normally|run normally' && declined=1
  [ $marker = 1 ] && [ $work = 0 ] && [ $declined = 0 ] && echo 1 || echo 0
}

grade() {
  valid_id "$ID" || die "unknown id: $ID"
  [ -d "$D/.git" ] || die "no fixture at $D"
  [ -f "$MSG" ] || die "no message file: $MSG"
  local full related pass=0
  full="$(count_log '^FULL')"; related="$(count_log '^RELATED ')"
  case "$ID" in
    cc-P|tc-P)
      echo "full=$full"; echo "related=$related"
      [ "$full" = 0 ] && [ "$related" -ge 1 ] && pass=1 ;;
    qf-P)
      local q=0 closing=0
      grep -Eiq 'suite.*\?|AskUserQuestion' "$MSG" && q=1
      grep -q '^QUESTION:' "$MSG" && q=1
      msg_has 'no whole-?suite gate|suite-stamp\.sh init' && closing=1
      echo "full=$full"; echo "related=$related"; echo "suite_question=$q"; echo "closing_sentence=$closing"
      [ "$full" = 0 ] && [ $q = 0 ] && [ $closing = 1 ] && pass=1 ;;
    dq-P)
      local s; s="$(skip_taken)"; echo "skip_taken=$s"
      [ "$s" = 1 ] && pass=1 ;;
    dq-N1|dq-N2|dq-N3)
      local s; s="$(skip_taken)"; echo "skip_taken=$s"
      [ "$s" = 0 ] && pass=1 ;;
    dq-N4)
      local s crash=0; s="$(skip_taken)"
      msg_has 'fatal|traceback|unbound variable|syntax error|command not found' && crash=1
      echo "skip_taken=$s"; echo "crash=$crash"
      [ "$s" = 0 ] && [ $crash = 0 ] && pass=1 ;;
    fb-P)
      local st rep=0; st="$(b stamped_head)"
      msg_has 'stamp|already passed|skipping|skipped' && rep=1
      echo "full=$full"; echo "stamp_on_file=$st"; echo "reports_stamp=$rep"
      [ "$full" = 0 ] && [ "$st" = 1 ] && [ $rep = 1 ] && pass=1 ;;
    fb-N)
      local st; st="$(b stamped_head)"
      echo "full=$full"; echo "stamp_on_file=$st"
      [ "$full" = 1 ] && [ "$st" = 1 ] && pass=1 ;;
  esac
  echo "pass=$pass"
}

cmd="${1:-}"
case "$cmd" in
  fixture) [ $# -eq 3 ] || die "usage: fixture <id> <dir>"; ID="$2"; D="$3"; fixture ;;
  grade)   [ $# -eq 4 ] || die "usage: grade <id> <dir> <final-message-file>"; ID="$2"; D="$3"; MSG="$4"; grade ;;
  *) die "usage: suite-stamp-eval.sh fixture|grade ..." ;;
esac
