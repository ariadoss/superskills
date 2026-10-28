#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  RUNNER="$REPO_ROOT/evals/_lib/humanize-constructions.py"
  TK="$REPO_ROOT/skills/humanize/toolkit"
}

@test "humanize eval computes every confusion cell and writes calibration pairs" {
  python3 - "$RUNNER" "$TK" "$BATS_TEST_TMPDIR" <<'PY'
import json
from pathlib import Path
import subprocess
import sys

runner, toolkit, temp = sys.argv[1:]
root = Path(temp)
cases = root / 'cases.json'
cases.write_text(json.dumps([
    {'id': 'tp', 'group': 'fixture', 'flag': True, 'text': 'Imagine this: the report is ready.'},
    {'id': 'tn', 'group': 'fixture', 'flag': False, 'text': 'The report is ready.'},
    {'id': 'fp', 'group': 'fixture', 'flag': False, 'text': 'Imagine this: the report is ready.'},
    {'id': 'fn', 'group': 'fixture', 'flag': True, 'text': 'The report is ready.'},
]))
output = root / 'nested' / 'result.json'
subprocess.run([sys.executable, runner, '--toolkit', toolkit, '--cases', str(cases), '--output', str(output)], check=True, capture_output=True)
report = json.loads(output.read_text())
assert report['counts'] == {'TP': 1, 'TN': 1, 'FP': 1, 'FN': 1}, report
assert report['metrics'] == {'recall': .5, 'specificity': .5, 'accuracy': .5, 'precision': .5}, report
assert [json.loads(line) for line in output.with_suffix('.labels.jsonl').read_text().splitlines()] == [
    {'human': 'FAIL', 'judge': 'FAIL'}, {'human': 'PASS', 'judge': 'PASS'},
    {'human': 'PASS', 'judge': 'FAIL'}, {'human': 'FAIL', 'judge': 'PASS'},
]
assert all(len(row['legacy_sha256']) == 64 for row in report['cases'])
PY
}

@test "humanize eval supports a selected report group and undefined empty-set metrics" {
  python3 - "$RUNNER" "$TK" "$BATS_TEST_TMPDIR" <<'PY'
import json
from pathlib import Path
import subprocess
import sys

runner, toolkit, temp = sys.argv[1:]
root = Path(temp)
cases, output = root / 'cases.json', root / 'result.json'
cases.write_text(json.dumps([{'id': 'editorial', 'group': 'fixture', 'flag': True, 'text': 'Great question! The gate opens.'}]))
command = [sys.executable, runner, '--toolkit', toolkit, '--cases', str(cases), '--output', str(output), '--section', 'EDITORIAL PATTERNS']
subprocess.run(command, check=True, capture_output=True)
assert json.loads(output.read_text())['counts'] == {'TP': 1, 'TN': 0, 'FP': 0, 'FN': 0}
cases.write_text('[]')
subprocess.run(command, check=True, capture_output=True)
assert set(json.loads(output.read_text())['metrics'].values()) == {None}
assert output.with_suffix('.labels.jsonl').read_text() == ''
PY
}

@test "humanize eval rejects an incomplete construction scan before publishing results" {
  cp -R "$TK" "$BATS_TEST_TMPDIR/toolkit"
  rm "$BATS_TEST_TMPDIR/toolkit/construction_scanner.py"
  printf '%s\n' '[{"id":"sample","group":"fixture","flag":true,"text":"Imagine this: the gate opens."}]' > "$BATS_TEST_TMPDIR/cases.json"
  run python3 "$RUNNER" --toolkit "$BATS_TEST_TMPDIR/toolkit" --cases "$BATS_TEST_TMPDIR/cases.json" --output "$BATS_TEST_TMPDIR/result.json"
  [ "$status" -ne 0 ] || false
  [[ "$output" == *"scanner failed"* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/result.json" ] || false
  [ ! -e "$BATS_TEST_TMPDIR/result.labels.jsonl" ] || false
}

@test "humanize eval rejects a failed scanner process" {
  printf '%s\n' '[{"id":"sample","group":"fixture","flag":true,"text":"Imagine this: the gate opens."}]' > "$BATS_TEST_TMPDIR/cases.json"
  run python3 "$RUNNER" --toolkit "$BATS_TEST_TMPDIR/missing-toolkit" --cases "$BATS_TEST_TMPDIR/cases.json" --output "$BATS_TEST_TMPDIR/result.json"
  [ "$status" -ne 0 ] || false
  [[ "$output" == *"scanner failed"* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/result.json" ] || false
}

@test "humanize eval does not confuse quoted diagnostic phrases with scanner failures" {
  printf '%s\n' '[{"id":"sample","group":"fixture","flag":true,"text":"Imagine this: the page says construction_scanner unavailable or scorer unavailable."}]' > "$BATS_TEST_TMPDIR/cases.json"
  run python3 "$RUNNER" --toolkit "$TK" --cases "$BATS_TEST_TMPDIR/cases.json" --output "$BATS_TEST_TMPDIR/result.json"
  [ "$status" -eq 0 ] || false
  [ -s "$BATS_TEST_TMPDIR/result.json" ] || false
}

@test "humanize rhetoric fixtures create all six editing and preservation passages" {
  for mode in marketing docs clean fiction-edit fiction-quotes fiction-voice; do
    mkdir "$BATS_TEST_TMPDIR/$mode"
    cd "$BATS_TEST_TMPDIR/$mode" || return 1
    run bash "$REPO_ROOT/evals/humanize-rhetoric-$mode/fixture.sh"
    [ "$status" -eq 0 ] || false
    [ -s draft.md ] || false
    case "$mode" in
      marketing) grep -Fq 'the plan costs $29 per month' draft.md || false ;;
      docs) grep -Fq 'Both receive job 42' draft.md || false ;;
      clean) grep -Fq 'Imagine a triangle' draft.md || false ;;
      fiction-edit) grep -Fq 'She had seven minutes' draft.md || false ;;
      fiction-quotes) grep -Fq 'She folded the paper' draft.md || false ;;
      fiction-voice) grep -Fq 'Neither of you smiles' draft.md || false ;;
    esac
  done
}

@test "humanize rhetoric fixture rejects an unknown mode without creating a draft" {
  cd "$BATS_TEST_TMPDIR" || return 1
  run bash "$REPO_ROOT/evals/_lib/humanize-rhetoric-fixture.sh" unknown
  [ "$status" -eq 2 ] || false
  [ ! -e draft.md ] || false
}
