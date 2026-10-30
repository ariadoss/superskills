#!/usr/bin/env bats
# Tests for skills/humanize/toolkit — the packaged closure, not the upstream
# toolkit it was copied from. These are packaging tests: the scripts are only
# useful if every data file they load travelled with them, and two of the
# failure modes are silent (a missing phrase-probability table makes the legacy
# index read 0.0 rather than "unavailable"), so they are asserted explicitly.

setup() {
  # Package-mode imports (unlike file-path runs) would write __pycache__/ into
  # the toolkit directory, which is the tree the export publishes.
  export PYTHONDONTWRITEBYTECODE=1
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

@test "rhetorical scaffolding reports scene openers, announced questions and filler" {
  cat > "$SAMPLE" <<'COPY'
Imagine this: your report is finished.

The practical test: can the reader repeat the calculation?

Here's the thing: we already collected the data.
COPY
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RHETORICAL SCAFFOLDING (review, not authorship): 3"* ]] || false
  [[ "$output" == *"L1:"* && "$output" == *"L3:"* && "$output" == *"L5:"* ]] || false
}

@test "rhetorical checks preserve literal language, technical scenarios and direct questions" {
  cat > "$SAMPLE" <<'COPY'
Imagine two requests arriving at the same time.

I can't imagine this working without a backup.

The practical test starts at nine.

Here's the thing I ordered.

Let's be honest with the customer about the delay.

Can both requests safely update the same record?
COPY
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RHETORICAL SCAFFOLDING (review, not authorship): none"* ]] || false
}

@test "rhetorical checks ignore quoted words, literals and code but keep line numbers" {
  cat > "$SAMPLE" <<'COPY'
"Imagine this: a new report," said Jo.

> Here's the thing: keep the receipt.

```text
The practical test: can it restart?
```

    Imagine this: a new report.

<!--
Imagine this: a new report.
-->

The string is `Here's the thing: a new report`.

Read [the guide](https://example.org "Imagine this: a new report").

Imagine this: a new report.
COPY
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RHETORICAL SCAFFOLDING (review, not authorship): 1"* ]] || false
  [[ "$output" == *"L19: [Imagine this:]"* ]] || false
}

@test "rhetorical checks handle emphasis, list items, curly apostrophes and soft wraps" {
  cat > "$SAMPLE" <<'COPY'
**Imagine this:** your report is ready.

- Here’s the thing: the data already exists.

The practical test:
Can the reader reproduce the result?
COPY
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RHETORICAL SCAFFOLDING (review, not authorship): 3"* ]] || false
  [[ "$output" == *"L5: [The practical test:"* ]] || false
}

@test "a wrapped phrase mid-sentence is not a rhetorical opener" {
  printf 'The engineer could not\nimagine this: two workers charging the same card.\n' > "$SAMPLE"
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RHETORICAL SCAFFOLDING (review, not authorship): none"* ]] || false
}

@test "construction review is read-only and does not change the lexical score" {
  printf 'Imagine this: your report is ready.\n' > "$SAMPLE"
  cp "$SAMPLE" "$BATS_TEST_TMPDIR/original.md"
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RHETORICAL SCAFFOLDING (review, not authorship): 1"* ]] || false
  [[ "$output" == *"slop_index = 0.0  [word 0, bigram 0, trigram 0]"* ]] || false
  cmp "$SAMPLE" "$BATS_TEST_TMPDIR/original.md"
}

@test "rhetorical checks accept literal-only and empty files without a final newline" {
  for content in '`Imagine this: a report`' '<!-- Imagine this: a report -->' ''; do
    printf '%s' "$content" > "$SAMPLE"
    run python3 "$TK/slop_report.py" "$SAMPLE"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"RHETORICAL SCAFFOLDING (review, not authorship): none"* ]] || false
  done
}

@test "rhetorical checks protect wrapped quotations and contractions in dialogue" {
  cat > "$SAMPLE" <<'COPY'
Jo wrote, "The report is ready.
Imagine this: every invoice is paid."

'Here's the thing. Imagine this: a report,' she said.

‘Here’s the thing. Imagine this: a report,’ she said.

Jo wrote, “The report is ready.
The practical test: can I open it?”

Imagine this: the next report is ready.
COPY
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RHETORICAL SCAFFOLDING (review, not authorship): 1"* ]] || false
  [[ "$output" == *"L11: [Imagine this:]"* ]] || false
}

