# FFmpeg H.264 Sourcehunt Walkthrough

This page describes how to recreate the FFmpeg H.264 slice-counter
vulnerability hunt with Clearwing in a way that keeps the discovery pass
blind. "Blind" means Clearwing is given only the vulnerable source tree:
no fix diff, no pull request, no CVE text, no blog post, and no human hint
that the issue is in H.264.

The public fix is useful after the run as an oracle for whether the finding
matches the real bug. Do not use it during the discovery pass.

## Case Metadata

- Upstream repository: `https://code.ffmpeg.org/FFmpeg/FFmpeg.git`
- Fix commit: `39e1969303a0b9ec5fb5f5eb643bf7a5b69c0a89`
- Vulnerable parent commit: `795bccdaf57772b1803914dee2f32d52776518e2`
- Fix subject: `avcodec/h264_slice: reject slice_num >= 0xFFFF`
- Fixed file: `libavcodec/h264_slice.c`
- Public review: `https://code.ffmpeg.org/FFmpeg/FFmpeg/pulls/22499/files`

## Blindness Rules

Follow these rules if you want a meaningful recreation:

1. Run Clearwing against the vulnerable parent commit, not the fixed commit.
2. Do not pass the fix commit, pull request, patch, article text, or this
   page into the model context.
3. Do not run `sourcehunt --retro-hunt` for the blind pass. Retro-hunt is
   explicitly patch-derived and is useful only as a non-blind control.
4. Use a fresh `CLEARWING_HOME` or pass `--no-mechanism-memory` so prior
   runs cannot inject remembered mechanisms.
5. For formal benchmarking, use a Clearwing checkout that has not been
   modified with FFmpeg-specific or H.264-specific local hints.

## Prerequisites

Install Clearwing per README.md

## Prepare The Vulnerable Checkout

Use a local checkout so the target is pinned to the parent of the fix commit.
FFmpeg's default branch is `master`, while Clearwing's `--branch` default is
`main`, so a local path avoids branch-name ambiguity.

```bash
mkdir -p ~/clearwing-cases/ffmpeg-h264
cd ~/clearwing-cases/ffmpeg-h264

git clone https://code.ffmpeg.org/FFmpeg/FFmpeg.git ffmpeg-vuln
cd ffmpeg-vuln
git switch --detach 795bccdaf57772b1803914dee2f32d52776518e2

git show --no-patch --pretty=fuller HEAD
```

Confirm that `HEAD` is:

```text
795bccdaf57772b1803914dee2f32d52776518e2
```

Do not fetch or inspect the fix diff yet if you are trying to preserve a
strict blind run.

## Run The Blind Discovery Pass

Create an isolated Clearwing home for this case. This keeps the mechanism
memory store, trajectories, logs, and knowledge graph separate from any
previous sourcehunt work.

```bash
cd ~/clearwing-cases/ffmpeg-h264

export CASE_DIR="$PWD"
export FFMPEG_DIR="$CASE_DIR/ffmpeg-vuln"
export CLEARWING_HOME="$CASE_DIR/.clearwing-blind-home"
export CLEARWING_SOURCEHUNT_TRACE_DIR="$CASE_DIR/trajectories"

rm -rf "$CLEARWING_HOME" "$CLEARWING_SOURCEHUNT_TRACE_DIR" "$CASE_DIR/results"
mkdir -p "$CLEARWING_HOME" "$CLEARWING_SOURCEHUNT_TRACE_DIR" "$CASE_DIR/results"

clearwing sourcehunt "$FFMPEG_DIR" \
  --depth deep \
  --agent-mode deep \
  --max-parallel 8 \
  --shard-entry-points \
  --seed-cves \
  --elaborate-pipeline \
  --no-mechanism-memory \
  --gvisor \
  --output-dir "$CASE_DIR/results" \
  --format all
```

Why these flags:

- `--depth deep` enables the full sourcehunt pipeline: callgraph,
  reachability, Semgrep sidecar if available, taint analysis, sandboxed
  hunters, crash-first harness generation (libFuzzer, 30s per file),
  verifier, patch oracle, and report generation.
- `--agent-mode deep` forces the full-shell agent (execute/read_file/
  write_file/think tools) regardless of the depth-derived default. This
  gives hunters maximum flexibility to compile test harnesses and inspect
  memory layouts.
