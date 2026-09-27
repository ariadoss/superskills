#!/usr/bin/env bats
# Tests for skills/humanize/toolkit — the packaged closure, not the upstream
# toolkit it was copied from. These are packaging tests: the scripts are only
# useful if every data file they load travelled with them, and two of the
# failure modes are silent (a missing phrase-probability table makes the legacy
# index read 0.0 rather than "unavailable"), so they are asserted explicitly.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # Layout-agnostic on purpose: this same file ships unmodified in the standalone
  # humanize repo, where the skill sits at the root. An export that rewrote paths
  # would be a transformation that can drift; locating them instead cannot.
  if [ -d "$REPO_ROOT/skills/humanize/toolkit" ]; then
    TK="$REPO_ROOT/skills/humanize/toolkit"
    SKILL_MD="$REPO_ROOT/skills/humanize/SKILL.md"
  else
    TK="$REPO_ROOT/toolkit"
    SKILL_MD="$REPO_ROOT/SKILL.md"
  fi
  SAMPLE="$BATS_TEST_TMPDIR/s.md"
  # Deliberately slop-heavy: EQ-Bench words, a bigram, an em-dash, double spaces.
  printf 'Our roadmap is a tapestry of features—a delicate balance of speed and scale.\nStakeholders murmured about a cost change that was almost imperceptible.  The plan was thick with unspoken assumptions.\n' > "$SAMPLE"
}

@test "the closure is complete: every data file the scripts load is present" {
  for f in emdash_fix.py mla_format.py slop_report.py eq_bench_slop_index.py \
           construction_scanner.py ai_slop_wordlist.json ai_overused_research.json \
           llm_slop.json eq_bench_slop_list.json eq_bench_slop_list_bigrams.json \
           eq_bench_slop_list_trigrams.json top2000_en.json \
           eq_bench_slop_phrase_prob_adjustments.json NOTICE.md; do
    [ -f "$TK/$f" ] || { echo "missing $f"; return 1; }
  done
}