@test "rhetorical checks protect lazy blockquotes but release following paragraphs and lists" {
  cat > "$SAMPLE" <<'COPY'
> First the customer writes.
Then she adds. Imagine this: every invoice is paid.

Imagine this: your own report is ready.

> The customer finished.
- Here's the thing: the next report is late.

> Another quote.
>
Picture this: the invoice is missing.
COPY
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RHETORICAL SCAFFOLDING (review, not authorship): 3"* ]] || false
  [[ "$output" == *"L4: [Imagine this:]"* ]] || false
  [[ "$output" == *"L7: [Here's the thing:]"* ]] || false
  [[ "$output" == *"L11: [Picture this:]"* ]] || false
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

@test "reviewed vocabulary is excluded from the gate score as well as the findings" {
  printf 'The Incantation Lab opens at noon.\n' > "$BATS_TEST_TMPDIR/product.txt"
  printf 'incantation\n' > "$BATS_TEST_TMPDIR/terms.txt"
  run python3 "$TK/slop_report.py" "$BATS_TEST_TMPDIR/product.txt" --exempt "$BATS_TEST_TMPDIR/terms.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"EQ-BENCH SLOP WORDS: none"* ]] || false
  [[ "$output" == *"slop_index = 0.0  [word 0, bigram 0, trigram 0]"* ]] || false
}

@test "exempt score keeps word counts and does not join neighboring phrase tokens" {
  run python3 -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import eq_bench_slop_index as e; e.tokenize = lambda text: text.lower().split(); e.load_slop_set = lambda path: {"incantation"} if path == e.SLOP_UNIGRAMS else {"deep breath"}; r = e.slop_index_new("deep incantation breath", exempt={"incantation"}); assert r["slop_index"] == 0 and r["total_words"] == 3, r; assert e.slop_index_new("incantation")["word_hits"] == 1' "$TK"
  [ "$status" -eq 0 ]
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
    | grep -vE '^(import|from) (re|sys|json|statistics|subprocess|math|os|argparse|collections|pathlib|__future__|typing|unicodedata|itertools|functools|textwrap|string|tempfile|shutil|bisect|html|mla_format|textio|emdash_fix|eq_bench_slop_index)([. ]|$)' \
    | grep -vE '^from \.')"
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

@test "--tighten keeps a hard break that follows a line-end dash" {
  printf 'Ends on a dash —  \nNext line.\n' > "$BATS_TEST_TMPDIR/tb.md"
  run python3 "$TK/emdash_fix.py" "$BATS_TEST_TMPDIR/tb.md" --tighten
  [[ "$output" == *$'dash—  \nNext line.'* ]] || { echo "hard break lost: $(printf '%s' "$output" | od -c | head -3)"; return 1; }
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

@test "literals that contain inline code, escapes or nesting stay literal" {
  # Inline code used to be masked before comments and link titles, so its backticks
  # split them; an escaped backtick opened a span; a fence closed on a line with
  # trailing text; an indented line inside a paragraph was taken for code.
  printf '%s\n' \
    '<!-- `x` -- comment -->' \
    '' \
    '[x](a--b "use `x` -- here")' \
    '' \
    'a `first' \
    '    middle' \
    'last -- code`' \
    '' \
    '\` outside `inside -- unchanged`' \
    '' \
    '~~~' \
    '~~~not-a-close' \
    'run --help  now' \
    '~~~' \
    '' \
    '[y](a(b(c))--d)' \
    '' \
    '[z]:' \
    '  /a--b "title"' > "$BATS_TEST_TMPDIR/lit.md"
  run norm "$BATS_TEST_TMPDIR/lit.md"
  [ "$output" = "$(cat "$BATS_TEST_TMPDIR/lit.md")" ] || { diff <(printf '%s\n' "$output") "$BATS_TEST_TMPDIR/lit.md"; return 1; }
}

@test "a placeholder character inside a literal round-trips" {
  printf 'Code `\356\200\200` and <!-- \356\200\220 --> end.\n' > "$BATS_TEST_TMPDIR/ph.md"
  run norm "$BATS_TEST_TMPDIR/ph.md"
  [ "$output" = "$(cat "$BATS_TEST_TMPDIR/ph.md")" ] || { echo "got: $output"; return 1; }
}

@test "a long run of word characters is masked in linear time" {
  python3 -c 'print("a" * 64000)' > "$BATS_TEST_TMPDIR/aa.md"
  run perl -e 'alarm 10; exec @ARGV' python3 "$TK/normalize.py" "$BATS_TEST_TMPDIR/aa.md" "$BATS_TEST_TMPDIR/aa.out"
  [ "$status" -eq 0 ] || { echo "timed out or failed: $status"; return 1; }
}

@test "malformed bundled word lists fall back instead of crashing the scan" {
  cp -R "$TK" "$BATS_TEST_TMPDIR/tk"
  printf '{"marketing_workslop": null}' > "$BATS_TEST_TMPDIR/tk/ai_slop_wordlist.json"
  printf '{"words": [{}]}' > "$BATS_TEST_TMPDIR/tk/ai_overused_research.json"
  printf 'We leverage synergy to delve into it.\n' > "$BATS_TEST_TMPDIR/m.md"
  run python3 "$BATS_TEST_TMPDIR/tk/slop_report.py" "$BATS_TEST_TMPDIR/m.md"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"leverage"* ]] || { echo "fallback list not used: $output"; return 1; }
}

@test "a line-end dash never pulls a comment, URL or link definition onto its line" {
  for lit in '<!-- note -->' 'https://example.com/path' '[ref]: http://example.com "t"'; do
    printf 'clause wraps —\n%s\nmore text\n' "$lit" > "$BATS_TEST_TMPDIR/jl.md"
    run norm "$BATS_TEST_TMPDIR/jl.md"
    [[ "$output" == *$'\n'"$lit"$'\nmore text'* ]] || { echo "joined into $lit: $output"; return 1; }
  done
}

@test "an HTML comment left open keeps its text literal to the end" {
  printf 'before — text\n<!-- never closed — with dash\nmore — here\n' > "$BATS_TEST_TMPDIR/oc.md"
  run norm "$BATS_TEST_TMPDIR/oc.md"
  [[ "$output" == *$'\n<!-- never closed — with dash\nmore — here'* ]] || { echo "$output"; return 1; }
}

@test "a bare URL ends before trailing punctuation, so the prose after it is still fixed" {
  # The URL pattern ran on through `)--it`, so the glued double hyphen was held
  # as part of the URL and never became a dash.
  printf 'Read (https://x.com/a)--it helps.\n' > "$BATS_TEST_TMPDIR/up.md"
  run python3 "$TK/mla_format.py" "$BATS_TEST_TMPDIR/up.md"
  [ "$output" = "Read (https://x.com/a)—it helps." ] || { echo "$output"; return 1; }
}

@test "every line of a multi-line indented code block stays code" {
  printf 'Intro.\n\n    first --flag\n    second --flag\n\nAfter.\n' > "$BATS_TEST_TMPDIR/ib.md"
  run norm "$BATS_TEST_TMPDIR/ib.md"
  [[ "$output" == *$'    first --flag\n    second --flag'* ]] || { echo "$output"; return 1; }
}

@test "an escaped backslash before a backtick still opens inline code" {
  # Two backslashes are one literal backslash, so the backtick after them is live.
  printf 'Path \\\\`a -- b` end.\n' > "$BATS_TEST_TMPDIR/eb.md"
  run norm "$BATS_TEST_TMPDIR/eb.md"
  [[ "$output" == *'`a -- b`'* ]] || { echo "code span edited: $output"; return 1; }
}

@test "an indented line continuing a list item is prose, not code" {
  printf -- '- item text\n    carries on -- here\n' > "$BATS_TEST_TMPDIR/lc.md"
  run python3 "$TK/mla_format.py" "$BATS_TEST_TMPDIR/lc.md"
  [[ "$output" == *"    carries on—here"* ]] || { echo "$output"; return 1; }
}

# ---- userfacing.py: which files are user-facing copy, and what text in them is ----

uf() { python3 "$TK/userfacing.py" "$@"; }

