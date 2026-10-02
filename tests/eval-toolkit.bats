#!/usr/bin/env bats
# Tests for skills/eval/toolkit - calibrate.py, the arithmetic half of the /eval
# skill. The expected numbers come from the method's worked example (80
# human-labeled runs: 50 FAIL, 30 PASS; the judge fails 44 of the 50 and passes
# 21 of the 30), so a regression in the confusion matrix, the rounding, or the
# harsh/lenient reading is caught against a known-good case rather than against
# the implementation's own echo.
#
# Layout-agnostic on purpose: this same file ships unmodified in the standalone
# eval repo (scripts/export-eval.sh), where the skill sits at the root. An
# export that rewrote paths would be a transformation that can drift; locating
# them instead cannot.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  if [ -d "$REPO_ROOT/skills/eval/toolkit" ]; then
    TK="$REPO_ROOT/skills/eval/toolkit"
    SKILL_MD="$REPO_ROOT/skills/eval/SKILL.md"
  else
    TK="$REPO_ROOT/toolkit"
    SKILL_MD="$REPO_ROOT/SKILL.md"
  fi
  LABELS="$BATS_TEST_TMPDIR/labels.jsonl"
}

# worked_example <file> - the method's worked example as JSONL: 80 runs, human
# 50 FAIL / 30 PASS; the judge fails 44 of the 50 and passes 21 of the 30.
worked_example() {
  : > "$1"
  local i
  for i in $(seq 44); do printf '{"human": "FAIL", "judge": "FAIL"}\n' >> "$1"; done
  for i in $(seq 6);  do printf '{"human": "FAIL", "judge": "PASS"}\n' >> "$1"; done
  for i in $(seq 9);  do printf '{"human": "PASS", "judge": "FAIL"}\n' >> "$1"; done
  for i in $(seq 21); do printf '{"human": "PASS", "judge": "PASS"}\n' >> "$1"; done
}

# lenient_example <file> - same human labels, a judge that waves bad work
# through: only 40 of the 50 FAILs caught, 29 of the 30 PASSes kept.
lenient_example() {
  : > "$1"
  local i
  for i in $(seq 40); do printf '{"human": "FAIL", "judge": "FAIL"}\n' >> "$1"; done
  for i in $(seq 10); do printf '{"human": "FAIL", "judge": "PASS"}\n' >> "$1"; done
  for i in $(seq 1);  do printf '{"human": "PASS", "judge": "FAIL"}\n' >> "$1"; done
  for i in $(seq 29); do printf '{"human": "PASS", "judge": "PASS"}\n' >> "$1"; done
}

@test "the closure is complete: the toolkit file the skill names is present" {
  [ -f "$TK/calibrate.py" ] || { echo "missing calibrate.py"; return 1; }
}

@test "the worked example: counts and all four metrics at 4 decimals" {
  worked_example "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"TP=44 TN=21 FP=9 FN=6"* ]] || false
  printf '%s\n' "$output" | grep -qE '^TPR \(recall\) +0\.8800$' || false
  printf '%s\n' "$output" | grep -qE '^TNR \(specificity\) +0\.7000$' || false
  printf '%s\n' "$output" | grep -qE '^accuracy +0\.8125$' || false
  printf '%s\n' "$output" | grep -qE '^precision +0\.8302$' || false
  [[ "$output" == *"n=80 positive=FAIL"* ]] || false
}

@test "the worked example reads harsh, with both error shares named" {
  worked_example "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"bias: harsh"* ]] || false
  [[ "$output" == *"judge FAIL where human PASS: 9/30 (0.3000)"* ]] || false
  [[ "$output" == *"judge PASS where human FAIL: 6/50 (0.1200)"* ]] || false
}

@test "declaring PASS the positive class swaps TPR/TNR and precision; the direction does not flip" {
  worked_example "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS" --positive PASS
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"TP=21 TN=44 FP=6 FN=9"* ]] || false
  printf '%s\n' "$output" | grep -qE '^TPR \(recall\) +0\.7000$' || false
  printf '%s\n' "$output" | grep -qE '^TNR \(specificity\) +0\.8800$' || false
  printf '%s\n' "$output" | grep -qE '^accuracy +0\.8125$' || false
  printf '%s\n' "$output" | grep -qE '^precision +0\.7778$' || false
  # The judge did not change, so the reading must not either. With PASS
  # positive, 1-TPR is the wrongly-failed share and 1-TNR the waved-through
  # one; a tool that kept the FAIL-positive formula would call this lenient.
  [[ "$output" == *"bias: harsh"* ]] || false
  [[ "$output" == *"judge FAIL where human PASS: 9/30 (0.3000)"* ]] || false
  [[ "$output" == *"judge PASS where human FAIL: 6/50 (0.1200)"* ]] || false
}