@test "every bundled json parses" {
  for f in "$TK"/*.json; do
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" || { echo "bad json: $f"; return 1; }
  done
}

@test "emdash_fix converts a paired-dash aside to commas (needs no spaCy)" {
  # The paired form A—mid—B is resolved by grammar alone, so this assertion holds
  # in any environment. The clause-role paths that DO need spaCy are covered by
  # the two tests below, one per availability.
  printf 'The platform, fast and stable—a benchmark by then—served every region.\n' > "$BATS_TEST_TMPDIR/p.md"
  run bash -c "python3 '$TK/emdash_fix.py' '$BATS_TEST_TMPDIR/p.md'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"—"* ]] || false
  [[ "$output" == *"stable (a benchmark by then)"* || "$output" == *"stable, a benchmark by then,"* ]] || false
}

@test "with spaCy an independent clause becomes a period, an appositive a comma" {
  python3 -c "import spacy; spacy.load('en_core_web_sm')" 2>/dev/null || skip "spaCy/en_core_web_sm not installed"
  printf 'We shipped the fix—the outage was already over.\nThe dashboard was a mess—a wall of charts.\n' > "$BATS_TEST_TMPDIR/c.md"
  run bash -c "python3 '$TK/emdash_fix.py' '$BATS_TEST_TMPDIR/c.md'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fix. The outage"* ]] || false
  [[ "$output" == *"mess, a wall of charts"* ]] || false
}

@test "mla_format collapses double spaces after sentence punctuation" {
  run bash -c "python3 '$TK/emdash_fix.py' '$SAMPLE' | python3 '$TK/mla_format.py' /dev/stdin"
  [ "$status" -eq 0 ]
  [[ "$output" != *"imperceptible.  The"* ]] || false
}

@test "slop_report flags the planted EQ-Bench words with line numbers" {
  run bash -c "python3 '$TK/slop_report.py' '$SAMPLE'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tapestry"* ]] || false
  [[ "$output" == *"murmured"* ]] || false
  [[ "$output" == *"L1:"* ]] || false
}

@test "slop_report flags a planted bigram" {
  run bash -c "python3 '$TK/slop_report.py' '$SAMPLE'"
  [[ "$output" == *"almost imperceptible"* ]] || false
}

@test "the legacy phrase-probability index is live, not a silent zero" {
  # Guards the packaging trap: drop eq_bench_slop_phrase_prob_adjustments.json and
  # this number reads 0.0 with no error, which would look like clean prose.
  run bash -c "python3 '$TK/slop_report.py' '$SAMPLE' | grep -o 'legacy_slop_index = [0-9.]*'"
  [ "$status" -eq 0 ]
  [[ "$output" != "legacy_slop_index = 0.0" ]] || false
}

@test "both subprocess scorers ran (no swallowed exception)" {
  run bash -c "python3 '$TK/slop_report.py' '$SAMPLE'"
  [[ "$output" == *"slop_index = "* ]] || false
  [[ "$output" == *"CONSTRUCTION SCANNER"* ]] || false
}

@test "an exempt list suppresses a flagged term" {
  printf 'tapestry\n' > "$BATS_TEST_TMPDIR/ex.txt"
  run bash -c "python3 '$TK/slop_report.py' '$SAMPLE' --exempt '$BATS_TEST_TMPDIR/ex.txt'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[tapestry]"* ]] || false
}

@test "every non-stdlib import is an optional, documented dependency" {
  # This test previously scanned only column-0 imports and passed while
  # emdash_fix.py imported spaCy INSIDE a function — a false pass that hid a
  # ModuleNotFoundError crash. Match imports at any indentation.
  run bash -c "grep -hE '^[[:space:]]*(import|from) ' '$TK'/emdash_fix.py '$TK'/mla_format.py '$TK'/slop_report.py '$TK'/eq_bench_slop_index.py '$TK'/construction_scanner.py \
    | sed -E 's/^[[:space:]]+//' \
    | grep -vE '^(import|from) (re|sys|json|statistics|subprocess|math|os|argparse|collections|pathlib|__future__|typing|unicodedata|itertools|functools|textwrap|string)([. ]|\$)'"
  # Exactly two optional third-party deps are allowed, and both must be
  # documented. spaCy decides clause role; NLTK improves tokenizing/syllables
  # and already falls back to regex + a heuristic when absent.
  # Everything left after removing stdlib and the toolkit's own sibling modules
  # must be spaCy or NLTK: grep -o'ing for just those two used to drop any other
  # third-party import on the floor instead of failing on it.
  imports="$(grep -hE '^[[:space:]]*(import|from) ' "$TK"/*.py | sed -E 's/^[[:space:]]+//' \
    | grep -vE '^(import|from) (re|sys|json|statistics|subprocess|math|os|argparse|collections|pathlib|__future__|typing|unicodedata|itertools|functools|textwrap|string|tempfile|shutil|mla_format|textio|emdash_fix|eq_bench_slop_index)([. ]|$)')"
  run bash -c "printf '%s\n' \"\$1\" | grep -vE '^(import|from) (spacy|nltk)([. ]|$)' | grep -c ." _ "$imports"
  [ "$output" = "0" ] || { echo "undocumented non-stdlib imports: $(printf '%s\n' "$imports" | grep -vE '(spacy|nltk)')"; return 1; }
  run bash -c "printf '%s\n' \"\$1\" | grep -oE '(spacy|nltk)' | sort -u | tr '\n' ' '" _ "$imports"
  [ "$output" = "nltk spacy " ] || { echo "expected optional deps missing: $output"; return 1; }
  for dep in spacy nltk; do
    run bash -c "grep -ci '$dep' '$SKILL_MD'"
    [ "$output" -ge 1 ] || { echo "optional dep not documented in SKILL.md: $dep"; return 1; }
  done
}

@test "without spaCy it keeps undecidable dashes and says so, instead of crashing" {
  # The crash this guards against: emdash_fix.py raised ModuleNotFoundError from
  # inside _is_independent, so any prose with a dash joining two clauses died.
  cat > "$BATS_TEST_TMPDIR/ind.md" <<'M'
We shipped the fix—the outage was already over.
M
  run bash -c "cd '$TK' && python3 -c \"
import sys
sys.path=[p for p in sys.path if 'site-packages' not in p and 'dist-packages' not in p]
sys.argv=['emdash_fix.py','$BATS_TEST_TMPDIR/ind.md']
import runpy; runpy.run_path('emdash_fix.py', run_name='__main__')
\" 2>&1"
  [ "$status" -eq 0 ] || { echo "crashed without spaCy: $output"; return 1; }
  [[ "$output" == *"—the outage"* ]] || false
  [[ "$output" == *"pip install spacy"* ]] || false
}

@test "no personal paths or private repo names leaked into the package" {
  # Generated bytecode embeds absolute source paths and is never exported, so it
  # is excluded; only shipped source and data are checked.
  # Generic on purpose: this file ships publicly, so it names no private project.
  run bash -c "grep -rlE --exclude-dir=__pycache__ --exclude='*.pyc' '/Users/[^/ ]+/|/home/[^/ ]+/' '$TK' || true"
  [ -z "$output" ] || { echo "leaked: $output"; return 1; }
}

@test "NOTICE.md carries the Apache-2.0 attribution that must travel with redistribution" {
  run bash -c "cat '$TK/NOTICE.md'"
  [[ "$output" == *"Apache-2.0"* ]] || false
  [[ "$output" == *"antislop-sampler"* ]] || false
  [[ "$output" == *"wordfreq"* ]] || false
}

@test "the toolkit CLIs print usage and exit 1 with no arguments" {
  for f in slop_report.py mla_format.py emdash_fix.py; do
    run bash -c "python3 '$TK/$f'"
    [ "$status" -eq 1 ] || { echo "$f: expected exit 1, got $status"; return 1; }
    [[ "$output" == *usage:* ]] || { echo "$f: no usage line"; return 1; }
  done
}

@test "slop_report on a missing file fails with one clean line, not a traceback" {
  run bash -c "python3 '$TK/slop_report.py' '$BATS_TEST_TMPDIR/does-not-exist.md'"
  [ "$status" -ne 0 ]
  [[ "$output" != *Traceback* ]] || { echo "leaked a traceback: $output"; return 1; }
  [[ "$output" == *"does-not-exist.md"* ]] || { echo "error does not name the file: $output"; return 1; }
}

# skill_snippet — the TOOLKIT-resolution bash block exactly as SKILL.md ships it.
skill_snippet() {
  awk '/`TOOLKIT` below means/{f=1} f&&/^```bash$/{g=1;next} g&&/^```$/{exit} g' "$SKILL_MD"
}

@test "SKILL.md's toolkit resolution works from an unrelated working directory" {
  # Regression: it used $0, which in an agent's shell is the shell, so from any
  # normal project directory it pointed at the wrong toolkit/.
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
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  run bash -c "cd '$BATS_TEST_TMPDIR/empty' && HOME='$BATS_TEST_TMPDIR/empty' && $(printf '%s' "$snippet" | sed "s#<base directory for this skill>#/nonexistent#")"
  [ "$status" -ne 0 ] || { echo "resolved a nonexistent toolkit: $output"; return 1; }
  [[ "$output" == *"toolkit not found"* ]] || false
}

@test "mla_format keeps Markdown structure: hard breaks, indentation, fenced code" {
  # Two trailing spaces are a Markdown hard break; leading spaces can be an
  # indented code block; and inside a fence, `--in-place` is a CLI flag, not a
  # dash. The docstring promises structure is left alone; all three were changed.
  f="$BATS_TEST_TMPDIR/md.md"
  printf 'Line one  \nLine two.  Double spaced.\n    indented  code\n```\nrun --in-place  now\n```\n' > "$f"
  run python3 "$TK/mla_format.py" "$f"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Line one  "$'\n'"Line two."* ]] || { echo "hard break lost: $output"; return 1; }
  [[ "$output" == *"Line two. Double spaced."* ]] || { echo "prose double space not collapsed: $output"; return 1; }
  [[ "$output" == *"    indented"* ]] || { echo "indentation lost: $output"; return 1; }
  [[ "$output" == *"run --in-place  now"* ]] || { echo "fenced code altered: $output"; return 1; }
}

@test "normalize.py: a failing stage never leaves an empty 'humanized' file behind" {
  # Regression: step 1 was a shell pipe. When emdash_fix.py failed, mla_format.py
  # happily formatted empty stdin, the pipe exited 0, and the scan then reported
  # the empty file as slop_index 0.0 -- a clean bill for no text at all.
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/missing.md" "$BATS_TEST_TMPDIR/out.md"
  [ "$status" -ne 0 ] || { echo "reported success for a missing input"; return 1; }
  [ ! -e "$BATS_TEST_TMPDIR/out.md" ] || { echo "left an output file behind"; return 1; }
}

@test "normalize.py refuses to overwrite its source" {
  printf 'Text—here.\n' > "$BATS_TEST_TMPDIR/src.md"
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/src.md" "$BATS_TEST_TMPDIR/src.md"
  [ "$status" -ne 0 ] || { echo "overwrote the source"; return 1; }
  [ "$(cat "$BATS_TEST_TMPDIR/src.md")" = "Text—here." ] || false
}

@test "normalize.py output equals emdash_fix then mla_format" {
  printf 'The platform, fast and stable—a benchmark by then—served users.  Twice.\n' > "$BATS_TEST_TMPDIR/n.md"
  expected="$(python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/n.md" 2>/dev/null | python3 "$TK/mla_format.py" /dev/stdin)"
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/n.md" "$BATS_TEST_TMPDIR/n_out.md"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(cat "$BATS_TEST_TMPDIR/n_out.md")" = "$expected" ] || { echo "got: $(cat "$BATS_TEST_TMPDIR/n_out.md")"; return 1; }
}

@test "SKILL.md step 1 uses the failure-propagating driver, not a bare pipe" {
  run grep -c 'normalize.py' "$SKILL_MD"
  [ "$output" -ge 1 ] || { echo "SKILL.md does not use normalize.py"; return 1; }
  run grep -cE 'emdash_fix\.py .*\| *python3 .*mla_format\.py' "$SKILL_MD"
  [ "$output" = "0" ] || { echo "SKILL.md still pipes emdash_fix into mla_format"; return 1; }
}

@test "a paired dash around an independent clause never becomes a comma splice" {
  # Regression: every paired aside became commas, so "left—it was late—and"
  # turned into "left, it was late, and": a splice. Parentheses are grammatical
  # around any aside, so they are the fallback whenever the aside is (or might
  # be) a full clause. Run with site-packages stripped: no spaCy, no guessing.
  printf 'The team paused the rollout—it was late—and resumed it Monday.\n' > "$BATS_TEST_TMPDIR/pi.md"
  run bash -c "cd '$TK' && python3 -c \"
import sys
sys.path=[p for p in sys.path if 'site-packages' not in p and 'dist-packages' not in p]
sys.argv=['emdash_fix.py','$BATS_TEST_TMPDIR/pi.md']
import runpy; runpy.run_path('emdash_fix.py', run_name='__main__')
\" 2>/dev/null"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"rollout (it was late) and"* ]] || { echo "got: $output"; return 1; }
}

@test "with spaCy a paired independent clause gets parentheses, an appositive commas" {
  python3 -c "import spacy; spacy.load('en_core_web_sm')" 2>/dev/null || skip "spaCy/en_core_web_sm not installed"
  printf 'The team paused the rollout—it was late—and resumed it Monday.\nThe platform—a benchmark by then—served every region.\n' > "$BATS_TEST_TMPDIR/ps.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/ps.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rollout (it was late) and"* ]] || { echo "got: $output"; return 1; }
  [[ "$output" == *"platform, a benchmark by then, served"* ]] || { echo "got: $output"; return 1; }
}

@test "emdash_fix leaves fenced and indented code alone" {
  # `--in-place` in a code block is a CLI flag; EM matched it as a dash.
  printf 'Prose—here.\n```\nrun --in-place now\n```\n    tool --flag x\n' > "$BATS_TEST_TMPDIR/code.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/code.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"run --in-place now"* ]] || { echo "fenced code altered: $output"; return 1; }
  [[ "$output" == *"    tool --flag x"* ]] || { echo "indented code altered: $output"; return 1; }
}

@test "construction_scanner counts and flags planted constructions" {
  printf 'The team works the way a startup works when it has lost funding. The product sells the way a habit sells. It was as if the market had stopped.\n' > "$BATS_TEST_TMPDIR/cs.md"
  run python3 "$TK/construction_scanner.py" "$BATS_TEST_TMPDIR/cs.md"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run python3 -c 'import json,sys; r=json.loads(sys.argv[1]); t={f["type"] for f in r["flags"]}; print(r["way_x_count"], r["as_if_count"], "way_x_density" in t, "as_if_density" in t)' "$output"
  [ "$output" = "2 1 True True" ] || { echo "got: $output"; return 1; }
}

@test "cmudict is loaded once per process, and a failed load is not retried" {
  # Regression: cmudict.dict() rebuilt ~130k entries on every syllable_count call.
  # A stub nltk on the path counts loads, so this needs no real corpus.
  stub="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$stub/nltk/corpus"
  : > "$stub/nltk/__init__.py"
  cat > "$stub/nltk/corpus/__init__.py" <<'PY'
import os
class _C:
    loads = 0
    def dict(self):
        _C.loads += 1
        if os.environ.get("STUB_FAIL"):
            raise LookupError("no corpus")
        return {"hello": [["HH", "AH0", "L", "OW1"]]}
cmudict = _C()
PY
  probe='import sys; sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2]); import eq_bench_slop_index as e; from nltk.corpus import cmudict; [e.syllable_count(w) for w in ("hello", "world", "hello")]; print(cmudict.loads, e.syllable_count("hello"))'
  run python3 -B -c "$probe" "$stub" "$TK"
  [ "$output" = "1 2" ] || { echo "cached path: $output"; return 1; }
  run env STUB_FAIL=1 python3 -B -c "$probe" "$stub" "$TK"
  [ "$output" = "1 2" ] || { echo "failure path (want 1 load, heuristic 2): $output"; return 1; }
}

@test "SKILL.md never resolves the toolkit against the shell's cwd" {
  # A ./toolkit fallback would run whatever toolkit/ the agent's cwd holds.
  run grep -cE '"\./toolkit"' "$SKILL_MD"
  [ "$output" = "0" ] || { echo "SKILL.md still falls back to ./toolkit"; return 1; }
}

@test "normalize.py reports an unwritable output cleanly, without a traceback" {
  printf 'Text—here.\n' > "$BATS_TEST_TMPDIR/w.md"
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/w.md" "$BATS_TEST_TMPDIR/no-such-dir/out.md"
  [ "$status" -eq 2 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" != *"Traceback"* ]] || { echo "$output"; return 1; }
  [[ "$output" == *"cannot write"* ]] || false
}

@test "every toolkit CLI rejects a non-UTF-8 file with a clean message, not a traceback" {
  # Found by fuzzing: a stray Latin-1 byte crashed four of them with UnicodeDecodeError.
  printf 'Caf\xe9 society\xb1.\n' > "$BATS_TEST_TMPDIR/latin1.md"
  for tool in emdash_fix mla_format construction_scanner slop_report eq_bench_slop_index normalize; do
    if [ "$tool" = normalize ]; then
      run python3 "$TK/$tool.py" "$BATS_TEST_TMPDIR/latin1.md" "$BATS_TEST_TMPDIR/l_out.md"
    else
      run python3 "$TK/$tool.py" "$BATS_TEST_TMPDIR/latin1.md"
    fi
    [ "$status" -eq 2 ] || { echo "$tool: status $status: $output"; return 1; }
    [[ "$output" != *"Traceback"* ]] || { echo "$tool: $output"; return 1; }
    [[ "$output" == *"not valid UTF-8"* ]] || { echo "$tool: $output"; return 1; }
  done
}

@test "emdash_fix --tighten keeps dashes but closes them, sparing ranges and code" {
  printf 'We paused — it was late -- and pp. 12–15 stayed.\n```\nrun --flag\n```\n' > "$BATS_TEST_TMPDIR/t.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/t.md" --tighten
  [ "$status" -eq 0 ]
  [[ "$output" == *"paused—it was late—and pp. 12–15 stayed."* ]] || { echo "got: $output"; return 1; }
  [[ "$output" == *"run --flag"* ]] || { echo "code altered: $output"; return 1; }
}

@test "emdash_fix --in-place rewrites the file and says so" {
  printf 'The platform—a benchmark by then—scaled.\n' > "$BATS_TEST_TMPDIR/ip.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/ip.md" --in-place
  [ "$status" -eq 0 ]
  [[ "$output" == *"fixed em-dashes in"* ]] || false
  run cat "$BATS_TEST_TMPDIR/ip.md"
  [[ "$output" != *"—"* ]] || { echo "file not rewritten: $output"; return 1; }
}

@test "a trailing break-off dash ends the sentence with a period" {
  printf 'The deploy stopped mid-run—\n' > "$BATS_TEST_TMPDIR/bo.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/bo.md"
  [ "$status" -eq 0 ]
  [ "$output" = "The deploy stopped mid-run." ] || { echo "got: [$output]"; return 1; }
}

@test "mla_format --in-place rewrites the file" {
  printf 'One.  Two — three.\n' > "$BATS_TEST_TMPDIR/m.md"
  run python3 "$TK/mla_format.py" "$BATS_TEST_TMPDIR/m.md" --in-place
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/m.md")" = "One. Two—three." ] || { echo "got: $(cat "$BATS_TEST_TMPDIR/m.md")"; return 1; }
}

@test "normalize.py with the wrong argument count prints usage and exits 1" {
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/only-one.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: python3 normalize.py SRC OUT"* ]] || false
}

@test "normalize.py leaves no temp file behind when the final rename fails" {
  # OUT is an existing directory: mkstemp succeeds beside it, os.replace fails.
  printf 'Text—here.\n' > "$BATS_TEST_TMPDIR/rn.md"
  mkdir -p "$BATS_TEST_TMPDIR/rnout/target.md"
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/rn.md" "$BATS_TEST_TMPDIR/rnout/target.md"
  [ "$status" -eq 2 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" != *"Traceback"* ]] || { echo "$output"; return 1; }
  [ -z "$(find "$BATS_TEST_TMPDIR/rnout" -maxdepth 1 -name '.*.tmp')" ] || { echo "temp file left behind"; return 1; }
}

@test "construction_scanner scores several files as a JSON list, and --calibrate tabulates them" {
  printf 'The team works the way a startup works. It was as if the market fell.\n' > "$BATS_TEST_TMPDIR/c1.md"
  printf 'Plain words here.\n' > "$BATS_TEST_TMPDIR/c2.md"
  run python3 "$TK/construction_scanner.py" "$BATS_TEST_TMPDIR/c1.md" "$BATS_TEST_TMPDIR/c2.md"
  [ "$status" -eq 0 ]
  run python3 -c 'import json,sys; r=json.loads(sys.argv[1]); print(len(r), r[1]["verdict"])' "$output"
  [ "$output" = "2 CLEAN" ] || { echo "got: $output"; return 1; }
  run python3 "$TK/construction_scanner.py" --calibrate "$BATS_TEST_TMPDIR/c1.md" "$BATS_TEST_TMPDIR/c2.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"c1.md"*"AI_SIGNAL"* ]] || { echo "got: $output"; return 1; }
  [[ "$output" == *"c2.md"*"CLEAN"* ]] || { echo "got: $output"; return 1; }
}

@test "slop_report warns when the --exempt file does not exist, instead of silently exempting nothing" {
  run python3 "$TK/slop_report.py" "$SAMPLE" --exempt "$BATS_TEST_TMPDIR/typo-terms.txt"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"exempt file not found"* ]] || { echo "no warning for a missing exempt file"; return 1; }
}

@test "slop_report --exempt with no value is a usage error, not a traceback" {
  run python3 "$TK/slop_report.py" "$SAMPLE" --exempt
  [ "$status" -eq 1 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" != *"Traceback"* ]] || { echo "$output"; return 1; }
  [[ "$output" == *"usage:"* ]] || false
}

@test "the toolkit imports as a package, via runpy, and through symlinks" {
  # Downstream projects symlink these files into their own package and use
  # `from pkg.emdash_fix import ...` or runpy.run_path(...). Bare sibling
  # imports (`from textio import ...`) only resolved when run as a script.
  d="$BATS_TEST_TMPDIR/downstream"
  mkdir -p "$d/pkg"
  : > "$d/pkg/__init__.py"
  for f in "$TK"/*.py "$TK"/*.json "$TK"/*.txt; do ln -s "$f" "$d/pkg/$(basename "$f")"; done
  printf 'We paused—it was late—and.\n' > "$d/in.md"
  run bash -c "cd '$d' && python3 -B -c '
from pkg.emdash_fix import fix_text
from pkg.mla_format import mla_format
from pkg.slop_report import prose_lines
from pkg.normalize import main
print(mla_format(fix_text(\"a — b\")) != \"\")'"
  [ "$status" -eq 0 ] || { echo "package import failed: $output"; return 1; }
  run bash -c "cd / && python3 -B -c 'import runpy, sys; sys.argv=[\"slop_report.py\", \"$d/in.md\"]; runpy.run_path(\"$d/pkg/slop_report.py\", run_name=\"__main__\")'"
  [ "$status" -eq 0 ] || { echo "runpy failed: $output"; return 1; }
  [[ "$output" == *"SLOP"* ]] || false
}

@test "inline code and table rows pass through both stages untouched" {
  # Found running /humanize on this repo's docs: `./setup --host codex` became
  # `./setup, host codex`, and a table cell's dash placeholder became a comma.
  printf 'Run `./setup --host codex` — then restart.\n| a — b | `x  --  y` |\n- item — with `git push --force`\n' > "$BATS_TEST_TMPDIR/ic.md"
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/ic.md" "$BATS_TEST_TMPDIR/ic_out.md"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run cat "$BATS_TEST_TMPDIR/ic_out.md"
  [[ "$output" == *'`./setup --host codex`'* ]] || { echo "inline code altered: $output"; return 1; }
  [[ "$output" == *'| a — b | `x  --  y` |'* ]] || { echo "table row altered: $output"; return 1; }
  [[ "$output" == *'`git push --force`'* ]] || { echo "inline code in a list altered: $output"; return 1; }
}

@test "link targets pass through untouched" {
  # Found on this repo's README: the anchor #packs--choose-what-gets-installed
  # became "#packs, choose-what-gets-installed".
  printf 'See the [packs](#packs--choose-what-gets-installed) and <https://x.test/a--b> — then decide.\n' > "$BATS_TEST_TMPDIR/lk.md"
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/lk.md" "$BATS_TEST_TMPDIR/lk_out.md"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run cat "$BATS_TEST_TMPDIR/lk_out.md"
  [[ "$output" == *"(#packs--choose-what-gets-installed)"* ]] || { echo "link target altered: $output"; return 1; }
  [[ "$output" == *"<https://x.test/a--b>"* ]] || { echo "autolink altered: $output"; return 1; }
}

@test "a dash after a list item's label becomes a colon" {
  printf -- '- [gstack](https://x.test/gstack) — virtual engineering team\n- **Scoped** — touches only QA profiles\n- `uv tool install clearwing` — for `/pentest`\n1. Plain words — a gloss\n' > "$BATS_TEST_TMPDIR/gl.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/gl.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- [gstack](https://x.test/gstack): virtual engineering team"* ]] || { echo "got: $output"; return 1; }
  [[ "$output" == *"- **Scoped**: touches only QA profiles"* ]] || { echo "got: $output"; return 1; }
  [[ "$output" == *'- `uv tool install clearwing`: for `/pentest`'* ]] || { echo "got: $output"; return 1; }
  [[ "$output" == *"1. Plain words: a gloss"* ]] || { echo "got: $output"; return 1; }
}

@test "HTML comments stay literal" {
  printf 'Intro.\n<!-- tool-marker -->\nText — here.\n' > "$BATS_TEST_TMPDIR/hc.md"
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/hc.md" "$BATS_TEST_TMPDIR/hc_out.md"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run cat "$BATS_TEST_TMPDIR/hc_out.md"
  [[ "$output" == *"<!-- tool-marker -->"* ]] || { echo "comment altered: $output"; return 1; }
}

@test "a dash at the end of a wrapped line continues the sentence, not a break-off" {
  # Found on this repo's README: "only a triggered skill's body does —" + a
  # continuation line became "does." and split the sentence.
  printf 'Only the body does —\nthe descriptions stay small.\n\nHe stopped—\n' > "$BATS_TEST_TMPDIR/wr.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/wr.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"does."* ]] || { echo "wrapped dash became a break-off: $output"; return 1; }
  [[ "$output" == *"descriptions stay small."* ]] || { echo "got: $output"; return 1; }
  [[ "$output" == *"He stopped."* ]] || { echo "real break-off lost: $output"; return 1; }
  printf 'Steps —
- first
1. second
' > "$BATS_TEST_TMPDIR/wl.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/wl.md"
  [[ "$output" == *$'\n- first\n1. second'* ]] || { echo "a list item was joined: $output"; return 1; }
}

@test "a line-end dash never joins code lines or pulls text into a heading" {
  # Found by /review: the wrapped-dash join ran before the code check, so an
  # indented code line ending in `--` swallowed the next line, and a heading
  # ending in a dash absorbed the paragraph below it.
  printf '# Title —\nBody text.\n\n    run --\n    next\n' > "$BATS_TEST_TMPDIR/wj.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/wj.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\nBody text.'* ]] || { echo "heading absorbed the paragraph: $output"; return 1; }
  [[ "$output" == *$'    run --\n    next'* ]] || { echo "code lines joined: $output"; return 1; }
}

@test "a broken sub-scorer is reported as unavailable, not silently dropped" {
  broken="$BATS_TEST_TMPDIR/broken-tk"
  cp -R "$TK" "$broken"
  printf 'print("not json")\n' > "$broken/construction_scanner.py"
  run python3 "$broken/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"construction_scanner unavailable"* ]] || { echo "no visible degradation notice: $output"; return 1; }
  [[ "$output" == *"slop_index = "* ]] || { echo "the healthy scorer's section disappeared too"; return 1; }
}

# --- /review pass on the whole branch (Codex + Claude adversarial) ------------

norm() { python3 "$TK/normalize.py" "$1" "$1.out" >/dev/null 2>&1 && cat "$1.out"; }

@test "numeric dashes inside code blocks are left alone" {
  printf 'Prose 3--64 here.\n\n    x = 3--1\n\n~~~\nSELECT 1--2\n~~~\n' > "$BATS_TEST_TMPDIR/nr.md"
  run norm "$BATS_TEST_TMPDIR/nr.md"
  [[ "$output" == *"Prose 3–64 here."* ]] || { echo "prose range not normalized: $output"; return 1; }
  [[ "$output" == *"    x = 3--1"* ]] || { echo "indented code changed: $output"; return 1; }
  [[ "$output" == *"SELECT 1--2"* ]] || { echo "tilde-fenced code changed: $output"; return 1; }
}

@test "bare URLs, reference links, emails and link destinations stay literal" {
  printf "See https://example.com/c--d now.\nMail bar--baz@example.com today.\n[a](https://example.com/a(b)--c) and [t](https://x.test/p--q 'T--t').\n\n[ref]: https://example.com/a--b \"R--r\"\n" > "$BATS_TEST_TMPDIR/ln.md"
  run norm "$BATS_TEST_TMPDIR/ln.md"
  for s in 'https://example.com/c--d' 'bar--baz@example.com' '(https://example.com/a(b)--c)' "(https://x.test/p--q 'T--t')" '[ref]: https://example.com/a--b "R--r"'; do
    [[ "$output" == *"$s"* ]] || { echo "altered: $s in: $output"; return 1; }
  done
}

@test "setext heading underlines and hard breaks survive dash replacement" {
  printf 'Heading\n--\n\nStop—  \nNew line.\nFirst line—with detail  \nSecond.\n' > "$BATS_TEST_TMPDIR/hb.md"
  run norm "$BATS_TEST_TMPDIR/hb.md"
  [[ "$output" == *$'Heading\n--'* ]] || { echo "setext underline destroyed: $output"; return 1; }
  [[ "$output" == *$'  \nNew line.'* ]] || { echo "hard break after a dash lost or joined: $output"; return 1; }
  [[ "$output" == *$'detail  \nSecond.'* ]] || { echo "hard break on a dash line lost: $output"; return 1; }
}

@test "a dash paragraph never swallows the code fence that follows it" {
  printf 'Run this —\n```\ncode\n```\n' > "$BATS_TEST_TMPDIR/fj.md"
  run norm "$BATS_TEST_TMPDIR/fj.md"
  [[ "$output" == *$'\n```\ncode\n```'* ]] || { echo "fence joined into prose: $output"; return 1; }
}

@test "a fence containing literal backticks keeps its code intact" {
  printf '```sh\nprintf "```"\ncmd --help  --verbose\n```\n' > "$BATS_TEST_TMPDIR/fb.md"
  run norm "$BATS_TEST_TMPDIR/fb.md"
  [[ "$output" == *"cmd --help  --verbose"* ]] || { echo "code altered: $output"; return 1; }
}

@test "a long run of backticks is processed in linear time" {
  python3 -c "print('\`' * 20000 + 'x')" > "$BATS_TEST_TMPDIR/bt.md"
  start=$(date +%s)
  run perl -e 'alarm 10; exec @ARGV' python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/bt.md" "$BATS_TEST_TMPDIR/bt.out"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ $(( $(date +%s) - start )) -le 3 ] || { echo "took too long"; return 1; }
}

@test "private-use characters already in the text survive untouched" {
  python3 -c "print('A 0 B  C \`x--y\` and 3--4.')" > "$BATS_TEST_TMPDIR/pu.md"
  run python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/pu.md" "$BATS_TEST_TMPDIR/pu.out"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run python3 -c "import sys; t=open(sys.argv[1]).read(); print(('0' in t, '' in t, '\`x--y\`' in t, '3–4' in t))" "$BATS_TEST_TMPDIR/pu.out"
  [ "$output" = "(True, True, True, True)" ] || { echo "got $output"; return 1; }
}

@test "--in-place writes atomically and keeps the file's permissions" {
  printf 'One — two.\n' > "$BATS_TEST_TMPDIR/ip2.md"; chmod 640 "$BATS_TEST_TMPDIR/ip2.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/ip2.md" --in-place
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run python3 "$TK/mla_format.py" "$BATS_TEST_TMPDIR/ip2.md" --in-place
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(python3 -c 'import os,stat,sys; print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode)))' "$BATS_TEST_TMPDIR/ip2.md")" = "0o640" ] || false
  [ -z "$(find "$BATS_TEST_TMPDIR" -maxdepth 1 -name '.ip2.md.*')" ] || { echo "temp file left behind"; return 1; }
}