@test "userfacing: classifies docs, marketing copy, locale strings and UI components as in scope" {
  for pair in README.md:markdown docs/guide.mdx:markdown content/blog/post.md:markdown \
              site/landing.html:html pages/pricing.txt:text locales/en.json:locale \
              src/i18n/en.yaml:locale src/Hero.tsx:source components/Card.vue:source; do
    path="${pair%%:*}"; want="${pair##*:}"
    run uf classify "$path"
    [ "$status" -eq 0 ]
    [ "$output" = "$want" ] || { echo "$path -> $output (want $want)"; return 1; }
  done
}

@test "userfacing: code, prompts, agent instructions, plans, tests and vendored trees are out of scope" {
  for path in package.json tsconfig.json src/util.ts src/main.py app/server.go Cargo.toml go.sum \
              prompts/system.md evals/case/prompt.md skills/x/SKILL.md CLAUDE.md AGENTS.md \
              tests/fixtures/a.md node_modules/pkg/README.md vendor/lib/README.md target/doc/index.html \
              dist/index.html static/app.min.js .humanize-exempt.txt pkg/server_test.go web/app.spec.ts; do
    run uf classify "$path"
    [ "$status" -eq 0 ]
    [ "$output" = "none" ] || { echo "$path -> $output (want none)"; return 1; }
  done
}

@test "userfacing: markdown extraction drops code blocks, inline code, link targets and front matter, keeping line numbers" {
  cd "$BATS_TEST_TMPDIR"; f="doc.md"
  printf '%s\n' '---' 'layout: post' '---' 'Intro with `code()` and [a link](https://example.com/x).' '' '```sh' 'rm -rf delve' '```' 'Last prose line.' > "$f"
  run uf extract "$f"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 9 ]
  [ "$(printf '%s\n' "$output" | sed -n 4p)" = "Intro with  and [a link]." ]
  [ -z "$(printf '%s\n' "$output" | sed -n 7p)" ]
  [ "$(printf '%s\n' "$output" | sed -n 9p)" = "Last prose line." ]
  [ -z "$(printf '%s\n' "$output" | sed -n 2p)" ]
}

@test "userfacing: html extraction keeps visible text and alt/placeholder, drops script, style, code, comments" {
  cd "$BATS_TEST_TMPDIR"; f="p.html"
  cat > "$f" <<'HTML'
<html><head><style>.a { color: red }</style><script>var x = "delve into it";</script></head>
<body>
<!-- delve internal comment -->
<h1>Ship faster</h1>
<p>Our tapestry of features
 helps teams.</p>
<img src="a.png" alt="A tidy dashboard overview">
<pre><code>delve --deep</code></pre>
</body></html>
HTML
  run uf extract "$f"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q "Ship faster"
  printf '%s\n' "$output" | grep -q "tapestry of features"
  printf '%s\n' "$output" | grep -q "A tidy dashboard overview"
  ! printf '%s\n' "$output" | grep -q "delve" || false
  ! printf '%s\n' "$output" | grep -q "color: red" || false
  # the h1 stays on its own source line (line 4)
  [ "$(printf '%s\n' "$output" | sed -n 4p)" = "Ship faster" ]
}

@test "userfacing: locale json keeps string values only" {
  cd "$BATS_TEST_TMPDIR"; d="locales"; mkdir -p "$d"
  printf '%s\n' '{' '  "hero.title": "Unlock your potential today",' '  "count": 3,' '  "nested": {' '    "cta": "Start your free trial now"' '  }' '}' > "$d/en.json"
  run uf extract "$d/en.json"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q "Unlock your potential today"
  printf '%s\n' "$output" | grep -q "Start your free trial now"
  ! printf '%s\n' "$output" | grep -q "hero.title" || false
  ! printf '%s\n' "$output" | grep -q "^3" || false
}

@test "userfacing: component source keeps JSX text and sentence-like literals, drops comments, classes, logs and imports" {
  cd "$BATS_TEST_TMPDIR"; f="Hero.tsx"
  cat > "$f" <<'TSX'
import { Button } from "./components/button-with-a-long-name";
// delve into the tapestry of this comment here please
/* a block comment mentioning the rich tapestry of things */
export function Hero() {
  console.log("Rendering the hero section now for debugging");
  return (
    <div className="flex items-center justify-between px-4 py-2">
      <h1>Build your site in minutes</h1>
      <Button label="Start your free trial today" />
      <p>{t("short")}</p>
    </div>
  );
}
TSX
  run uf extract "$f"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q "Build your site in minutes"
  printf '%s\n' "$output" | grep -q "Start your free trial today"
  ! printf '%s\n' "$output" | grep -qi "tapestry" || false
  ! printf '%s\n' "$output" | grep -q "flex items-center" || false
  ! printf '%s\n' "$output" | grep -q "Rendering the hero" || false
  ! printf '%s\n' "$output" | grep -q "button-with-a-long-name" || false
}

