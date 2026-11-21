#!/usr/bin/env bats
# Tests for evals/debrief-v2/regrade: pre-registration, calibration pairs, anonymiser.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  RG="$REPO_ROOT/evals/debrief-v2/regrade"
}

@test "PREREG states the positive class and every threshold" {
  grep -q 'Positive class: FAIL' "$RG/PREREG.md"
  grep -q 'TPR >= 0.85, TNR >= 0.85, accuracy >= 0.85' "$RG/PREREG.md"
  grep -q '|TPR - TNR| <= 0.10' "$RG/PREREG.md"
  grep -q 'Repeatability: item-level agreement between pass A and pass B >= 0.90' "$RG/PREREG.md"
}

@test "calibration pairs are JSONL with PASS/FAIL human and judge labels" {
  run python3 -I - "$RG/calibration-pairs.jsonl" <<'PY'
import json, sys
n = 0
for line in open(sys.argv[1]):
    if not line.strip():
        continue
    p = json.loads(line)
    assert p["human"] in ("PASS", "FAIL") and p["judge"] in ("PASS", "FAIL"), p
    n += 1
assert n >= 192, n
PY
  [ "$status" -eq 0 ] || false
}

@test "anonymise writes the body without its header under a random id" {
  src="$BATS_TEST_TMPDIR/src"
  mkdir -p "$src"
  printf 'agent id: a1 (run r03, fixture public, arm x, n=1)\n\nLine one about r07/inst.\nLine two.\n' > "$src/public-x-1.md"
  printf 'SYNTHETIC CONTROL (test)\n\nControl body.\n' > "$src/private-c01.md"
  run python3 -I "$RG/anonymise.py" --out "$BATS_TEST_TMPDIR/out" --map "$BATS_TEST_TMPDIR/map.json" "$src/public-x-1.md" "$src/private-c01.md"
  [ "$status" -eq 0 ] || false
  run python3 -I - "$BATS_TEST_TMPDIR/out" "$BATS_TEST_TMPDIR/map.json" <<'PY'
import json, os, re, sys
out, mp = sys.argv[1], json.load(open(sys.argv[2]))
fx = json.load(open(os.path.join(out, "fixtures.json")))
assert sorted(fx) == sorted(mp) and len(mp) == 2
for tid, src in mp.items():
    assert re.fullmatch(r"[0-9a-f]{8}", tid), tid
    body = open(os.path.join(out, tid + ".md")).read()
    if src.endswith("public-x-1.md"):
        assert body == "Line one about rNN/inst.\nLine two.\n", repr(body)
        assert fx[tid] == "public"
    else:
        assert body == "Control body.\n", repr(body)
        assert fx[tid] == "private"
PY
  [ "$status" -eq 0 ] || false
}

@test "anonymise refuses a file name without a fixture prefix" {
  printf 'body\n' > "$BATS_TEST_TMPDIR/other.md"
  run python3 -I "$RG/anonymise.py" --out "$BATS_TEST_TMPDIR/o" --map "$BATS_TEST_TMPDIR/m.json" "$BATS_TEST_TMPDIR/other.md"
  [ "$status" -ne 0 ] || false
}
