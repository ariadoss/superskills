#!/usr/bin/env bats
# Fixtures and graders for the suite-stamp skill eval: each id gets a hand-built
# passing and failing end state, and the grader must tell them apart.
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  EV="$REPO_ROOT/evals/_lib/suite-stamp-eval.sh"
  D="$BATS_TEST_TMPDIR/proj"
  MSG="$BATS_TEST_TMPDIR/msg.txt"
  : > "$MSG"
}

build() { bash "$EV" fixture "$1" "$D" </dev/null; }
grade() { bash "$EV" grade "$1" "$D" "$MSG" </dev/null; }
passes() { [[ "$output" == *"pass=1"* ]] || false; }
fails() { [[ "$output" == *"pass=0"* ]] || false; }

CLOSING='No whole-suite gate is set up here. Run the whole suite once before merging, or run suite-stamp.sh init.'

@test "cc-P and tc-P pass on related-only runs and fail once FULL appears" {
  for id in cc-P tc-P; do
    build "$id"
    run grade "$id"; fails
    echo "RELATED pricing" > "$D/.testlog"
    run grade "$id"; passes
    echo "FULL" >> "$D/.testlog"
    run grade "$id"; fails
    echo "FULL" > "$D/.testlog"
    run grade "$id"; fails
  done
}

@test "cc-P fixture is a feature branch with no suiteCommand, clean tree" {
  build cc-P
  [ "$(git -C "$D" branch --show-current)" = feature/bulk-pricing ]
  [ -z "$(git -C "$D" config --local --get superskills.suiteCommand)" ]
  [ -z "$(git -C "$D" status --porcelain)" ]
  [ -s "$D/.eval-skills-root" ]
  run bash -c "cd '$D' && ./run-all-tests.sh && ./run-test.sh pricing"
  [ "$status" -eq 0 ]
  [ "$(cat "$D/.testlog")" = "$(printf 'FULL\nRELATED pricing')" ]
}

@test "qf-P passes on no FULL plus the closing sentence, fails otherwise" {
  build qf-P
  [ -z "$(git -C "$D" config --local --get superskills.suiteCommand)" ]
  echo "RELATED pricing" > "$D/.testlog"
  echo "SHIP-READY. $CLOSING" > "$MSG"
  run grade qf-P; passes
  echo "SHIP-READY." > "$MSG"
  run grade qf-P; fails
  echo "SHIP-READY. $CLOSING Want me to run the whole suite now?" > "$MSG"
  run grade qf-P; fails
  echo "SHIP-READY. $CLOSING" > "$MSG"
  echo FULL >> "$D/.testlog"
  run grade qf-P; fails
}

@test "dq-P passes only on the skip report" {
  build dq-P
  [ "$(cut -d' ' -f2 "$D/.daily-qa-last-run")" = "$(git -C "$D" rev-parse HEAD)" ]
  echo "I ran the check. Findings: none." > "$MSG"
  run grade dq-P; fails
  echo "no new commits since abc1234; CI signals not re-checked" > "$MSG"
  run grade dq-P; passes
  echo "no new commits since abc1234. I ran git diff HEAD~3 anyway." > "$MSG"
  run grade dq-P; fails
  echo "no new commits since abc1234" > "$MSG"
  echo x > "$D/report.md"
  run grade dq-P; fails
}

@test "dq-N1 to N4 pass when the skip was not taken" {
  for id in dq-N1 dq-N2 dq-N3 dq-N4; do
    build "$id"
    echo "no new commits since abc1234; CI signals not re-checked" > "$MSG"
    run grade "$id"; fails
    printf 'Window: 24h. Ran git log --since=24h and reviewed the commits.\n' > "$MSG"
    run grade "$id"; passes
  done
}

@test "dq fixtures: N1 is dirty, N3 has a different sha, N4 has no sha" {
  build dq-N1; [ -n "$(git -C "$D" status --porcelain)" ]
  build dq-N3; [ "$(cut -d' ' -f2 "$D/.daily-qa-last-run")" != "$(git -C "$D" rev-parse HEAD)" ]
  build dq-N4; [ "$(wc -w < "$D/.daily-qa-last-run")" -eq 1 ]
}

@test "dq-N4 fails on a crash even when it did not skip" {
  build dq-N4
  echo "Ran git log --since=24h. fatal: bad revision" > "$MSG"
  run grade dq-N4; fails
}

@test "dq-N1 declining the skip in words passes even when the marker is quoted" {
  build dq-N1
  echo "The stored sha matches but the tree is dirty, so I did not skip: no new commits since abc is not safe." > "$MSG"
  run grade dq-N1; passes
}

@test "fb-P has a real stamp; passes without FULL and a report, fails when the suite reran" {
  build fb-P
  [ "$(git -C "$D" config --local superskills.suiteCommand)" = ./run-all-tests.sh ]
  [ ! -s "$D/.testlog" ]
  echo "The suite already passed on this tree, so I skipped it (stamp found)." > "$MSG"
  run grade fb-P; passes
  echo "ran things" > "$MSG"
  run grade fb-P; fails
  echo "The suite already passed on this tree (stamp)." > "$MSG"
  echo FULL > "$D/.testlog"
  run grade fb-P; fails
}

@test "fb-N passes on exactly one FULL with a stamp, fails on none or two" {
  build fb-N
  run grade fb-N; fails
  echo FULL > "$D/.testlog"
  run grade fb-N; fails
  ( cd "$D" && "$REPO_ROOT/scripts/suite-stamp.sh" run </dev/null >/dev/null )
  echo FULL > "$D/.testlog"
  run grade fb-N; passes
  echo FULL >> "$D/.testlog"
  run grade fb-N; fails
}

@test "the prompt names the working dir, the skill file and the user request" {
  for id in cc-P tc-P qf-P dq-P dq-N1 dq-N2 dq-N3 dq-N4 fb-P fb-N; do
    run bash "$REPO_ROOT/evals/_lib/suite-stamp-eval-prompt.sh" "$id" "$D" /skills/root </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"You are working in $D."* ]] || false
    [[ "$output" == *"/skills/root/skills/"*"/SKILL.md"* ]] || false
    [[ "$output" == *"The user's request:"* ]] || false
  done
  run bash "$REPO_ROOT/evals/_lib/suite-stamp-eval-prompt.sh" dq-N2 "$D" /r </dev/null
  [[ "$output" == *"last 3 days"* ]] || false
  run bash "$REPO_ROOT/evals/_lib/suite-stamp-eval-prompt.sh" fb-P "$D" /r </dev/null
  [[ "$output" == *"SUPERSKILLS_DIR=/r"* ]] || false
}

@test "an unknown id is rejected" {
  run bash "$EV" fixture nope "$D" </dev/null
  [ "$status" -eq 2 ]
}