@test "userfacing: extract on an out-of-scope file exits 1 with no output" {
  cd "$BATS_TEST_TMPDIR"; f="util.ts"; printf 'const a = "one two three four five";\n' > "$f"
  run uf extract "$f"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "userfacing: READMEs and markdown docs are always user-facing, even under test or plan folders" {
  for path in README.md tests/README.md evals/README.md docs/plans/q3.md docs/internal/arch.md \
              NOTES.md TODO.md CHANGELOG.md CONTRIBUTING.md _posts/2026-01-01-hello.md; do
    run uf classify "$path"
    [ "$output" = "markdown" ] || { echo "$path -> $output"; return 1; }
  done
  run uf classify node_modules/pkg/README.md
  [ "$output" = "none" ]
}

@test "userfacing: template engines of every ecosystem classify as template" {
  for path in resources/views/home.blade.php templates/base.twig app/views/home.html.erb \
              layouts/index.gohtml emails/welcome.njk themes/x/sections/hero.liquid views/page.hbs \
              templates/index.jinja2 views/page.ejs web/index.tmpl; do
    run uf classify "$path"
    [ "$output" = "template" ] || { echo "$path -> $output"; return 1; }
  done
}

@test "userfacing: front matter keeps copy fields (title, description) and blanks the rest" {
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' '---' 'layout: post' 'title: "Why we rewrote our billing engine"' 'tags: [a, b]' 'description: How we cut invoice errors in half.' '---' 'Body text here.' > post.md
  run uf extract post.md
  [ "$(printf '%s\n' "$output" | sed -n 3p)" = "Why we rewrote our billing engine" ]
  [ "$(printf '%s\n' "$output" | sed -n 5p)" = "How we cut invoice errors in half." ]
  [ -z "$(printf '%s\n' "$output" | sed -n 2p)" ]
  [ -z "$(printf '%s\n' "$output" | sed -n 4p)" ]
  printf '%s\n' '+++' 'title = "Launch week recap"' 'weight = 3' '+++' 'Hugo body.' > hugo.md
  run uf extract hugo.md
  [ "$(printf '%s\n' "$output" | sed -n 2p)" = "Launch week recap" ]
  [ -z "$(printf '%s\n' "$output" | sed -n 3p)" ]
}

@test "userfacing: template extraction blanks tags and comments but keeps text and translated strings" {
  cd "$BATS_TEST_TMPDIR"
  cat > home.blade.php <<'T'
@extends('layouts.app')
{{-- delve internal note about the layout --}}
<h1>{{ __('Welcome back to your dashboard') }}</h1>
@if($user->isAdmin())
<p>Manage your team and billing in one place.</p>
@endif
{% comment %} a tapestry of notes {% endcomment %}
<p class="x">{{ $user->name }}</p>
T
  run uf extract home.blade.php
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q "Welcome back to your dashboard"
  printf '%s\n' "$output" | grep -q "Manage your team and billing in one place."
  ! printf '%s\n' "$output" | grep -qi "tapestry\|delve\|isAdmin\|user->name" || false
  [ "$(printf '%s\n' "$output" | sed -n 3p)" = "Welcome back to your dashboard" ]
  [ "$(printf '%s\n' "$output" | sed -n 5p)" = "Manage your team and billing in one place." ]
}

@test "userfacing: php keeps html outside the tags and echoed copy, drops comments and error logs" {
  cd "$BATS_TEST_TMPDIR"; mkdir -p site
  cat > site/index.php <<'T'
<?php
// delve into the tapestry of this internal comment
$title = "Home";
error_log("Something went wrong while saving the data");
echo "<p>Welcome to our fast and simple platform.</p>";
?>
<section><h2>Pricing that scales with you</h2></section>
T
  run uf classify site/index.php
  [ "$output" = "source" ]
  run uf extract site/index.php
  printf '%s\n' "$output" | grep -q "Welcome to our fast and simple platform."
  printf '%s\n' "$output" | grep -q "Pricing that scales with you"
  ! printf '%s\n' "$output" | grep -qi "tapestry\|Something went wrong" || false
}

@test "userfacing: generator code in go, rust, python and node keeps rendered copy only" {
  cd "$BATS_TEST_TMPDIR"; mkdir -p gen
  cat > gen/main.go <<'T'
package main

// delve comment about the tapestry
func main() {
	log.Printf("Starting the static site generator now")
	page := `<html><body><h1>Documentation for the whole team</h1></body></html>`
	os.WriteFile("out/index.html", []byte(page), 0644)
}
T
  cat > gen/build.rs <<'T'
/// delve doc comment about the tapestry
fn main() {
    println!("Building the site for production use");
    let page = r#"<h1>Guides and tutorials for everyone</h1>"#;
    std::fs::write("out/index.html", page).unwrap();
}
T
  cat > gen/build.py <<'T'
"""Docstring about the tapestry of the build."""
import sys

# delve comment
def build():
    print("Writing the pages to disk right now")
    with open("out/index.html", "w") as f:
        f.write("<p>Our team ships quickly and reliably.</p>")
T
  cat > gen/server.js <<'T'
// delve comment tapestry
app.get("/", (req, res) => {
  console.log("Server is handling the home request now");
  res.send("<h1>Welcome to the status dashboard</h1>");
});
T
  for f in gen/main.go:"Documentation for the whole team" gen/build.rs:"Guides and tutorials for everyone" \
           gen/build.py:"Our team ships quickly and reliably." gen/server.js:"Welcome to the status dashboard"; do
    path="${f%%:*}"; want="${f#*:}"
    run uf classify "$path"
    [ "$output" = "source" ] || { echo "$path classify -> $output"; return 1; }
    run uf extract "$path"
    printf '%s\n' "$output" | grep -q "$want" || { echo "$path missing: $want"; return 1; }
    ! printf '%s\n' "$output" | grep -qi "tapestry\|Starting the\|Building the\|Writing the pages\|handling the home" || { echo "$path leaked"; return 1; }
  done
}

@test "userfacing: code without any output signal stays out of scope even with sentence-like strings" {
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' 'package util' 'var Default = "This is a fairly long default configuration value."' > util.go
  run uf classify util.go
  [ "$output" = "none" ]
}

@test "userfacing: gettext po, properties and strings files keep message text only" {
  cd "$BATS_TEST_TMPDIR"; mkdir -p locales
  printf '%s\n' '# translator note delve' 'msgid "Save your changes before leaving"' 'msgstr "Guarde sus cambios antes de salir"' > locales/app.po
  run uf extract locales/app.po
  printf '%s\n' "$output" | grep -q "Save your changes before leaving"
  ! printf '%s\n' "$output" | grep -q "translator note" || false
  printf '%s\n' '# comment' 'hero.title=Ship your product faster than ever' 'count=3' > locales/messages.properties
  run uf extract locales/messages.properties
  printf '%s\n' "$output" | grep -q "Ship your product faster than ever"
  ! printf '%s\n' "$output" | grep -q "hero.title" || false
}

@test "userfacing: liquid style/schema blocks and code templates (.js.erb) are not copy" {
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' '{% style %}' '.section { padding: 4px; }' '{% endstyle %}' '<h2>Gentle on your skin</h2>' '{% schema %}' '{"name": "Hero banner"}' '{% endschema %}' > hero.liquid
  run uf extract hero.liquid
  printf '%s\n' "$output" | grep -q "Gentle on your skin"
  ! printf '%s\n' "$output" | grep -q "padding\|Hero banner" || false
  run uf classify app/views/tags/show.js.erb
  [ "$output" = "none" ]
  run uf classify app/views/tags/show.html.erb
  [ "$output" = "template" ]
}

@test "userfacing: python module docstrings after a shebang and sql fragments are not copy" {
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' '#!/usr/bin/env python3' '"""Comprehensive performance analysis and optimization tool."""' 'import sys' 'q = "ORDER BY j.title ASC LIMIT 10"' 'open("out/a.html", "w").write("<p>Hello and welcome to the docs.</p>")' > tool.py
  run uf extract tool.py
  printf '%s\n' "$output" | grep -q "Hello and welcome to the docs."
  ! printf '%s\n' "$output" | grep -q "Comprehensive\|ORDER BY" || false
}

@test "userfacing: unterminated template openers cannot stall extraction" {
  cd "$BATS_TEST_TMPDIR"
  python3 -c "print('{{ x\n' * 20000, end='')" > many.liquid
  python3 -c "print('{%- comment %}\n' * 20000, end='')" > many2.liquid
  run timeout 10 python3 "$TK/userfacing.py" extract many.liquid
  [ "$status" -eq 0 ]
  run timeout 10 python3 "$TK/userfacing.py" extract many2.liquid
  [ "$status" -eq 0 ]
}

@test "userfacing: oversized files and symlinks are never scanned" {
  cd "$BATS_TEST_TMPDIR"
  head -c 700000 /dev/zero | tr '\0' 'a' > big.md
  run uf classify big.md
  [ "$output" = "none" ]
  printf 'Real prose lives here.\n' > real.md
  ln -s real.md link.md
  run uf classify link.md
  [ "$output" = "none" ]
  run uf extract link.md
  [ "$status" -eq 1 ]
}

@test "userfacing: prompts inside code and a stray 'echo' do not make a code file copy" {
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' '# we echo the results to the console' 'SYSTEM_PROMPT = "You are a helpful assistant that rewrites documentation."' 'def f():' '    return 1' > cli.py
  run uf classify cli.py
  [ "$output" = "none" ]
  printf '%s\n' 'SYSTEM_PROMPT = "You are a helpful assistant that rewrites documentation."' 'open("out/a.html", "w").write("<p>Welcome to our documentation for everyone.</p>")' > gen.py
  run uf extract gen.py
  printf '%s\n' "$output" | grep -q "Welcome to our documentation for everyone."
  ! printf '%s\n' "$output" | grep -q "helpful assistant" || false
}

@test "userfacing: generated report trees, license boilerplate and prompt-named guides are classified correctly" {
  for path in htmlcov/index.html storybook-static/index.html playwright-report/index.html LICENSE.txt NOTICE.md COPYING; do
    run uf classify "$path"
    [ "$output" = "none" ] || { echo "$path -> $output (want none)"; return 1; }
  done
  for path in prompting-guide.md how-to-write-a-good-prompt.md docs/commands/install.md docs/specs/overview.md; do
    run uf classify "$path"
    [ "$output" = "markdown" ] || { echo "$path -> $output (want markdown)"; return 1; }
  done
  run uf classify prompts/system.md
  [ "$output" = "none" ]
  run uf classify prompt.md
  [ "$output" = "none" ]
}

@test "userfacing: 'echo' counts only in PHP, and an html tag in a comment is not an output signal" {
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' 'import sys' 'label = "please echo this back to the caller"' 'print(label)' > echo.py
  run uf classify echo.py
  [ "$output" = "none" ]
  printf '%s\n' '// render <p>Hello there</p> later' 'package main' 'var X = 1' > c.go
  run uf classify c.go
  [ "$output" = "none" ]
  printf '%s\n' '<?php' 'echo "<p>Welcome to our fast and simple platform.</p>";' > e.php
  run uf classify e.php
  [ "$output" = "source" ]
}

@test "userfacing: a single very long line of strings cannot stall the scanner" {
  cd "$BATS_TEST_TMPDIR"
  python3 -c "print('res.send(1);' + 'var a=\"x y\";' * 30000)" > long.js
  run timeout 20 python3 "$TK/userfacing.py" extract long.js
  [ "$status" -eq 0 ]
}

@test "userfacing: a parenthesised multi-line prompt and a role/system message are not copy" {
  cd "$BATS_TEST_TMPDIR"
  cat > p.py <<'PY'
SYSTEM_PROMPT = (
    "You are a helpful assistant that always answers questions politely."
)
msgs = [{"role": "system", "content": "You are a careful reviewer who explains every change."}]
open("out/a.html", "w").write("<p>Welcome to our documentation for everyone.</p>")
PY
  run uf extract p.py
  printf '%s\n' "$output" | grep -q "Welcome to our documentation for everyone."
  ! printf '%s\n' "$output" | grep -q "helpful assistant\|careful reviewer" || false
}

@test "userfacing: agent handoff and resume notes are records, not copy; a handoff guide is" {
  for path in handoff-20261013T010203Z-4242.md handoff-844e2be8-cfed-4b7c-9b9f-34508a76af88.md QUOTA-RESUME.md; do
    run uf classify "$path"
    [ "$output" = "none" ] || { echo "$path -> $output"; return 1; }
  done
  run uf classify docs/handoff-guide.md
  [ "$output" = "markdown" ]
}

@test "userfacing: gettext continuation lines and plural forms are copy, the empty header is not" {
  cd "$BATS_TEST_TMPDIR"; mkdir -p locales
  cat > locales/app.po <<'PO'
msgid ""
msgstr ""
"Project-Id-Version: demo\n"

msgid ""
"Save your work before you leave "
"this page."
msgstr[0] "Guarde su trabajo antes de salir de esta pagina."
PO
  run uf extract locales/app.po
  printf '%s\n' "$output" | grep -q "Save your work before you leave"
  printf '%s\n' "$output" | grep -q "this page."
  printf '%s\n' "$output" | grep -q "Guarde su trabajo"
}

@test "userfacing: yaml, ios strings and arb locale values are copy; numbers, booleans and keys are not" {
  cd "$BATS_TEST_TMPDIR"; mkdir -p config/locales i18n
  printf '%s\n' 'en:' '  hero:' '    title: Ship your product faster than ever' '    count: 42' '    on: true' '    cta: "Start your free trial today"' > config/locales/en.yml
  run uf extract config/locales/en.yml
  printf '%s\n' "$output" | grep -q "Ship your product faster than ever"
  printf '%s\n' "$output" | grep -q "Start your free trial today"
  ! printf '%s\n' "$output" | grep -qx "42\|true\|hero\|title" || false
  printf '%s\n' '/* note */' '"welcome" = "Welcome back to your dashboard";' > i18n/Localizable.strings
  run uf extract i18n/Localizable.strings
  printf '%s\n' "$output" | grep -q "Welcome back to your dashboard"
  ! printf '%s\n' "$output" | grep -q "welcome\b" || false
  printf '%s\n' '{' '  "@@locale": "en",' '  "greeting": "Hello and welcome to the app"' '}' > i18n/app_en.arb
  run uf extract i18n/app_en.arb
  printf '%s\n' "$output" | grep -q "Hello and welcome to the app"
}

@test "userfacing: locale-named json outside a locale folder is copy; package.json is not" {
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' '{' '  "title": "Build the future with us today"' '}' > en.json
  run uf classify en.json
  [ "$output" = "locale" ]
  run uf classify messages.fr.json
  [ "$output" = "locale" ]
  run uf classify package.json
  [ "$output" = "none" ]
}

@test "userfacing: rust raw strings, php heredocs and ruby heredocs yield copy; their comments do not" {
  cd "$BATS_TEST_TMPDIR"
  cat > r.rs <<'RS'
// delve into the tapestry of generated pages here
fn main() {
    let page = r##"<p>Our docs cover every step of the setup.</p>"##;
    std::fs::write("out.html", page).unwrap();
}
RS
  run uf extract r.rs
  printf '%s\n' "$output" | grep -q "Our docs cover every step of the setup."
  ! printf '%s\n' "$output" | grep -qi "tapestry" || false
  cat > h.php <<'PHP'
<?php
// delve tapestry comment
$html = <<<HTML
<h1>Pricing that stays simple as you grow</h1>
HTML;
echo $html;
PHP
  run uf extract h.php
  printf '%s\n' "$output" | grep -q "Pricing that stays simple as you grow"
  ! printf '%s\n' "$output" | grep -qi "tapestry" || false
  cat > h.rb <<'RB'
# delve tapestry comment
html = <<~HTML
  <p>Every plan includes unlimited projects and users.</p>
HTML
File.write("out.html", html)
RB
  run uf extract h.rb
  printf '%s\n' "$output" | grep -q "Every plan includes unlimited projects and users."
  ! printf '%s\n' "$output" | grep -qi "tapestry" || false
}

@test "userfacing: svelte braces, astro frontmatter and a bare multi-line jsx text node" {
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' '<script>let name = "delve into tapestry";</script>' '<h1>Hello {name}, welcome to the studio</h1>' '{#if open}' '<p>The studio is open every day.</p>' '{/if}' > a.svelte
  run uf extract a.svelte
  printf '%s\n' "$output" | grep -q "welcome to the studio"
  printf '%s\n' "$output" | grep -q "The studio is open every day."
  ! printf '%s\n' "$output" | grep -qi "tapestry\|name}" || false
  printf '%s\n' '---' 'const t = "delve into tapestry";' '---' '<h2>Built for teams that ship every week</h2>' > a.astro
  run uf extract a.astro
  printf '%s\n' "$output" | grep -q "Built for teams that ship every week"
  ! printf '%s\n' "$output" | grep -qi "tapestry" || false
  cat > m.tsx <<'TSX'
export const A = () => (
  <section>
    <p>
      Teams that plan together ship together every single week.
    </p>
  </section>
);
TSX
  run uf extract m.tsx
  printf '%s\n' "$output" | grep -q "Teams that plan together ship together every single week."
}

@test "userfacing: mdx imports and html comments are dropped, rst text keeps prose" {
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' "import Chart from './chart'" '<!-- delve internal note -->' 'The chart below shows weekly active teams.' > d.mdx
  run uf extract d.mdx
  printf '%s\n' "$output" | grep -q "weekly active teams"
  ! printf '%s\n' "$output" | grep -qi "delve\|import Chart" || false
  printf '%s\n' 'Usage' '=====' 'Run the installer and follow the prompts.' > u.rst
  run uf classify u.rst
  [ "$output" = "text" ]
  run uf extract u.rst
  printf '%s\n' "$output" | grep -q "Run the installer and follow the prompts."
}

@test "userfacing: absolute paths are judged by their place inside the repo, not by ancestors" {
  d="$BATS_TEST_TMPDIR/build/test/proj"; mkdir -p "$d/docs"
  git -C "$d" init -q
  printf 'Plain prose lives in this guide for readers.\n' > "$d/docs/guide.md"
  run uf classify "$d/docs/guide.md"
  [ "$output" = "markdown" ]
  mkdir -p "$d/node_modules/pkg"; printf 'x\n' > "$d/node_modules/pkg/README.md"
  run uf classify "$d/node_modules/pkg/README.md"
  [ "$output" = "none" ]
}

@test "userfacing: test and generated code names are out even when they render html" {
  for path in pkg/render_test.go web/page.spec.ts app/test_views.py types/api.d.ts \
              vite.config.ts proto/service.pb.go src/Widget.generated.tsx; do
    run uf classify "$path"
    [ "$output" = "none" ] || { echo "$path -> $output"; return 1; }
  done
}

@test "editorial patterns: stock openers closers contrasts and chat wrappers are review signals" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import editorial_patterns
examples = [
    "Let's dive in. The file is ready.",
    "Let's break this down: the file is ready.",
    "Here's what you need to know: the file is ready.",
    "Without further ado, the file is ready.",
    "The thing is: the file is ready.",
    "Real talk: the file is ready.",
    "Honestly? The file is ready.",
    "The file is ready. Read that again.",
    "That is the real win.",
    "That's why it matters.",
    "That distinction matters.",
    "It is not just storage, but a searchable archive.",
    "The archive holds not only receipts but also attachments.",
    "I wanted not a pardon but an answer.",
    "This isn't about storage. It's about finding receipts.",
    "It's not filing. It's finding.",
    "It is not storage; it is retrieval.",
    "Great question! The file is ready.",
    "Certainly! The file is ready.",
    "I hope this helps!",
    "Would you like me to expand on this?",
    "Want me to continue?",
    "Should I continue?",
    "As an AI language model, I cannot inspect the file.",
]
for text in examples:
    assert editorial_patterns(text), text
PY
}

@test "editorial patterns: near misses and useful ordinary language are not blanket banned" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import editorial_patterns
examples = [
    "Imagine two workers reading the queue.",
    "I answered honestly and put the letter away.",
    "Read the message again if the code is missing.",
    "The backup is not complete.",
    "The backup is complete, but the index is missing.",
    "As of 2026, the archive holds 128 files.",
    "The cause of the missing attachment is not known.",
    "The service includes invoices, receipts, and attachments.",
    "She came. She saw. She conquered.",
    "Here is a copper key.",
    "I hope this helps us find the missing key.",
    "The thing is missing from the drawer.",
    "The expression without further ado appears in the essay.",
]
for text in examples:
    assert not editorial_patterns(text), text
PY
}