@test "a judge that waves bad work through is named lenient under both conventions" {
  lenient_example "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"bias: lenient"* ]] || false
  [[ "$output" == *"judge PASS where human FAIL: 10/50 (0.2000)"* ]] || false
  [[ "$output" == *"judge FAIL where human PASS: 1/30 (0.0333)"* ]] || false
  run python3 "$TK/calibrate.py" "$LABELS" --positive PASS
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"bias: lenient"* ]] || false
}

@test "a custom positive class keeps the same cells and names the real labels" {
  # The worked example with FAIL renamed FLAG and PASS renamed OK: same matrix,
  # same shares, actual label strings in the reading.
  {
    for i in $(seq 9);  do printf '{"human": "OK", "judge": "FLAG"}\n'; done
    for i in $(seq 21); do printf '{"human": "OK", "judge": "OK"}\n'; done
    for i in $(seq 6);  do printf '{"human": "FLAG", "judge": "OK"}\n'; done
    for i in $(seq 44); do printf '{"human": "FLAG", "judge": "FLAG"}\n'; done
  } > "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS" --positive FLAG
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"TP=44 TN=21 FP=9 FN=6"* ]] || false
  [[ "$output" == *"judge FLAG where human OK: 9/30 (0.3000)"* ]] || false
  [[ "$output" == *"judge OK where human FLAG: 6/50 (0.1200)"* ]] || false
  [[ "$output" == *"bias: harsh"* ]] || false
}

@test "equal error rates read as no directional bias" {
  {
    for i in $(seq 5);  do printf '{"human": "PASS", "judge": "FAIL"}\n'; done
    for i in $(seq 5);  do printf '{"human": "PASS", "judge": "PASS"}\n'; done
    for i in $(seq 10); do printf '{"human": "FAIL", "judge": "FAIL"}\n'; done
    for i in $(seq 10); do printf '{"human": "FAIL", "judge": "PASS"}\n'; done
  } > "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"bias: none"* ]] || false
  [[ "$output" == *"5/10 (0.5000)"* ]] || false
  [[ "$output" == *"10/20 (0.5000)"* ]] || false
}

@test "empty input prints n/a metrics and exits 0" {
  : > "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS"
  [ "$status" -eq 0 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" == *"n=0"* ]] || false
  printf '%s\n' "$output" | grep -qE '^TPR \(recall\) +n/a$' || false
  printf '%s\n' "$output" | grep -qE '^accuracy +n/a$' || false
  [[ "$output" == *"bias: n/a"* ]] || false
}

@test "stdin is an input source, like a file argument" {
  worked_example "$LABELS"
  run bash -c "cat '$LABELS' | python3 '$TK/calibrate.py'"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"n=80"* ]] || false
  [[ "$output" == *"TP=44 TN=21 FP=9 FN=6"* ]] || false
}

@test "a zero denominator prints n/a for that metric only; no crash" {
  # Every run is human PASS and judge PASS: with FAIL positive there are no
  # positive-class runs at all, so TPR and precision have zero denominators
  # while TNR and accuracy are still real numbers.
  for i in $(seq 3); do printf '{"human": "PASS", "judge": "PASS"}\n'; done > "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qE '^TPR \(recall\) +n/a$' || false
  printf '%s\n' "$output" | grep -qE '^precision +n/a$' || false
  printf '%s\n' "$output" | grep -qE '^TNR \(specificity\) +1\.0000$' || false
  printf '%s\n' "$output" | grep -qE '^accuracy +1\.0000$' || false
  [[ "$output" == *"bias: n/a"* ]] || false
}

@test "a malformed JSONL line fails with the line number, exit 2, no traceback" {
  printf '{"human": "FAIL", "judge": "FAIL"}\n{"human": "FAIL", "judge": "PASS"}\noops not json\n' > "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS"
  [ "$status" -eq 2 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" == *"line 3"* ]] || false
  [[ "$output" != *"Traceback"* ]] || false
}

@test "a JSON line missing a key names the key and the line number" {
  printf '{"human": "FAIL"}\n' > "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS"
  [ "$status" -eq 2 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" == *"line 1"* ]] || false
  [[ "$output" == *"judge"* ]] || false
}

@test "two-column CSV (human first) parses, with an optional header line" {
  printf 'human,judge\nFAIL,FAIL\nFAIL,PASS\nPASS,PASS\n' > "$BATS_TEST_TMPDIR/labels.csv"
  run python3 "$TK/calibrate.py" "$BATS_TEST_TMPDIR/labels.csv"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"n=3"* ]] || false
  [[ "$output" == *"TP=1 TN=1 FP=0 FN=1"* ]] || false
}

@test "a CSV line with the wrong column count is malformed, named by line" {
  printf 'FAIL,FAIL,PASS\n' > "$BATS_TEST_TMPDIR/bad.csv"
  run python3 "$TK/calibrate.py" "$BATS_TEST_TMPDIR/bad.csv"
  [ "$status" -eq 2 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" == *"line 1"* ]] || false
}

@test "the header names the labels seen, so a typo'd positive class is visible" {
  worked_example "$LABELS"
  run python3 "$TK/calibrate.py" "$LABELS" --positive FAIl
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"positive=FAIl"* ]] || false
  [[ "$output" == *"FAIL, PASS"* ]] || false
}