- `--shard-entry-points` splits high-ranked files into per-function shards
  instead of whole-file analysis. FFmpeg's codec files have many entry
  points; sharding lets each agent focus on one parser, decoder, or fuzz
  target.
- `--seed-cves` extracts CVE history from FFmpeg's git log and injects it
  as seed context for hunters. Past CVE patterns (integer overflows in
  codec parsers, etc.) help hunters recognize similar shapes.
- `--elaborate-pipeline` enables Stage 1.5 autonomous elaboration, which
  upgrades the top 10% of verified findings to higher-impact primitives
  (e.g. promoting a heap overflow to arbitrary write or code execution).
- `--no-mechanism-memory` prevents prior runs from influencing the hunter.
  The fresh `CLEARWING_HOME` is a second isolation layer.
- `--gvisor` uses the gVisor runtime for container isolation, adding an
  extra security layer when running untrusted PoC code inside sandboxes.
- Budget is unlimited by default. Add `--budget 50` to cap spend for a local
  recreation, or pass `--budget 0` explicitly to keep the unlimited default.

### Tuning Band Promotion

The three-band promotion system (fast → standard → deep) auto-promotes
files when signals are detected. For a targeted deep dive you can override:

```bash
  --starting-band standard   # skip the fast band, start at standard
  --redundancy 3             # run 3 independent agents per high-ranked file
```

Higher redundancy increases the chance of finding non-deterministic bugs
(especially race conditions) but costs proportionally more.

### Budget Split

The default tier budget is 70/25/5 (A/B/C). For FFmpeg, Tier B
(propagation-style headers like `codec_limits.h`) is unusually important.
Consider:

```bash
  --tier-split 60/35/5       # shift budget toward Tier B propagation files
```

Unused budget rolls forward: A → B → C.

### Cross-Subsystem Hunting

FFmpeg's codecs interact heavily across subsystem boundaries. After the
per-file hunt, enable cross-subsystem analysis:

```bash
  --subsystem-hunt \
  --subsystem libavcodec \
  --subsystem libavutil \
  --subsystem libavformat
```

This runs additional agents that see all findings from the per-file phase
and can discover cross-file interaction bugs (e.g., a type mismatch between
`h264dec.h` declarations and `h264_slice.c` usage).

The command writes a session directory under:

```text
~/clearwing-cases/ffmpeg-h264/results/<session_id>/
```

The important files are:

- `report.md` - human-readable findings with pipeline health summary.
- `findings.json` - structured findings, verifier output, and stability
  classifications.
- `findings.sarif` - IDE/code-scanning import.
- `manifest.json` - run metadata, spend by tier, and pipeline status.

## Run Multiple Independent Passes

The original scenario was not a guaranteed single-shot discovery. For a closer
recreation, run several isolated passes and compare their reports:

```bash
cd ~/clearwing-cases/ffmpeg-h264
export CASE_DIR="$PWD"
export FFMPEG_DIR="$CASE_DIR/ffmpeg-vuln"

for i in 1 2 3 4 5; do
  RUN_HOME="$CASE_DIR/.clearwing-blind-home-$i"
  RUN_OUT="$CASE_DIR/results-pass-$i"
  RUN_TRACE="$CASE_DIR/trajectories-pass-$i"
  rm -rf "$RUN_HOME" "$RUN_OUT" "$RUN_TRACE"
  mkdir -p "$RUN_HOME" "$RUN_OUT" "$RUN_TRACE"

  CLEARWING_HOME="$RUN_HOME" \
  CLEARWING_SOURCEHUNT_TRACE_DIR="$RUN_TRACE" \
  clearwing sourcehunt "$FFMPEG_DIR" \
    --depth deep \
    --agent-mode deep \
    --max-parallel 8 \
    --shard-entry-points \
    --seed-cves \
    --elaborate-pipeline \
    --no-mechanism-memory \
    --gvisor \
    --output-dir "$RUN_OUT" \
    --format all
done
```

If shell automation treats high-severity findings as a failing command, check
the output directories before discarding the run. `sourcehunt` may return a
non-zero exit code when it finds high or critical issues.

## Identify A Successful Finding

Search the generated reports for the H.264 slice-counter mechanism:

```bash
cd ~/clearwing-cases/ffmpeg-h264

rg -n \
  "h264_slice|h264dec|slice_table|current_slice|slice_num|0xFFFF|65535|65536|deblock|sentinel" \
  results*/*/report.md \
  results*/*/findings.json
```

