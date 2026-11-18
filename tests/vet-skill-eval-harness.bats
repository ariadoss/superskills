#!/usr/bin/env bats
# The vet-skill eval fixtures: dev and holdout seeds build into a bad tree and a
# clean tree, the scanner finds what the bad seeds plant, and the clean tree is
# a true negative control. These tests check the fixtures and the scanner only;
# the eval measures the agent.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIX="$REPO_ROOT/evals/_lib/pentest_fixture.py"
  SCAN="$REPO_ROOT/skills/vet-skill/tools/vet_scan.py"
  EXTRACT="$REPO_ROOT/evals/_lib/extract_finals.py"
  SEEDS="$REPO_ROOT/evals/vet-skill"
}

# build <seeds file> <bad|clean> <name>: builds the tree into $BATS_TEST_TMPDIR/<name>
build() {
  jq --arg t "$2" '[.[] | select(.tree==$t)]' "$1" > "$BATS_TEST_TMPDIR/$3-seeds.json"
  python3 -I "$FIX" build "$BATS_TEST_TMPDIR/$3-seeds.json" "$BATS_TEST_TMPDIR/$3" "$BATS_TEST_TMPDIR/$3-key.json"
}

@test "the dev bad seeds build, and the scanner floors them at block" {
  build "$SEEDS/seeds-dev.json" bad bad
  run python3 -I "$SCAN" "$BATS_TEST_TMPDIR/bad"
  [ "$(echo "$output" | jq -r '.floor')" = "block" ]
}

@test "the dev clean seeds build, and the scanner does not block them" {
  build "$SEEDS/seeds-dev.json" clean clean
  run python3 -I "$SCAN" "$BATS_TEST_TMPDIR/clean"
  [ "$(echo "$output" | jq -r '.floor')" != "block" ]
}

@test "the holdout bad seeds build, and the scanner floors them at block" {
  build "$SEEDS/seeds-holdout.json" bad hbad
  run python3 -I "$SCAN" "$BATS_TEST_TMPDIR/hbad"
  [ "$(echo "$output" | jq -r '.floor')" = "block" ]
}

@test "the holdout clean seeds build, and the scanner does not block them" {
  build "$SEEDS/seeds-holdout.json" clean hclean
  run python3 -I "$SCAN" "$BATS_TEST_TMPDIR/hclean"
  [ "$(echo "$output" | jq -r '.floor')" != "block" ]
}

@test "every URL in every seed file is on the .invalid domain" {
  run bash -c "grep -hoE 'https?://[^\" )]+' '$SEEDS'/seeds-*.json | grep -v '\.invalid' | head -1"
  [ -z "$output" ] || false
}

@test "the fixture keeps invisible characters intact when it writes a file" {
  build "$SEEDS/seeds-dev.json" bad bad
  run grep -rl "$(printf '\xe2\x80\x8b')" "$BATS_TEST_TMPDIR/bad"
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/bad/docs/INSTALL.md" ]
}

@test "seed files hold no raw invisible characters, only escapes" {
  run python3 -I -c 'import sys; sys.exit(any(ord(c) > 127 for f in sys.argv[1:] for c in open(f, encoding="utf-8").read()))' "$SEEDS"/seeds-dev.json "$SEEDS"/seeds-holdout.json
  [ "$status" -eq 0 ]
}

@test "seed ids and paths are unique per file, and every seed has the required keys" {
  for f in "$SEEDS"/seeds-dev.json "$SEEDS"/seeds-holdout.json; do
    run jq -e '
      (map(.id) | length == (unique | length))
      and (map(.tree + "/" + .path) | length == (unique | length))
      and all(.[]; has("id") and has("category") and has("kind") and has("path")
                   and has("lines") and has("vuln_line_index") and (.tree == "bad" or .tree == "clean"))' "$f"
    [ "$status" -eq 0 ]
  done
}

@test "each scanner-covered bad seed is found by its rule at the seed's path and line" {
  for f in seeds-dev seeds-holdout; do
    build "$SEEDS/$f.json" bad "$f"
    python3 -I "$SCAN" "$BATS_TEST_TMPDIR/$f" > "$BATS_TEST_TMPDIR/$f-scan.json" || true
    jq -c '.[] | select(.scanner_rule != null) | {id, rule: .scanner_rule, path, line: (.vuln_line_index + 1)}' \
      "$SEEDS/$f.json" > "$BATS_TEST_TMPDIR/$f-want.jsonl"
    [ -s "$BATS_TEST_TMPDIR/$f-want.jsonl" ]
    while read -r want; do
      run jq -e --argjson w "$want" \
        'any(.findings[]; .rule == $w.rule and .path == $w.path and .line == $w.line)' "$BATS_TEST_TMPDIR/$f-scan.json"
      if [ "$status" -ne 0 ]; then echo "$f: seed not found by the scanner: $want"; false; fi
    done < "$BATS_TEST_TMPDIR/$f-want.jsonl"
  done
}