@test "--help exits 0 and documents the positive-class contract" {
  run python3 "$TK/calibrate.py" --help
  [ "$status" -eq 0 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" == *"usage:"* ]] || false
  [[ "$output" == *"--positive"* ]] || false
}

@test "importable: confusion() and metrics() agree with the CLI numbers" {
  # -B: importing the module must not leave a __pycache__ beside it, which
  # would then ship nondeterministic bytecode into an export's verification
  # run and break the export's byte-identity guarantees.
  run python3 -B -c "
import sys
sys.path.insert(0, '$TK')
from calibrate import confusion, metrics
human = ['FAIL'] * 50 + ['PASS'] * 30
judge = ['FAIL'] * 44 + ['PASS'] * 6 + ['FAIL'] * 9 + ['PASS'] * 21
m = metrics(confusion(human, judge))
print(m['counts']['TP'], m['counts']['TN'], m['counts']['FP'], m['counts']['FN'])
print(m['TPR (recall)'], m['TNR (specificity)'], m['accuracy'], m['precision'])
m2 = metrics(confusion(human, judge, positive='PASS'))
print(m2['TPR (recall)'], m2['TNR (specificity)'], m2['precision'])
"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "${lines[0]}" = "44 21 9 6" ] || { echo "${lines[0]}"; return 1; }
  [ "${lines[1]}" = "0.88 0.7 0.8125 0.8302" ] || { echo "${lines[1]}"; return 1; }
  [ "${lines[2]}" = "0.7 0.88 0.7778" ] || { echo "${lines[2]}"; return 1; }
}

@test "standard library only: no third-party imports" {
  run bash -c "grep -hE '^[[:space:]]*(import|from) ' '$TK/calibrate.py' \
    | sed -E 's/^[[:space:]]+//' \
    | grep -vE '^(import|from) (argparse|json|sys|collections|dataclasses)([. ]|\$)' \
    | grep -c ."
  [ "$output" = "0" ] || { echo "non-stdlib imports found"; return 1; }
}

@test "a missing input file fails with one clean line naming the file" {
  run python3 "$TK/calibrate.py" "$BATS_TEST_TMPDIR/does-not-exist.jsonl"
  [ "$status" -eq 2 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" != *"Traceback"* ]] || false
  [[ "$output" == *"does-not-exist.jsonl"* ]] || false
}

@test "a non-UTF-8 input file fails with one clean line, not a traceback" {
  printf 'Caf\xe9\n' > "$BATS_TEST_TMPDIR/latin1.jsonl"
  run python3 "$TK/calibrate.py" "$BATS_TEST_TMPDIR/latin1.jsonl"
  [ "$status" -eq 2 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" != *"Traceback"* ]] || false
  [[ "$output" == *"not valid UTF-8"* ]] || false
}

# skill_snippet - the TOOLKIT-resolution bash block exactly as SKILL.md ships it.
skill_snippet() {
  awk '/`TOOLKIT` below means/{f=1} f&&/^```bash$/{g=1;next} g&&/^```$/{exit} g' "$SKILL_MD"
}

@test "SKILL.md's toolkit resolution works from an unrelated working directory" {
  # It must not use $0, which in an agent's shell is the shell.
  base="$(dirname "$TK")"
  snippet="$(skill_snippet)"
  [ -n "$snippet" ] || { echo "could not extract the snippet"; return 1; }
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  run bash -c "cd '$BATS_TEST_TMPDIR/elsewhere' && HOME='$BATS_TEST_TMPDIR' && $(printf '%s' "$snippet" | sed "s#<base directory for this skill>#$base#") && echo \"TK=\$TOOLKIT\""
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"TK=$TK"* ]] || { echo "resolved wrongly: $output"; return 1; }
}

@test "SKILL.md's toolkit resolution fails loudly on a wrong base directory" {
  snippet="$(skill_snippet)"
  [ -n "$snippet" ] || { echo "could not extract the snippet"; return 1; }
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  run bash -c "cd '$BATS_TEST_TMPDIR/empty' && HOME='$BATS_TEST_TMPDIR/empty' && $(printf '%s' "$snippet" | sed "s#<base directory for this skill>#/nonexistent#")"
  [ "$status" -ne 0 ] || { echo "resolved a nonexistent toolkit: $output"; return 1; }
  [[ "$output" == *"toolkit not found"* ]] || false
}

@test "SKILL.md never resolves the toolkit against the shell's cwd" {
  # A ./toolkit fallback would run whatever toolkit/ the agent's cwd holds.
  run grep -cE '"\./toolkit"' "$SKILL_MD"
  [ "$output" = "0" ] || { echo "SKILL.md still falls back to ./toolkit"; return 1; }
}