A matching finding should explain substantially this root cause:

- FFmpeg tracks macroblock ownership in a `slice_table`.
- The table entries are 16-bit values and are initialized to all `0xFF`
  bytes, making `0xFFFF` the "no slice owns this position" sentinel.
- The slice counter is wider and can continue increasing until a real slice
  number aliases that sentinel value.
- Neighbor/same-slice logic can then believe an out-of-bounds or padding
  neighbor belongs to the current slice.
- The deblocking path can follow that incorrect neighbor decision into an
  out-of-bounds heap write.

The best report will point at `libavcodec/h264_slice.c` and should also
notice the type mismatch with declarations in `libavcodec/h264dec.h`.

### Checking PoC Stability

If a finding includes a concrete PoC, check its stability classification
in `findings.json`:

```bash
jq '.[] | select(.file | contains("h264_slice")) |
  {id, stability_classification, stability_success_rate, stability_total_runs}' \
  results*/*/findings.json
```

Findings classified as `stable` (≥90% reproduction rate across 3 fresh
containers) are the strongest. `flaky` findings (50–90%) may indicate
ASLR sensitivity or timing dependence. The stability verifier automatically
attempts one hardening round for unreliable PoCs before archival.

### Checking Validation Axes

With the default v2 validator, each finding is evaluated on four
independent axes: REAL, TRIGGERABLE, IMPACTFUL, and GENERAL. Inspect
the validation details:

```bash
jq '.[] | select(.file | contains("h264_slice")) |
  {id, severity, evidence_level, verified,
   validator_real, validator_triggerable, validator_impactful, validator_general}' \
  results*/*/findings.json
```

## Validate Against The Public Fix

Only after the blind pass, fetch and inspect the official fix:

```bash
cd ~/clearwing-cases/ffmpeg-h264/ffmpeg-vuln

git fetch origin 39e1969303a0b9ec5fb5f5eb643bf7a5b69c0a89
git diff \
  795bccdaf57772b1803914dee2f32d52776518e2 \
  39e1969303a0b9ec5fb5f5eb643bf7a5b69c0a89 \
  -- libavcodec/h264_slice.c
```

The patch rejects excessive slice counts before assigning the next slice
number. A strong Clearwing finding does not need to reproduce the exact patch,
but it should converge on the same invariant: a slice number must never be
allowed to collide with the sentinel value used by the 16-bit slice table.

You can also run a fixed-commit control:

```bash
cd ~/clearwing-cases/ffmpeg-h264/ffmpeg-vuln
git switch --detach 39e1969303a0b9ec5fb5f5eb643bf7a5b69c0a89

cd ~/clearwing-cases/ffmpeg-h264
export CASE_DIR="$PWD"
export FFMPEG_DIR="$CASE_DIR/ffmpeg-vuln"
export CLEARWING_HOME="$CASE_DIR/.clearwing-fixed-home"

rm -rf "$CLEARWING_HOME" "$CASE_DIR/results-fixed"
mkdir -p "$CLEARWING_HOME" "$CASE_DIR/results-fixed"

clearwing sourcehunt "$FFMPEG_DIR" \
  --depth standard \
  --agent-mode deep \
  --max-parallel 8 \
  --shard-entry-points \
  --seed-cves \
  --no-mechanism-memory \
  --output-dir "$CASE_DIR/results-fixed" \
  --format all
```

The fixed control should either omit the slice-counter finding or mark the
dangerous counter/sentinel collision as mitigated.

## Post-Discovery: Elaborate and Disclose

After a successful blind discovery, use the elaboration and disclosure
tools to upgrade the finding and prepare for responsible disclosure.

### Elaborate a Finding

Upgrade a partial finding (e.g., heap overflow → arbitrary write → code
execution) using the interactive elaboration agent:

```bash
clearwing sourcehunt "$FFMPEG_DIR" \
  --elaborate <finding_id> \
  --elaborate-session <session_id> \
  --output-dir "$CASE_DIR/results"
```

Or run autonomous elaboration on the top findings:

```bash
clearwing sourcehunt "$FFMPEG_DIR" \
  --elaborate-top 3 \
  --elaborate-session <session_id> \
  --output-dir "$CASE_DIR/results"
```

### Generate Disclosure Templates

