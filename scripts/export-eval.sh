#!/usr/bin/env bash
# export-eval.sh [OUTDIR] — assemble the standalone `eval` repo tree from this
# repo, which is the single source of truth for the skill.
#
# Deliberately a pure copy: the standalone repo names the toolkit directory
# `toolkit/`, exactly as the skill does, and tests/eval-toolkit.bats locates
# its layout at runtime. So there is no path rewriting anywhere in this
# script. That is the point — a transformation step is the thing that drifts,
# and a rewrite that half-applies produces a repo whose tests pass and whose
# docs lie. The two files with no in-repo source (README.md and .gitignore)
# are written below by this script itself: the eval export deliberately owns
# no helper directory, so everything the export produces is either a byte
# copy of an in-repo file or text defined verbatim here; nothing is derived
# from the source tree's shape.
#
# Idempotent: it removes only the paths it owns, so re-running over a real git
# checkout leaves .git and anything else in place.
set -euo pipefail

SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$SRC_ROOT/dist/eval}"
. "$SRC_ROOT/scripts/lib/export-lib.sh"

SKILL_DIR="$SRC_ROOT/skills/eval"
[ -f "$SKILL_DIR/SKILL.md" ] || { echo "no skill at $SKILL_DIR" >&2; exit 1; }
[ -d "$SKILL_DIR/toolkit" ] || { echo "no toolkit at $SKILL_DIR/toolkit" >&2; exit 1; }

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd -P)"
# The export deletes and rewrites toolkit/ and tests/ under OUT, so OUT must
# not overlap the source tree in either direction (shared guard).
export_refuse_source_overlap || exit 1
# Only our own outputs are cleared; a .git directory or local notes survive.
rm -rf "$OUT/toolkit" "$OUT/tests"
mkdir -p "$OUT/toolkit" "$OUT/tests"

cp "$SKILL_DIR/SKILL.md"                     "$OUT/SKILL.md"
# An allowlist, not a denylist: only toolkit files git tracks (committed or
# staged; their working-tree content is copied) ship. Anything else, be it __pycache__/, a macOS
# .DS_Store, scratch notes or a misnamed secret, stays out of the public tree.
# To publish a new toolkit file, `git add` it first.
( cd "$SKILL_DIR/toolkit" && git ls-files -z -- . ) \
  | while IFS= read -r -d '' f; do
      case "$f" in */*) continue ;; esac       # top level only, as the skill loads it
      # A symlink would publish whatever it points at (or dangle in the public repo).
      [ ! -L "$SKILL_DIR/toolkit/$f" ] || { echo "refusing to export symlinked toolkit file: $f" >&2; exit 1; }
      cp "$SKILL_DIR/toolkit/$f" "$OUT/toolkit/"
    done
untracked="$(cd "$SKILL_DIR/toolkit" && git ls-files --others --exclude-standard -- . | grep -v / || true)"
[ -z "$untracked" ] || printf '%s\n' "$untracked" | sed 's/^/not exported (untracked; git add to publish): /' >&2
cp "$SRC_ROOT/tests/eval-toolkit.bats"   "$OUT/tests/"
cp "$SRC_ROOT/LICENSE"                   "$OUT/LICENSE"

# The standalone repo's front door. Byte-identity with a source file is not
# testable for these two (the source is this heredoc), so tests/export-eval.bats
# pins their content instead: they may only name paths the export creates.
cat > "$OUT/README.md" <<'README'
# eval

Measure whether a change to AI behavior (a prompt edit, a skill rewording, an
agent-loop change, a RAG pipeline tweak) actually improved things, the way you
would measure a code change: a grid-sampled eval set with negative controls
and a generated response side, a hand-labeled answer key, a judge written like
code, and calibration of that judge against the key before any system number
is trusted. "It looks better" is not evidence.

[`SKILL.md`](SKILL.md) is the full method, written as an
[agent skill](https://code.claude.com/docs/en/skills): drop this directory into
`~/.claude/skills/eval/` and ask your agent to evaluate a behavior change, or
read it as a checklist and run the loop by hand.

The toolkit is one dependency-free script:

```bash
# judge the human-labeled subset, write one {"human","judge"} pair per line,
# then read the judge's calibration before trusting it at scale:
python3 toolkit/calibrate.py labels.jsonl                  # FAIL positive, the usual
python3 toolkit/calibrate.py labels.jsonl --positive PASS  # the swapped convention
```

It prints the confusion counts (TP/TN/FP/FN), TPR (recall), TNR
(specificity), accuracy and precision at 4 decimals, plus a one-line bias
reading: harsh when the judge fails good work more than it waves bad work
through, lenient when the reverse. A two-column CSV (human first) also reads.

Python 3 standard library only; nothing to install, no model calls.

## Tests

```bash
bats tests/eval-toolkit.bats
```

The suite pins the method's worked example (80 labeled runs: counts, all four
metrics, and the harsh reading with both error shares) so a regression in the
arithmetic is caught against a known-good case rather than the
implementation's own echo.

## License

MIT, see [LICENSE](LICENSE). All code here is original and standard-library
only; no third-party data ships, so there is no NOTICE file.
README

cat > "$OUT/.gitignore" <<'IGNORE'
__pycache__/
*.pyc
IGNORE

# The export is only good if it stands alone, so prove it here rather than
# discovering it after a push. No bats means no proof, so no export.
command -v bats >/dev/null 2>&1 || {
  echo "bats is required to verify the export (brew install bats-core); $OUT is NOT publishable" >&2
  exit 1
}
if bats "$OUT/tests/eval-toolkit.bats" >/dev/null 2>&1; then
  verdict="tests pass in the exported tree"
else
  echo "export FAILED its own tests at $OUT — not publishable" >&2
  bats "$OUT/tests/eval-toolkit.bats" >&2 || true
  exit 1
fi

printf 'exported to %s (%s files, %s)\n  %s\n' \
  "$OUT" "$(find "$OUT" -type f -not -path '*/.git/*' | wc -l | tr -d ' ')" \
  "$(du -sh "$OUT" 2>/dev/null | cut -f1)" "$verdict"