@test "editorial patterns: quoted words Markdown literals and source line numbers survive" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import editorial_patterns
text = '''"Great question!\nI hope this helps!"

'Let's break this down: I kept the ticket.'

> Read that again.
Certainly! I kept the ticket.

```text
The thing is: keep the ticket.
```

`Would you like me to continue?`
<!-- Great question! -->
[link](https://example.test/Great-question)

Great question! The gate opens at six.
'''
hits = editorial_patterns(text)
assert [(line, phrase) for line, phrase, _ in hits] == [(17, 'Great question!')], hits
PY
}

@test "editorial patterns: sentence paragraph and list boundaries include soft wraps" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import editorial_patterns
text = "A plain sentence. **Great question!**\n\n- Here’s what you need\nto know: the gate opens.\n\nThis isn’t about speed.\nIt’s about trust."
hits = editorial_patterns(text)
assert [h[0] for h in hits] == [1, 3, 6], hits
assert not editorial_patterns('I used the phrase\ngreat question! when I wrote to her.')
assert not editorial_patterns('This is not about speed.\n\nIt is about trust.')
assert not editorial_patterns('The backup is not complete. It failed, but a copy remains.')
assert not editorial_patterns('Not only one room. Another room has a bell, but no key.')
PY
}

@test "editorial patterns: empty and literal-only files are safe" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import editorial_patterns
for text in ['', '`Great question!`', '<!-- Great question! -->', '"Great question!"', '> Great question!']:
    assert not editorial_patterns(text), text