```bash
clearwing sourcehunt "$FFMPEG_DIR" \
  --depth quick \
  --export-disclosures \
  --reporter-name "Your Name" \
  --reporter-affiliation "Your Org" \
  --reporter-email "you@example.com" \
  --output-dir "$CASE_DIR/results"
```

This writes pre-filled MITRE CVE request and HackerOne templates for
verified findings into the session directory.

### Disclosure Workflow

Queue findings for human review and track disclosure timelines:

```bash
clearwing disclose queue "$CASE_DIR/results/<session_id>"
clearwing disclose review
clearwing disclose validate <finding_id>
clearwing disclose send <finding_id>
clearwing disclose status
```

The disclosure system tracks 60/75/90-day timelines and creates SHA-3
cryptographic commitments to prove discovery priority.

## N-Day Exploit Pipeline (Post-Fix)

After the blind experiment, use the N-day pipeline to develop a working
exploit against the known vulnerability. This is explicitly non-blind:

```bash
cd ~/clearwing-cases/ffmpeg-h264/ffmpeg-vuln
git switch --detach 795bccdaf57772b1803914dee2f32d52776518e2

clearwing sourcehunt "$FFMPEG_DIR" \
  --nday \
  --cve CVE-2025-XXXXX \
  --patch-commit 39e1969303a0b9ec5fb5f5eb643bf7a5b69c0a89 \
  --nday-budget deep \
  --output-dir "$CASE_DIR/results-nday"
```

The N-day pipeline builds the vulnerable version, develops a working
exploit using the agentic exploiter with sanitizer instrumentation, and
validates against the patched version.

## Retro-Hunt (Non-Blind Control)

After the blind experiment, use the fix diff and `sourcehunt --retro-hunt`
to test whether patch-derived variant hunting can rediscover the same
pattern:

```bash
clearwing sourcehunt "$FFMPEG_DIR" \
  --retro-hunt CVE-2025-XXXXX \
  --patch-source 39e1969303a0b9ec5fb5f5eb643bf7a5b69c0a89 \
  --patch-repo "$FFMPEG_DIR" \
  --output-dir "$CASE_DIR/results-retro"
```

Retro-hunt generates Semgrep rules from the fix and searches for variant
patterns across the codebase. Do not mix retro-hunt results with
blind-discovery claims.

## Optional Local ASan Build

Clearwing's sourcehunt run does not require you to build FFmpeg manually, but
a local ASan build is useful if a run produces a concrete H.264 proof of
concept.

```bash
cd ~/clearwing-cases/ffmpeg-h264/ffmpeg-vuln
git switch --detach 795bccdaf57772b1803914dee2f32d52776518e2

./configure \
  --cc=clang \
  --cxx=clang++ \
  --disable-stripping \
  --disable-doc \
  --disable-optimizations \
  --enable-debug=3 \
  --extra-cflags='-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1' \
  --extra-ldflags='-fsanitize=address,undefined'

NPROC="$(sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN)"
make -j"$NPROC"
```

If Clearwing emits a PoC input, run it through the sanitizer-built binary and
keep the ASan report with the finding. Then rebuild at the fixed commit and
confirm the same input no longer reaches the out-of-bounds path.

## Troubleshooting

- `fatal: invalid reference: main`: FFmpeg uses `master`; use the local
  checkout flow above or pass `--branch master` for unpinned scans.
- Docker errors: run `clearwing doctor` and confirm Docker is reachable.
  Without Docker, Clearwing can still reason over source, but sanitizer-backed
  evidence is weaker. Add `--gvisor` for stronger container isolation.
- No matching finding: increase budget, run more independent passes, enable
  `--shard-entry-points` and `--seed-cves`, and keep `CLEARWING_HOME`
  isolated. Large mature C projects are intentionally hard targets.
- Too much report noise: search `findings.json` first, then inspect the
  matching hunter trajectory under `trajectories*/`. Check
  `stability_classification` to filter out unreliable PoCs.
- Need a non-blind control: after the blind experiment, use the fix diff and
  `sourcehunt --retro-hunt` to test whether patch-derived variant hunting can
  rediscover the same pattern. Do not mix that result with blind-discovery
  claims.
- PoC instability: if a finding has `stability_classification: "flaky"`,
  consider running with `--redundancy 5` to increase the number of
  independent agents per file, or manually trigger hardening through
  elaboration.