@test "the uncovered holdout seed is present and the scanner reports nothing on its file" {
  run jq -e '[.[] | select(.category=="uncovered")] | length == 1
             and .[0].kind == "vuln" and .[0].tree == "bad"
             and .[0].mechanism_re == "permission|scope|broader|exceeds"' "$SEEDS/seeds-holdout.json"
  [ "$status" -eq 0 ]
  p="$(jq -r '.[] | select(.category=="uncovered") | .path' "$SEEDS/seeds-holdout.json")"
  build "$SEEDS/seeds-holdout.json" bad hbad
  run python3 -I "$SCAN" "$BATS_TEST_TMPDIR/hbad"
  [ "$(echo "$output" | jq --arg p "$p" '[.findings[] | select(.path == $p)] | length')" = "0" ]
}

@test "extract_finals writes the SubagentHandback message and reports the tool-use count" {
  printf '%s\n' \
    '{"message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}' \
    '{"message":{"content":[{"type":"tool_use","id":"t2","name":"SubagentHandback","input":{"message":"final report text"}}]}}' \
    > "$BATS_TEST_TMPDIR/t.jsonl"
  run python3 -I "$EXTRACT" "$BATS_TEST_TMPDIR/t.jsonl" "$BATS_TEST_TMPDIR/final.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/final.txt 2 True" ]
  [ "$(cat "$BATS_TEST_TMPDIR/final.txt")" = "final report text" ]
}

@test "each seed's mechanism_re matches its own planted line and report sentence, and no other seed's" {
  run python3 -I - "$SEEDS/seeds-dev.json" "$SEEDS/seeds-holdout.json" <<'PY'
import json, re, sys
bad = []
for path in sys.argv[1:]:
    seeds = json.load(open(path, encoding="utf-8"))
    rx = {s["id"]: re.compile(s["mechanism_re"], re.I) for s in seeds if s.get("mechanism_re")}  # grader flags
    text = {s["id"]: s["lines"][s["vuln_line_index"]] for s in seeds}
    report = {s["id"]: s.get("report_line", "") for s in seeds}
    whole = {s["id"]: "\n".join(s["lines"]) for s in seeds}
    tree = {s["id"]: s["tree"] for s in seeds}  # a fixture is one tree, so only same-tree seeds can be confused
    for sid, r in rx.items():
        if not r.search(text[sid]):
            bad.append(f"{path}: {sid} does not match its own planted line")
        if not report[sid] or not r.search(report[sid]):
            bad.append(f"{path}: {sid} does not match its own report sentence")
        for other in text:
            if other == sid or tree[other] != tree[sid]:
                continue
            for what, hay in (("planted line", text[other]), ("report sentence", report[other])):
                if r.search(hay):
                    bad.append(f"{path}: {sid} pattern also matches the {what} of {other}")
            if other in rx and rx[other].search(whole[sid]) and sid.endswith("uncovered"):
                bad.append(f"{path}: pattern of {other} matches the uncovered file")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "extract_finals skips blocks without an id, non-object lines and a non-object input" {
  printf '%s\n' \
    '[1,2]' '"text"' 'null' \
    '{"message":{"content":[{"type":"tool_use","name":"Read","input":{}}]}}' \
    '{"message":{"content":[{"type":"tool_use","id":"t1","name":"SubagentHandback","input":"oops"}]}}' \
    '{"message":{"content":["plain",{"type":"tool_use","id":"t2","name":"SubagentHandback","input":{"message":"kept"}}]}}' \
    > "$BATS_TEST_TMPDIR/odd.jsonl"
  run python3 -I "$EXTRACT" "$BATS_TEST_TMPDIR/odd.jsonl" "$BATS_TEST_TMPDIR/final.txt"
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/final.txt")" = "kept" ]
  [ "$output" = "$BATS_TEST_TMPDIR/final.txt 2 True" ]
}