PY
}

@test "editorial patterns: CLI reports findings without rewriting or changing lexical scores" {
  printf 'Great question! The file is ready.\n' > "$SAMPLE"
  cp "$SAMPLE" "$BATS_TEST_TMPDIR/original.md"
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"EDITORIAL PATTERNS (review context; never auto-delete): 1"* ]] || false
  [[ "$output" == *"L1: [Great question!]"* ]] || false
  cmp "$SAMPLE" "$BATS_TEST_TMPDIR/original.md"
}

@test "editorial patterns: protected spans and Markdown blocks cannot manufacture a contrast" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import editorial_patterns
for text in [
    'The response was not "Ready." We retried, but the service timed out.',
    'The response was not `Ready.` We retried, but the service timed out.',
    'The response was not [Ready.](https://example.test) We retried, but the service timed out.',
    '- The cache is not ready\n- The search is slow, but results load.',
    'The cache is not ready\n## Search\nIt is slow, but results load.',
    'The cache is not ready\n---\nIt is slow, but results load.',
]:
    assert not editorial_patterns(text), text
for text in [
    'The page includes not only text\nbut also images.',
    '- The page includes not only text but also images.',
]:
    assert editorial_patterns(text), text
PY
}

@test "editorial patterns: supported closing emphasis preserves stock closer matches" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import editorial_patterns
for phrase in ['Read that again.', 'That is the real win.', 'That distinction matters.', 'I hope this helps!']:
    for marker in ['**', '__']:
        assert editorial_patterns(marker + phrase + marker), (phrase, marker)
PY
}

@test "review phrases preserve repeated opening quotes in multiline dialogue and unmatched contractions" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import rhetorical_scaffolding

for opening, closing in [('“', '”'), ('‘', '’')]:
    text = f'{opening}The guard waited.\n\n{opening}Imagine this: he came back.{closing}\n\nImagine this: the gate is open.'
    assert [hit[0] for hit in rhetorical_scaffolding(text)] == [5], text
# An apostrophe inside a contraction cannot become a closing quotation just
# because a bounded search treats its position as the end of the input.
for text in ["‘An unfinished quote.\nImagine this: we’re ready.",
             "'An unfinished quote.\nImagine this: we're ready."]:
    assert [hit[0] for hit in rhetorical_scaffolding(text)] == [2], text
PY
}

@test "review phrases finish on a document full of unmatched opening quotes" {
  python3 - "$TK" <<'PY'
import subprocess
import sys

code = """import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import rhetorical_scaffolding, editorial_patterns
for quote in ['“', '‘']:
    text = quote * 170000
    assert not rhetorical_scaffolding(text)
    assert not editorial_patterns(text)
"""
# The old quadratic matcher takes tens of seconds; the repaired scan has a
# large margin. This deadline prevents a parser regression hanging the suite.
subprocess.run([sys.executable, '-c', code, sys.argv[1]], check=True, timeout=8)
PY
}

@test "editorial contrast whitespace cannot cross paragraph or Markdown block boundaries" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import editorial_patterns

for text in [
    'This is not\n## Complete\nbut it starts.',
    'The system is not\n\nready but it starts.',
    'Not\n- only text but images.',
    'This\n\nis not storage. It is retrieval.',
    'Not only text but\n\nalso images.',
]:
    assert not editorial_patterns(text), text
for text in ['Not\nonly text but images.', 'Not only text but\nalso images.']:
    assert editorial_patterns(text), text
PY
}

@test "review phrases preserve straight multi-paragraph and separately closed dialogue" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import rhetorical_scaffolding, editorial_patterns, _mask_quotations
failures=[]
for text, expected in [
    ('"The guard waited.\n\n"Imagine this: he came back."\n\nImagine this: the gate is open.', [5]),
    ('"The guard waited.\n\n  "Imagine this: he came back."\n\nImagine this: the gate is open.', [5]),
    ('"A guard."\n\n"Imagine this: he came back."\n\nImagine this: the gate is open.', [5]),
    ('"A guard." "Imagine this: he came back."\n\nImagine this: the gate is open.', [3]),
]:
    got=[hit[0] for hit in rhetorical_scaffolding(text)]
    if got != expected: failures.append((text,expected,got))
text = '"No closing quotation.\n\n"Imagine this: the gate is open.'
assert _mask_quotations(text) == text

assert not failures, failures
PY
}

@test "review phrases do not treat decades and common leading elisions as quotation openers" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import rhetorical_scaffolding, editorial_patterns, _mask_quotations
failures=[]
for elision in ["'90s", "'em", "'tis", "'cause"]:
    text=f"We remember {elision}. Imagine this: every gate opens.\n\nThe workers' union called."
    got=[hit[0] for hit in rhetorical_scaffolding(text)]
    if got != [1]: failures.append((text,[1],got))
for text in ["'Imagine this: the gate opens,' she said.", "He called it 'em'. Imagine this: every gate opens."]:
    expected=[] if text.startswith("'Imagine") else [1]
    got=[hit[0] for hit in rhetorical_scaffolding(text)]
    if got != expected: failures.append((text,expected,got))

assert not failures, failures
PY
}

@test "editorial contrasts stop at setext headings and pipe-table boundaries" {
  python3 - "$TK" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from slop_report import rhetorical_scaffolding, editorial_patterns, _mask_quotations
failures=[]
for text in ['Not required\n============\nBut optional flags still work.',
             'Not required\n--\nBut optional flags still work.',
             '| Not required | Mode |\n| --- | --- |\n| But optional flags | off |',
             'Not required | Mode\n--- | ---\nBut optional flags | off']:
    got=editorial_patterns(text)
    if got: failures.append((text,[],got))
for text in ['Not only text but images.', 'Not\nonly text but images.']:
    if not editorial_patterns(text): failures.append((text,'finding',[]))

assert not failures, failures
PY
}

# ---- installable package: humanize_toolkit ---------------------------------
# pkg_root <dir>: a directory holding the toolkit under its import name, which
# is what pip's package-dir mapping produces in site-packages. A symlink keeps
# this layout-agnostic (skill layout or standalone repo) and needs no network.
pkg_root() { mkdir -p "$1" && ln -s "$TK" "$1/humanize_toolkit"; }

@test "package: importing humanize_toolkit is cheap and never touches sys.path" {
  pkg_root "$BATS_TEST_TMPDIR/site"
  run env PYTHONPATH="$BATS_TEST_TMPDIR/site" python3 -B -c '
import sys
before = list(sys.path); bytecode = sys.dont_write_bytecode
import humanize_toolkit as ht
assert sys.path == before, "sys.path changed"
assert sys.dont_write_bytecode == bytecode, "bytecode flag changed"
heavy = {"humanize_toolkit.slop_report", "humanize_toolkit.emdash_fix", "spacy", "nltk"}
assert not heavy & set(sys.modules), sorted(heavy & set(sys.modules))
for bare in ("textio", "normalize", "emdash_fix", "mla_format", "slop_report", "userfacing", "construction_scanner", "eq_bench_slop_index"):
    assert bare not in sys.modules, bare
print(ht.__version__)'
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "$output"; return 1; }
}

@test "package: every module imports with relative imports and still writes no sys.path entries" {
  pkg_root "$BATS_TEST_TMPDIR/site"
  run env PYTHONPATH="$BATS_TEST_TMPDIR/site" python3 -B -c '
import importlib, sys
before = list(sys.path)
for m in ("textio", "mla_format", "emdash_fix", "normalize", "eq_bench_slop_index", "slop_report", "construction_scanner", "userfacing"):
    importlib.import_module("humanize_toolkit." + m)
assert sys.path == before, "sys.path changed"
for bare in ("textio", "normalize", "emdash_fix", "mla_format", "slop_report"):
    assert bare not in sys.modules, bare
print("ok")'
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "package: the public API works and agrees with the command line" {
  pkg_root "$BATS_TEST_TMPDIR/site"
  run env PYTHONPATH="$BATS_TEST_TMPDIR/site" python3 -B -c '
import sys, humanize_toolkit as ht
text = open(sys.argv[1], encoding="utf-8").read()
assert ht.slop_index(text)["word_hits"] >= 1
assert "tapestry" in ht.scan(text)
assert "—" not in ht.normalize("We paused—it was late—and.")
assert ht.classify("README.md") == "markdown"
print("api ok")' "$SAMPLE"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run env PYTHONPATH="$BATS_TEST_TMPDIR/site" python3 -B -m humanize_toolkit.slop_report "$SAMPLE"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"tapestry"* ]] || false
}

@test "package: __version__ is a plain literal that matches pyproject when one ships" {
  run grep -E '^__version__ = "[0-9]+\.[0-9]+\.[0-9]+"$' "$TK/__init__.py"
  [ "$status" -eq 0 ] || { echo "version literal missing"; return 1; }
  if [ -f "$REPO_ROOT/pyproject.toml" ]; then
    run grep -E '^version = \{ attr = "humanize_toolkit.__version__" \}' "$REPO_ROOT/pyproject.toml"
    [ "$status" -eq 0 ] || { echo "pyproject does not read the single version source"; return 1; }
  fi
}

@test "package: scripts still run by file path from another directory, with isolated mode off" {
  cd "$BATS_TEST_TMPDIR"
  run python3 "$TK/slop_report.py" "$SAMPLE"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"tapestry"* ]] || false
  run python3 "$TK/normalize.py" "$SAMPLE" "$BATS_TEST_TMPDIR/n.md"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "package: scan() never runs a humanize_toolkit planted in the caller's directory" {
  command -v python3 >/dev/null || skip "no python3"
  mkdir -p "$BATS_TEST_TMPDIR/evil/humanize_toolkit" "$BATS_TEST_TMPDIR/site"
  printf 'open("%s/pwned", "w").write("x")\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/evil/humanize_toolkit/slop_report.py"
  mkdir -p "$BATS_TEST_TMPDIR/site"; ln -sfn "$TK" "$BATS_TEST_TMPDIR/site/humanize_toolkit"
  cd "$BATS_TEST_TMPDIR/evil"
  # The package is found via sys.path only (not PYTHONPATH), as an app that vendors it would.
  run python3 -B -c 'import sys; sys.path.insert(1, sys.argv[1])
import humanize_toolkit as ht
assert "tapestry" in ht.scan(open(sys.argv[2]).read())
print("scan ok")' "$BATS_TEST_TMPDIR/site" "$SAMPLE"
  [ ! -e "$BATS_TEST_TMPDIR/pwned" ] || { echo "planted module ran"; return 1; }
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}
