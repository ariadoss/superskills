# Codex Prompt/Workflow Adoption — Eval-Gated Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt only the Codex-harness improvements that measurably improve superskills skills under `claude plugin eval` — each behind a pre-registered adopt/reject threshold — plus two zero-model-cost infrastructure imports from Codex's evaluation method; document null results as real answers.

**Architecture:** Two deterministic infrastructure pieces first (host-neutrality lint, lexical-selection baseline), then three single-intervention A/B experiments in cost order (basic-review calibration → write-plan contrastive examples → qa-full check accounting), each following the PREREG discipline established by `evals/reports/2026-10-04-orchestration-checklist-PREREG.md`. Everything rejected up front (with reasons) stays out of the tree.

**Tech Stack:** `claude plugin eval` (sonnet judge), bats, Python 3 stdlib (no new dependencies), markdown skill bodies.

---

## Research verdicts (done before this plan — do not re-litigate while executing)

Verified against `/tmp/codex` at commit `062439b` (2026-10-05, shallow clone — re-clone with `git clone --depth 1 https://github.com/openai/codex /tmp/codex` if gone):

| Candidate | Evidence | Verdict |
|---|---|---|
| Contrastive good/bad plan examples | **Confirmed present**: `codex-rs/protocol/src/prompts/base_instructions/default.md:101-119` and `codex-rs/core/gpt_5_2_prompt.md:87-107` both ship "Low-quality plans" blocks. **No in-repo ablation proves they help.** The user's prior (bad examples can hurt) is untested. | **Experiment B decides.** (Task 4) |
| Status invariants (exactly-one-in-progress, no pending→completed jumps) | Confirmed at `gpt_5_2_prompt.md:46`. They govern a host-side plan *tool*. Our plans are files with checkboxes executed by host agents whose todo semantics differ per host. | **Rejected:** host-specific semantics; cross-harness rule (below) forbids naming host tools; our executing-plans/subagent-driven-development already own checkbox discipline. |
| Skills usage contract (trigger/announce/no-delegation/fallback) | `codex-rs/ext/skills/src/catalog_prompt.rs`. Superskills already has: fallback-with-reason (`qa-full` "How sub-skills run"), in-session invocation ("doing the check's work by hand from memory is not running it"), resume notes, and — verified during review — a full per-check accounting ledger with dispositions (RAN-CLEAN/FIXED/UNFIXED/SKIPPED/NOT-TRIGGERED/MANDATORY-FAIL, `skills/qa-full/SKILL.md` around line 618) plus a structured report file (`qa-full-reports/`, ~line 659). The Codex delta would duplicate existing output. | **Rejected after review:** no behavioral experiment (would measure a duplicate); only the inert authoring conventions ride along in Task 5, with zero model spend. |
| Review rubric calibration (8-condition bug test, "prefer no findings", comment discipline) | `codex-rs/prompts/templates/review/rubric.md`. Our `basic-review` has severity+confidence but no introduced-in-diff rule, no speculation bar, no precision-first stance. | **Experiment A.** (Task 3) |
| Strict JSON review output schema | Same file. Our review consumers are humans and `/qa-full`; no machine consumer exists. | **Rejected:** YAGNI — no consumer for the JSON. |
| Compaction/handoff summary for resume notes | `prompts/templates/compact/prompt.md` — progress/decisions, constraints, next steps, critical data. `quota-resilience` already ships Goal/Done/In-flight/Next-steps/Verify/Context/Hops. | **Rejected:** already equivalent; only a framing sentence differs; no plausible measurable delta. |
| Codex skill-evaluation method | Production telemetry + shadow-mode deterministic selectors (`ext/skills/src/shadow_selection_experiment/mod.rs`: BM25/ngram/lexical selectors, "cheap enough to run in shadow mode on every turn", inputs frozen before outcomes, metrics-flag A/B). We cannot replicate production telemetry. | **Adopt the two transferable pieces:** deterministic lexical baseline as a comparison row (Task 2, report Task 6), and PREREG discipline (already ours — keep). |
| Tool-hygiene block (parallel reads, don't re-read after edits) | `gpt_5_2_prompt.md:252`. Claude Code / ZCode base prompts already instruct this; per-skill duplication is host-behavior we can't measure separately. | **Rejected:** unmeasurable + host-dependent. |
| `get_context_remaining` / `new_context` / `tool_search` meta-tools | Harness-level features, not skill-level. | **Rejected:** out of superskills' layer. |
| claw-code (`ultraworkers/claw-code`) | Self-described "museum exhibit"; real harnesses it points to are LazyCodex/Gajae-Code. Its agent-managed artifacts (commit-stamped generated AGENTS.md index, `progress.txt` iteration log, `prd.json` acceptance criteria) map to things superskills already has: `repomap`/`dbmap` skills, `quota-resilience` resume notes, write-plan's Test Plan & Verification. | **Nothing adopted.** No artifact meets the measurable-improvement bar. |

**Cross-harness rule (user requirement):** superskills installs into Claude Code, Codex, ZCode, OpenCode, and minimal harnesses. Every intervention in this plan is a markdown edit to a skill body that introduces **no new host-specific instructions** — that is the portability claim, and it is deliberately narrow: existing skill bodies already contain Claude-flavored mechanisms (`Skill(defense)`, `${CLAUDE_PLUGIN_ROOT}`), and all behavioral measurement happens under Claude Code because that is the only harness `claude plugin eval` exercises. Both limits are stated, not hidden. Task 1 enforces the narrow claim (no skill body names a tool exclusive to another host); full host-syntax neutrality across the existing corpus is a separate pre-existing project this plan does not claim.

**Cost governance (money rule):** every behavioural run is a real model charge. Every `claude plugin eval` command below carries a per-command `--max-cost-usd` sized so the sum of an experiment's commands meets its stated budget: Experiment A ≤ $19 (3 + 8 + 8), Experiment B ≤ $45 (15 + 15 + 15). Task 5 spends nothing. Total if everything runs: **≈ $45–64** plus judge calls (planning runs measured $1.00–1.53 each on 2026-10-04). Each experiment has a stated abort condition; the plan remains valid with that experiment skipped and the abort reported.

**Security & threat model:** this feature crosses no trust boundary — no auth, no untrusted input, no sensitive data; the eval fixtures are local synthetic repos and the scripts never leave the machine. Stated per the plan checklist; no `/cso` design pass needed.

---

## File Structure

| File | Responsibility | Create/Modify |
|---|---|---|
| `tests/lib/host-neutral-lib.sh` | One function: grep a file list for host-specific tool tokens, honoring a `host-tool-allow:` escape comment. Single reason to change: the token list or matching rule. | Create |
| `tests/skills-host-neutral.bats` | Lint test: fixture with a planted violation fails; the real tree passes. | Create |
| `evals/_lib/lexical-baseline.py` | Deterministic BM25 ranking of skill frontmatter against eval-case prompts; derives the answer key from each case's `skill-fired` grader (no hand-maintained key file — DRY: the key already exists as `input_match` patterns). `--selftest` embeds its own fixture for bats. | Create |
| `evals/_lib/review-fixture.sh` | Builds the two-mode review fixture repo (planted introduced bug, pre-existing bug, speculative bait, style bait). Idempotent (`rm -rf` first, mirroring `qa-full-fixture.sh`). | Create |
| `evals/review-calibration/`, `evals/review-clean/` | Experiment A cases: `prompt.md`, `graders/`, plus the harness wiring pair `case.yaml` + `fixture.sh` (the `scaffold_script` convention the doctor cases use). | Create |
| `evals/writeplan-plan-quality/` | Experiment B's new case (`prompt.md` + graders; planning asks need no fixture). | Create |
| `evals/reports/<date>-*-PREREG.md` (×2) | Pre-registrations: intervention, cases, fairness rules, endpoints, thresholds, power gates, abort conditions — each committed before its experiment's first comparative run. | Create |
| `skills/basic-review/SKILL.md` | Experiment A intervention: "What earns a finding" block after the calibration guidance (~line 68); `version: 1.1.0` → `1.2.0` only on adoption. | Modify (gated) |
| `skills/write-plan/SKILL.md` | Experiment B intervention: plan-quality examples after "Bite-Sized Task Granularity" (~line 78). This skill's frontmatter carries no version field. | Modify (gated) |
| `ENGINEERING_STANDARDS.md` | Inert authoring conventions: "Skill usage rules" (announce, fallback, no-summary-delegation, no cross-turn carry). Inert for behaviour: no skill fetches this file at runtime. | Modify (ungated, Task 5) |
| `evals/reports/<date>-lexical-baseline.md`, `evals/reports/<date>-codex-adoption.md` | Comparison report; consolidated verdicts. | Create |

DRY: the routing answer key is derived from existing graders, never re-typed; review fixtures live in `_lib/` shared by both review cases via case-local `fixture.sh` shims; the two PREREGs are each self-contained (deliberate: a PREREG is a legal document, sharing a template would couple experiments).
SOLID: `host-neutral-lib.sh` exposes one narrow function (ISP); `lexical-baseline.py` separates scoring / key-derivation / reporting so a future selector swap touches one seam (OCP).
YAGNI: no key file, no selector framework, no JSON review schema, no cross-turn eval machinery, no qa-full experiment (its accounting ledger already exists — verified `skills/qa-full/SKILL.md` ~618 and ~659) — none has a consumer in this plan.

---

## Context for executors (zero-context assumption)

- **This repo IS superskills** — a plugin of markdown skills installed into multiple agent harnesses. `AGENTS.md` and `ENGINEERING_STANDARDS.md` are the contributor rules; `evals/README.md` is the eval harness manual — read it before Task 3.
- **Eval harness:** `claude plugin eval . --case <name> --runs N --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd <cap> --json <out>`. Judge model must stay sonnet ("judge accuracy is a measured quantity; do not downgrade it"). Results land in `evals/results/<timestamp>/` (git-ignored). A case = a directory with `prompt.md` (frontmatter: `max_turns`, `timeout_seconds`, `allowed_tools`, `tags`) plus `graders/*.md`. Grader types: `tool_used` (mechanical indicator, never scored for Δ) and `llm` (focus: `last_message`, 0–1 score).
- **Do not use in-session subagents for routing evals** (`evals/README.md` — ~25% firing ceiling is the harness, not wording; closed question).
- **Git model:** trunk-based; commit every task with the repo's git user (`git config user.name` is Danilo Stern-Sapad); never add Co-Authored-By lines; never rewrite `main`.
- **Versioning:** if any experiment adopts, ship once at the end (Task 7): one reviewed bump per merged change.

---

### Task 0: Commit the pre-existing untracked eval artifacts

The 2026-10-04 orchestration run left its cases and reports untracked (`git status`: `evals/writeplan-*` dirs, `evals/reports/2026-10-04-orchestration-checklist*.md`). Experiment B uses two of those cases as regression guards and cites that report; a fresh-checkout executor would otherwise lack them.

- [ ] **Step 1: Verify they are the prior session's finished artifacts**

Run: `git status --short evals/ && ls evals/writeplan-simple-crud evals/reports/2026-10-04-orchestration-checklist.md`
Expected: the six `writeplan-*` case dirs and both 2026-10-04 reports listed. If anything else untracked appears under `evals/`, stop and report before committing — do not sweep unknown files into this commit.

- [ ] **Step 2: Commit them as prior-session work**

```bash
git add evals/writeplan-batch-classify evals/writeplan-docs-agent evals/writeplan-judge-loop evals/writeplan-overreach evals/writeplan-router-intake evals/writeplan-simple-crud evals/reports/2026-10-04-orchestration-checklist-PREREG.md evals/reports/2026-10-04-orchestration-checklist.md
git commit -m "evals: commit the 2026-10-04 orchestration-checklist artifacts (six writeplan-* cases + PREREG + report) left untracked by the prior session; Experiment B reuses two of these cases as regression guards"
```

---

### Task 1: Host-neutrality lint (Codex lesson: never name tools the host doesn't have)

**Files:**
- Create: `tests/lib/host-neutral-lib.sh`
- Create: `tests/skills-host-neutral.bats`

- [ ] **Step 1: Write the failing test**

`tests/skills-host-neutral.bats`:

```bats
#!/usr/bin/env bats
# Host-neutrality lint: shared skill bodies must not name host-specific tools.
# Superskills installs into Claude Code, Codex, ZCode, OpenCode and minimal
# harnesses; a skill that tells the model to call another host's tool teaches
# a call that cannot succeed here.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/tests/lib/host-neutral-lib.sh"
}

@test "host-neutral lint flags a planted violation" {
  tmp="$(mktemp -d)"
  cat > "$tmp/BAD_SKILL.md" <<'EOF'
---
name: bad
description: Calls a tool that only exists on one host.
---
Use multi_tool_use.parallel to batch your reads.
EOF
  run host_neutral_check "$tmp/BAD_SKILL.md"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "multi_tool_use"
  rm -rf "$tmp"
}

@test "host-neutral lint passes the allowlist escape" {
  tmp="$(mktemp -d)"
  cat > "$tmp/OK_SKILL.md" <<'EOF'
---
name: ok
description: Documents a host tool without instructing its use.
---
The Codex harness names a tool multi_tool_use.parallel. <!-- host-tool-allow: multi_tool_use -->
EOF
  run host_neutral_check "$tmp/OK_SKILL.md"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "tracked skill bodies name no host-specific tools" {
  files="$(git ls-files -- 'skills/*/SKILL.md' 'design-skills/*/SKILL.md' 'marketing-skills/*/SKILL.md')"
  [ -n "$files" ]
  status_sum=0
  while IFS= read -r f; do
    host_neutral_check "$f" || status_sum=1
  done <<< "$files"
  [ "$status_sum" -eq 0 ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/skills-host-neutral.bats`
Expected: FAIL — `load lib/host-neutral-lib` cannot find the library.

- [ ] **Step 3: Write the library**

`tests/lib/host-neutral-lib.sh`:

```bash
#!/usr/bin/env bash
# host_neutral_check <file> — exit 1 naming violations, exit 0 when clean.
# Tokens are host-specific tool names that must never appear as instructions
# in a shared skill body. A line containing "host-tool-allow:" is exempt
# (documenting a host's behavior is fine; instructing a call is not).
host_neutral_check() {
  local file="$1"
  local tokens=(multi_tool_use TodoWrite update_plan write_stdin exec_command get_context_remaining)
  local bad=0 t line
  for t in "${tokens[@]}"; do
    while IFS= read -r line; do
      case "$line" in
        *host-tool-allow:*) continue ;;
        *"$t"*)
          echo "host-specific tool '$t' in $file: $line"
          bad=1
          ;;
      esac
    done < <(grep -F "$t" "$file" 2>/dev/null)
  done
  return "$bad"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/skills-host-neutral.bats && ./tests/run.sh`
Expected: all PASS (the real tree is clean — verified 2026-10-05: zero hits for all six tokens).

- [ ] **Step 5: Commit**

```bash
git add tests/lib/host-neutral-lib.sh tests/skills-host-neutral.bats
git commit -m "tests: host-neutrality lint for shared skill bodies — superskills installs into Claude Code, Codex, ZCode, OpenCode and minimal harnesses, so a skill naming another host's tool (multi_tool_use, TodoWrite, update_plan, write_stdin, exec_command, get_context_remaining) teaches a call that cannot succeed; allowlist escape via host-tool-allow: comments; adopted from the Codex lesson of stripping instructions for absent tools"
```

---

### Task 2: Lexical-selection baseline (Codex eval-method import)

**Files:**
- Create: `evals/_lib/lexical-baseline.py`

- [ ] **Step 1: Write the self-test (embedded, runs via `--selftest`)**

`evals/_lib/lexical-baseline.py` — complete file:

```python
#!/usr/bin/env python3
"""Deterministic lexical baseline for skill triggering.

Codex evaluates skill selection with cheap deterministic selectors run in
shadow mode against real invocations (codex-rs/ext/skills/src/
dynamic_skill_selector.rs: "deterministic, side-effect free, and cheap enough
to run in shadow mode on every turn"). We cannot run production telemetry,
but we can add the same kind of dumb-baseline row to our eval reports: if a
BM25 ranker over skill descriptions matches the answer key as well as the
model does, the model is not adding value on that slice; if it does far
worse, model judgement is earning its cost.

The answer key is derived from each case's graders/skill-fired.md input_match
pattern — the key already exists there; this script never re-types it.

Usage:
  evals/_lib/lexical-baseline.py --selftest
  evals/_lib/lexical-baseline.py [--evals-root evals] [--skills-root skills]
"""
import argparse
import math
import re
import sys
from pathlib import Path

TOKEN_RE = re.compile(r"[a-z0-9]+")
BM25_K1 = 1.5
BM25_B = 0.75

HOST_TOKENS = ("multi_tool_use", "TodoWrite", "update_plan",
               "write_stdin", "exec_command", "get_context_remaining")


def tokenize(text):
    return TOKEN_RE.findall(text.lower())


def parse_frontmatter(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---"):
        return "", text
    end = text.find("\n---", 3)
    if end == -1:
        return "", text
    return text[3:end], text[end + 4:]


def skill_documents(skills_root):
    """[(name, tokens)] from every skills/*/SKILL.md frontmatter.

    The whole frontmatter block is the document (name, description, triggers):
    trigger phrases are the designed routing keywords, so a lexical baseline
    should see them too.
    """
    docs = []
    for skill_md in sorted(Path(skills_root).glob("*/SKILL.md")):
        fm, _ = parse_frontmatter(skill_md)
        name_m = re.search(r"^name:\s*(\S+)", fm, re.M)
        name = name_m.group(1) if name_m else skill_md.parent.name
        docs.append((name, tokenize(fm)))
    return docs


def expected_skill_from_graders(case_dir):
    """Derive the answer key from graders/skill-fired.md input_match.

    The value is a quoted regex like '"skill"\s*:\s*"(?:[\w-]+:)?NAME"' —
    take the last double-quoted segment and strip the optional namespace
    prefix, which yields NAME.
    """
    grader = case_dir / "graders" / "skill-fired.md"
    if not grader.is_file():
        return None  # not a routing case; skipped, reported as '-'
    text = grader.read_text()
    m = re.search(r"input_match:\s*'(.*)'", text) or re.search(r'input_match:\s*"(.*)"', text)
    if not m:
        return None
    parts = re.findall(r'"([^"]*)"', m.group(1))
    if not parts:
        return None
    name = re.sub(r"^\(\?:\[\\w-\]\+:\)\?", "", parts[-1])
    return name or None


class Bm25:
    def __init__(self, docs):
        self.docs = docs
        self.df = {}
        for _, toks in docs:
            for t in set(toks):
                self.df[t] = self.df.get(t, 0) + 1
        self.avgdl = sum(len(t) for _, t in docs) / max(1, len(docs))

    def score(self, query, doc_tokens):
        s = 0.0
        dl = len(doc_tokens)
        for t in set(query):
            if t not in self.df:
                continue
            idf = math.log(1 + (len(self.docs) - self.df[t] + 0.5) / (self.df[t] + 0.5))
            tf = doc_tokens.count(t)
            s += idf * tf * (BM25_K1 + 1) / (tf + BM25_K1 * (1 - BM25_B + BM25_B * dl / self.avgdl))
        return s

    def top(self, query, n=3):
        ranked = sorted(((self.score(query, toks), name) for name, toks in self.docs), reverse=True)
        return ranked[:n]


def case_prompt(case_dir):
    _, body = parse_frontmatter(case_dir / "prompt.md")
    return tokenize(body)


def run_report(evals_root, skills_root, out=print):
    docs = skill_documents(skills_root)
    catalog = {name for name, _ in docs}
    if not docs:
        out("| case | expected | bm25 top-1 | hit |")
        out("|---|---|---|---|")
        return 0.0, 0
    bm25 = Bm25(docs)
    hits = total = 0
    out("| case | expected | bm25 top-1 | hit |")
    out("|---|---|---|---|")
    for case_dir in sorted(Path(evals_root).iterdir()):
        if not (case_dir / "prompt.md").is_file():
            continue
        expected = expected_skill_from_graders(case_dir)
        if expected is None:
            out(f"| {case_dir.name} | (no key) | - | - |")
            continue
        if expected not in catalog:
            # marketing-* cases key on skills in marketing-skills/, not skills/;
            # a different catalog is a different (incomparable) ranking pool.
            out(f"| {case_dir.name} | {expected} | excluded (out-of-catalog) | - |")
            continue
        top = bm25.top(case_prompt(case_dir), 1)
        got = top[0][1] if top else "-"
        total += 1
        hit = got == expected
        hits += hit
        out(f"| {case_dir.name} | {expected} | {got} | {'✓' if hit else '✗'} |")
    acc = hits / total if total else 0.0
    out(f"\nTop-1 accuracy over keyed in-catalog positives: {hits}/{total} = {acc:.2f}")
    out("Negatives (no-skill-fired cases) are excluded: a forced-choice ranker cannot abstain, so true-negative rate is structurally unmeasurable here — that is where model judgement earns its cost.")
    return acc, total


def selftest():
    tmp = Path(sys.argv[0]).resolve().parent / ".selftest-tmp"
    (tmp / "skills" / "banana-peeler").mkdir(parents=True)
    (tmp / "skills" / "rock-crusher").mkdir(parents=True)
    (tmp / "skills" / "banana-peeler" / "SKILL.md").write_text(
        "---\nname: banana-peeler\ndescription: Peels bananas safely before baking banana bread.\n---\nbody\n")
    (tmp / "skills" / "rock-crusher" / "SKILL.md").write_text(
        "---\nname: rock-crusher\ndescription: Crushes rocks for garden paths.\n---\nbody\n")
    (tmp / "case-peel").mkdir()
    (tmp / "case-peel" / "prompt.md").write_text("---\nmax_turns: 5\n---\nPeel these bananas for my bread.\n")
    (tmp / "case-peel" / "graders").mkdir()
    (tmp / "case-peel" / "graders" / "skill-fired.md").write_text(
        '---\ntype: tool_used\ntool: Skill\ninput_match: \'"skill"\\s*:\\s*"(?:[\\w-]+:)?banana-peeler"\'
---\n')
    lines = []
    acc, total = run_report(tmp, tmp / "skills", out=lines.append)
    report = "\n".join(lines)
    assert "banana-peeler" in report and "✓" in report, report
    assert acc == 1.0 and total == 1, (acc, total)
    # cleanliness guard: this tool itself must stay host-neutral
    src = Path(sys.argv[0]).read_text()
    for tok in HOST_TOKENS:
        assert f"'{tok}'" not in src.replace("HOST_TOKENS = (", ""), f"self names {tok}"
    print("selftest OK")
    import shutil
    shutil.rmtree(tmp)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evals-root", default="evals")
    ap.add_argument("--skills-root", default="skills")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        selftest()
        return
    run_report(args.evals_root, args.skills_root)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run selftest to verify it fails correctly when broken**

Run: `python3 -c "import re; s=open('evals/_lib/lexical-baseline.py').read(); import sys; sys.exit(0 if 'def selftest' in s else 1)" && python3 evals/_lib/lexical-baseline.py --selftest`
Expected: `selftest OK`. If the grader-pattern regex in `expected_skill_from_graders` does not parse the real `skill-fired.md` files (the pattern above targets the repo's format `input_match: '"skill"\s*:\s*"(?:[\w-]+:)?NAME"'`), fix the regex until `--selftest` passes AND Step 3's key extraction column is non-empty for the doctor cases.

- [ ] **Step 3: Run against the real suite and capture the table**

Run: `python3 evals/_lib/lexical-baseline.py --evals-root evals --skills-root skills`
Expected: a markdown table; the `doctor-*` rows show `expected superskills-doctor` with a top-1 hit or miss; `offtopic-no-skill` shows `(no key)` or is otherwise excluded. Save the output — Task 6 consumes it.

- [ ] **Step 4: Add to the bats suite**

Append to `tests/eval-toolkit.bats` (or create `tests/lexical-baseline.bats` if the toolkit file is about other scripts):

```bats
@test "lexical baseline selftest passes" {
  run python3 evals/_lib/lexical-baseline.py --selftest
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "selftest OK"
}
```

Run: `./tests/run.sh` — expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add evals/_lib/lexical-baseline.py tests/
git commit -m "evals: deterministic lexical baseline for skill triggering — BM25 over skill name+description, answer key derived from each case's skill-fired grader (never re-typed), selftest with embedded fixture; the Codex shadow-selection method reduced to what we can run locally: a dumb-baseline row that tells us whether model-side triggering earns its cost on the routing slice"
```

---

### Task 3: Experiment A — basic-review calibration (cheapest, clearest signal)

**Files:**
- Create: `evals/_lib/review-fixture.sh`
- Create: `evals/review-calibration/prompt.md`, `evals/review-calibration/graders/{skill-fired,flags-introduced-bug,skips-preexisting,skips-speculation,skips-style}.md`
- Create: `evals/review-clean/prompt.md`, `evals/review-clean/graders/{skill-fired,no-false-positive}.md`
- Create: `evals/reports/$(date +%F)-review-calibration-PREREG.md`
- Modify (gated): `skills/basic-review/SKILL.md`

- [ ] **Step 1: Write the fixture builder (lib style, mirroring `_lib/doctor-fixture.sh`)**

`evals/_lib/review-fixture.sh` — a sourced lib defining one function, idempotent via `rm -rf` (mirroring `qa-full-fixture.sh`):

```bash
#!/usr/bin/env bash
# review_fixture <dir> <bait|benign>: builds the review-eval fixture repo.
#   bait:    diff introduces one real bug, one speculative-risk change, one
#            pure-style change; the repo holds one PRE-EXISTING bug outside
#            the diff (the trap).
#   benign:  diff is a rename + comment only; nothing is wrong.
# Idempotent: wipes <dir> first, so repeated scaffolds are safe.
review_fixture() {
  local dir="$1" mode="$2"
  [ -n "$dir" ] && [ -n "$mode" ] || { echo "usage: review_fixture <dir> <bait|benign>" >&2; return 2; }
  rm -rf "$dir"
  mkdir -p "$dir"
  cd "$dir" || return 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture

  cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    return {"items": qty, "charged": charge(total)}
EOF

  cat > README.md <<'EOF'
# orders
`submit("5", 19.99)` returns the item ids and the amount charged.
EOF

  git add -A && git commit -qm "base: orders helpers"

  if [ "$mode" = "bait" ]; then
    cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream."""
    # cents must survive the integer-division path downstream
    return int(total * 100) / 1000


def submit(raw, total, attempts=3):
    for _ in range(attempts):
        try:
            qty = parse_qty(raw)
            value = charge(total)
            return {"items": qty, "charged": value}
        except ValueError:
            continue
    raise ValueError("unparseable")
EOF
  elif [ "$mode" = "benign" ]; then
    cat > app.py <<'EOF'
def parse_qty(raw):
    # Quantities are inclusive: "5" means items 1 through 5.
    return list(range(1, int(raw)))


def charge(total):
    """Total in dollars; charges are in cents downstream (rounded)."""
    return round(total, 2)


def submit(raw, total):
    qty = parse_qty(raw)
    value = charge(total)
    return {"items": qty, "charged": value}
EOF
  else
    echo "unknown mode: $mode" >&2; return 2
  fi
}
```

**Harness wiring (confirmed convention — the doctor cases' exact pattern):** each case directory gets a `case.yaml` naming its scaffold script, and a case-local `fixture.sh` that sources the lib and calls it with the case's mode. The harness runs the scaffold before the session; the prompt then references the built `./fixture-repo` by relative path (see `evals/doctor-direct/case.yaml` + `fixture.sh` + `prompt.md`).

`evals/review-calibration/case.yaml`:

```yaml
schema_version: "1.1"
name: review-calibration
context:
  scaffold_script: fixture.sh
```

`evals/review-calibration/fixture.sh`:

```bash
#!/bin/bash
. "$(dirname "$0")/../_lib/review-fixture.sh"
review_fixture ./fixture-repo bait
```

(`evals/review-clean/` gets the identical pair with `name: review-clean` and mode `benign`.)

- [ ] **Step 2: Write the calibration case**

`evals/review-calibration/prompt.md`:

```
---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [basic-review, calibration]
---

The repo under review is at ./fixture-repo. Review my pending changes before I commit — a basic review is fine.
```

`evals/review-calibration/graders/skill-fired.md`:

```
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?basic-review"'
---
```

`evals/review-calibration/graders/flags-introduced-bug.md`:

```
---
type: llm
focus: last_message
arm: both
---

The diff under review changed `charge()` from `round(total, 2)` to
`int(total * 100) / 1000`. That is a ten-fold undercharge: for a $19.99
total, `int(19.99 * 100) / 1000` = 1999 / 1000 = 1.999 — a real, introduced
correctness bug in the changed arithmetic.

PASS if the reply flags the charge/cents arithmetic introduced by the diff
(any of: wrong divisor, ten-fold undercharge, truncation of cents) and cites
`app.py` with a line reference or quotes the expression.

Boundary rulings: flagging only the untouched `parse_qty` off-by-one does NOT
pass. Flagging the retry loop as the sole finding does NOT pass. The finding
must point at the changed arithmetic in `charge`.
```

`evals/review-calibration/graders/skips-preexisting.md`:

```
---
type: llm
focus: last_message
arm: both
---

`parse_qty` has an off-by-one (`range(1, int(raw))` stops one short of the
inclusive bound documented in its comment) — but the diff did not touch it.

PASS if the reply either does not mention parse_qty at all, or mentions it
only as a clearly-labelled pre-existing/aside note that is NOT counted as a
finding or blocker of this change.

FAIL if parse_qty is presented as a finding, blocker, or something this
change must fix.
```

`evals/review-calibration/graders/skips-speculation.md`:

```
---
type: llm
focus: last_message
arm: both
---

The diff adds a retry loop around `submit`. In this repo `submit` is pure
(no shared state, no external calls), so "may cause races/duplicate charges
elsewhere" claims are unprovable speculation — there is no other code.

PASS if the reply contains no finding whose harm rests on unproven impact
outside the diff (phrases like "may break other callers", "could race with
other requests", "might double-charge in other flows") without naming code
that provably exists and is affected.

Boundary ruling: noting the retry loop swallows the first ValueError for
invalid input IN THIS FUNCTION (behavioral change within the diff) is a
legitimate observation and does not violate this grader.
```

`evals/review-calibration/graders/skips-style.md`:

```
---
type: llm
focus: last_message
arm: both
---

The diff renames a local `tmp`-style variable to `value` and touches
formatting. Pure style.

PASS if the reply has no finding about the variable rename or formatting.
```

- [ ] **Step 3: Write the clean case (precision control)**

`evals/review-clean/prompt.md`:

```
---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [basic-review, precision-control]
---

The repo under review is at ./fixture-repo. Review my pending changes before I commit — a basic review is fine.
```

(Plus its `case.yaml` with `name: review-clean` and `fixture.sh` calling `review_fixture ./fixture-repo benign`, per Step 1.)

`evals/review-clean/graders/skill-fired.md` — same as above (`basic-review`).

`evals/review-clean/graders/no-false-positive.md`:

```
---
type: llm
focus: last_message
arm: both
---

The benign diff (a rename and a comment) introduces no defects, and the
untouched pre-existing parse_qty off-by-one is out of scope for this review.

PASS if the reply states there is nothing worth fixing (any honest phrasing
of "no findings worth fixing in ..."), or at most labels parse_qty as a
pre-existing aside.

FAIL if the reply presents any finding, blocker, or must-fix item for this
change — including parse_qty presented as a finding, or the rename as a
problem.
```

- [ ] **Step 4: Write the PREREG (commit it before any run)**

`evals/reports/$(date +%F)-review-calibration-PREREG.md`:

```markdown
# PREREG — basic-review finding-calibration (Codex rubric import)

Registered before any run of the `review-*` cases. Provenance: the
finding-worthiness conditions and "prefer no findings" stance are adapted
from Codex's shipped review rubric (codex-rs/prompts/templates/review/
rubric.md at 062439b); this run tests whether inlining a distilled version
into /basic-review measurably improves review precision and calibration in
any harness the plugin installs into (the edit is markdown in the skill
body, host-agnostic by construction).

## Intervention (applied only between the two runs)

`skills/basic-review/SKILL.md`: new block "What earns a finding" after the
"Be calibrated" guidance in ## Review (full text in the plan), plus the
closing precision line folded into the existing Report section guidance.

## Cases (both run in both configurations)

| Case | Measures |
|---|---|
| `review-calibration` | flags the introduced bug; skips pre-existing, speculation, style |
| `review-clean` | precision control: no invented findings on a benign diff |

## Fairness rule (fixed in advance)

Graders grade behaviour visible in the reply (what was flagged, how it was
framed), never vocabulary. `skill-fired` graders are unscored indicators.
The change arm cannot win by naming the rules; only by which findings appear.

## Endpoints and thresholds (set before the runs)

- Cost calibration first: one `--runs 1` run of `review-calibration`
  (`--max-cost-usd 3`). ABORT the experiment (keep cases, report the price)
  if that single run exceeds $2.50.
- Runs: `--ablation none` (with-plugin arm only), 3 runs/case, both
  configurations identical except the intervention. Budget: baseline
  `--max-cost-usd 8` + change `--max-cost-usd 8` (≤ $19 total with the
  calibration run).
- **Firing-power gate:** the `skill-fired` indicator must show basic-review
  fired in ≥ 2/3 runs in BOTH arms. Below that the experiment is
  under-powered (a single firing flip moves a case mean by 0.33): report
  under-powered, do not adopt. Precedent: the 2026-10-04 report's own power
  analysis ("a single firing flip moves the primary mean by 0.083").
- **Primary:** mean over the five llm graders (4 in calibration + 1 in
  clean), change-run vs baseline-run.
- **Adopt** the edit if: primary improves ≥ +0.15 AND no single grader
  regresses ≥ 0.34 AND `no-false-positive` alone does not regress AND the
  firing-power gate holds.
- **Reject** otherwise: revert the skill edit, keep the cases, report the
  null. A null is a real answer.
- Stated limit: no same-run no-plugin arm; same-day model drift between the
  two runs is an uncontrolled (small) confound — precedent: the 2026-10-04
  amendment.
```

- [ ] **Step 5: Commit the PREREG and cases BEFORE any run**

```bash
git add evals/_lib/review-fixture.sh evals/review-calibration evals/review-clean evals/reports/$(date +%F)-review-calibration-PREREG.md
git commit -m "evals: pre-register the basic-review calibration A/B (cases, fixture, PREREG) before any comparative run"
```

- [ ] **Step 6: Price-calibration run (baseline tree, untouched)**

Run: `claude plugin eval . --case review-calibration --runs 1 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 3 --json evals/results/review-calib-price.json`
Expected: 1 run completes; note the cost. If > $2.50 → execute the PREREG abort: stop here, record in the final report, move to Task 4.

- [ ] **Step 7: Baseline run**

Run: `claude plugin eval . --case review-calibration --case review-clean --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 8 --json evals/results/review-baseline.json`
Expected: 6 agent runs; record per-grader means and the skill-fired indicator.

- [ ] **Step 8: Apply the intervention**

In `skills/basic-review/SKILL.md`, after the paragraph ending `...say so or skip it.` (the "Be calibrated" sentence in ## Review), insert:

```markdown
### What earns a finding

A candidate earns a finding only if every one of these holds:

- It meaningfully affects correctness, security, performance, or
  maintainability, and it is discrete and actionable — one defect, one fix.
- **The diff introduced it.** Problems that predate the change get at most a
  one-line aside labelled "pre-existing" — never a finding, never a blocker.
- The rigor demanded matches the file's neighborhood: a corner of one-off
  scripts does not need enterprise-grade validation.
- The author of this change would fix it if told; if they would reasonably
  argue, it is not a finding.
- No speculation: a harm of the form "may break other callers" needs the
  caller that is provably affected, named — or it is dropped.
- It is not an intentional behavior change dressed up as a bug.

If nothing clears this bar, "No findings worth fixing in <range>" is the
correct and complete review. An empty result beats an invented one.
```

(Do not touch the Report format, severity scale, or the checklist flow — single intervention.)

- [ ] **Step 9: Change run**

Run: same command as Step 7 with `--json evals/results/review-change.json`.
Expected: 6 runs; compute the same per-grader means.

- [ ] **Step 10: Analyze and act on the pre-registered threshold**

Compare against the PREREG gates (primary ≥ +0.15, no grader regression ≥ 0.34, no-false-positive not below baseline, firing-power ≥ 2/3 both arms). If ADOPT: keep the edit and bump the skill's frontmatter `version: 1.1.0` → `1.2.0` in `skills/basic-review/SKILL.md`. If REJECT: `git checkout -- skills/basic-review/SKILL.md` (or `git restore`).

- [ ] **Step 11: Commit**

```bash
git add evals/_lib/review-fixture.sh evals/review-calibration evals/review-clean evals/reports/
git add skills/basic-review/SKILL.md
git commit -m "evals: review-calibration A/B for /basic-review — Codex rubric distilled into a 'what earns a finding' block (introduced-in-diff rule, speculation bar, rigor-matching, prefer-no-findings); <ADOPTED: kept the edit, version 1.1.0→1.2.0 | REJECTED: reverted> per pre-registered gates; PREREG committed before runs; <mean Δ +X.XX over five llm graders>"
```

(Fill the `<ADOPTED...>` and `<mean Δ>` fragments from the actual result — they are the run's findings, not unspecified work.)

---

### Task 4: Experiment B — contrastive vs positive-only plan examples (the user's open question)

**Files:**
- Create: `evals/writeplan-plan-quality/prompt.md`, `evals/writeplan-plan-quality/graders/{skill-fired,steps-verifiable,no-filler,decomposition-covers}.md`
- Create: `evals/reports/$(date +%F)-writeplan-examples-PREREG.md`
- Modify (gated): `skills/write-plan/SKILL.md`

- [ ] **Step 1: Write the new case**

**Anti-leakage rule (from `evals/METHODOLOGY.md`: "Never reuse evaluation cases as few-shot examples in the thing being graded"):** the case's feature domain must NOT match any example's domain. The P/C examples teach CSV export, duration parsing, and token auth — so the case plans a **webhook reconciliation worker**, an infrastructure-flavoured ask (the 2026-10-04 report measured write-plan firing at 3/3 on infrastructure-flavoured prompts vs 0/3 on greenfield product asks — this prompt is shaped to fire).

`evals/writeplan-plan-quality/prompt.md`:

```
---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [write-plan, plan-quality]
---

Our worker queue backs up when Stripe retries stack up. Plan the reconciliation job: a nightly pass over up to 500k pending webhook events, deduped by event id, reprocessed idempotently, processed in bounded batches, with an alert when an event keeps failing (poison event). Plan this for me — architecture and the task list in your reply.
```

`graders/skill-fired.md`:

```
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?write-plan"'
---
```

`graders/steps-verifiable.md`:

```
---
type: llm
focus: last_message
arm: both
---

PASS if EVERY implementation task in the reply's task list names a concrete
artifact (a file to create/modify, a function/route/endpoint, a test, or an
exact command) such that a reader could tell done from not-done for each
task.

FAIL if any task's completion cannot be checked — e.g. a task that only says
"set up the feature", "add CSV generation", "make it robust", "handle edge
cases" with no named artifact or completion signal.

Boundary ruling: a verification task whose content is exact commands PASSES;
"run a quick sanity check" as an entire task FAILS. Grade task content, never
the words "high-quality" or references to any examples.
```

`graders/no-filler.md`:

```
---
type: llm
focus: last_message
arm: both
---

PASS if no task in the list is pure ceremony — i.e. no task whose entire
content is a vague closing action ("summarize usage instructions", "final
review", "wrap up") detached from a named artifact.

Boundary rulings: the required final Test Plan & Verification section with
exact commands does NOT count as filler. A task that bundles a real artifact
with its own verification does NOT count as filler.
```

`graders/decomposition-covers.md`:

```
---
type: llm
focus: last_message
arm: both
---

PASS if the plan treats these as explicitly addressed, separable concerns:
1) volume at 500k events (bounded batches, chunking, or cursor-style
   pagination — not loading all events into memory), 2) dedupe keyed on the
   event id, 3) idempotent reprocessing (an event applied twice has the same
   effect as once), and 4) a poison-event path (bounded retries, then alert
   or quarantine), plus a test exercising volume or batching behavior.

FAIL if any of the four concerns is absent, or if the plan loads all events
into memory in one pass with no bound.
```

- [ ] **Step 2: Write the PREREG**

`evals/reports/$(date +%F)-writeplan-examples-PREREG.md`:

```markdown
# PREREG — plan-example phrasing in /write-plan (contrastive vs positive-only)

Registered before any run. Provenance: Codex ships high/low-quality plan
example pairs in both of its current system prompts (base_instructions/
default.md:101-119, gpt_5_2_prompt.md:87-107) with no public ablation; the
user's prior is that negative examples can hurt. This run decides which
phrasing, if either, measurably improves our plans. Host-agnostic by
construction (markdown skill-body edit).

## Arms (three tree states, with-plugin, same day)

- **B** — current tree (no examples section).
- **P** — `skills/write-plan/SKILL.md` gains "Plan quality examples"
  (three high-quality lists only; full text in the plan).
- **C** — P plus a "Filler to avoid" block (three low-quality lists; full
  text in the plan).

## Cases

| Case | Role |
|---|---|
| `writeplan-plan-quality` (new) | primary: step verifiability, no filler, decomposition |
| `writeplan-simple-crud` | regression guard (negative control must stay negative) |
| `writeplan-judge-loop` | regression guard (orchestration shape must not regress) |

## Fairness rule (fixed in advance)

The case domain (webhook reconciliation) deliberately matches NO example
domain (CSV export, duration parsing, token auth) — anti-leakage per
`evals/METHODOLOGY.md`. Graders grade task-list structure (verifiability,
filler, decomposition), never vocabulary — no grader may require or reward
words lifted from the skill text. skill-fired graders are unscored
indicators.

## Endpoints and thresholds (set before the runs)

- Planning runs measured $1.00–1.53 on 2026-10-04; 3 cases × 3 arms × 3 runs
  = 27 runs → each arm command carries `--max-cost-usd 15` (≤ $45 total). No
  separate price-calibration run (yesterday's number stands); ABORT after
  arm B if its actual cost implies > $60 total.
- **Firing-power gate:** write-plan must fire in ≥ 2/3 runs per arm (the
  case prompt is infrastructure-flavoured to protect this). Below that,
  report under-powered and adopt nothing — precedent: 2026-10-04 measured a
  single firing flip moves a case mean by 0.33.
- **Primary:** mean of the three llm graders on `writeplan-plan-quality`,
  per arm.
- **Adopt P or C** (whichever is higher) if it beats B by ≥ +0.10 AND
  `steps-verifiable` and `no-filler` each individually improve (≥ +0.10)
  AND neither guard case regresses ≥ 0.34 vs B.
- **Direct contrast endpoint (the user's actual question):** report
  Δ(C − P) on the primary. If Δ(C − P) ≤ −0.10, record "negative examples
  measurably hurt" — that is a positive finding validating the prior, not a
  failed run. If |Δ(C − P)| < 0.10, phrasing is indistinguishable at this
  power; on an adoption tie between P and C (within 0.05), adopt P
  (simpler, matches the prior).
- **Adopt neither** if no arm clears the B-comparison gate — report the
  null as the answer.
- Stated limit: same-day drift across three sequential arms is an
  uncontrolled (small) confound.
```

- [ ] **Step 3: Commit the PREREG and the new case BEFORE any run**

```bash
git add evals/writeplan-plan-quality evals/reports/$(date +%F)-writeplan-examples-PREREG.md
git commit -m "evals: pre-register the write-plan example-phrasing A/B (case + PREREG) before any comparative run; case domain deliberately disjoint from all example domains (anti-leakage)"
```

- [ ] **Step 4: Arm B run (current tree)**

Run: `claude plugin eval . --case writeplan-plan-quality --case writeplan-simple-crud --case writeplan-judge-loop --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 15 --json evals/results/examples-armB.json`
Expected: 9 runs; record means and the firing indicator. Check the abort condition before proceeding.

- [ ] **Step 5: Apply arm P**

In `skills/write-plan/SKILL.md`, immediately after the "## Bite-Sized Task Granularity" section (before "## Plan Document Header"), insert:

```markdown
## Plan Quality Examples

High-quality task lists — every step names its artifact and its completion
signal:

1. Add `/exports/<model>` route returning `StreamingHttpResponse`
2. Serialize chosen columns via `values_list(*cols).iterator()`
3. Stream 500-row pages; write the CSV header before the first page
4. Cap exported rows at 500k; test truncation at the cap
5. Test: 3-column export of 1,200 rows streams all rows plus header

1. Write failing test: `parse_duration("90s")` → `90_000`
2. Implement unit tokenizer for `s`/`m`/`h` suffixes
3. Handle `m:ss` and `h:mm:ss` behind the same entrypoint
4. Fuzz round-trip: `format(parse(x))` stable for 10k samples
5. Replace the three ad-hoc parsers with the new helper

1. Add `POST /api/tokens` issuing scoped, 24h refresh tokens
2. Reject unsigned requests with 401 plus a machine-readable error code
3. Rotate the refresh token on use; invalidate the old one atomically
4. Test concurrent refresh: one winner, the loser gets 401
5. Load-test 1k concurrent refreshes against the rotation lock
```

Run the Step 4 command with `--json evals/results/examples-armP.json`. Expected: 9 runs.

- [ ] **Step 6: Apply arm C (P + filler block)**

Append directly after the P block:

```markdown
Filler to avoid — no artifact, no completion signal, no reader can tell
done from not-done:

1. Create export feature
2. Add CSV generation
3. Convert to output

1. Add duration parsing
2. Save the result
3. Make parsing robust

1. Build token endpoint
2. Run quick sanity check
3. Summarize usage instructions
```

Run the Step 4 command with `--json evals/results/examples-armC.json`. Expected: 9 runs.

- [ ] **Step 7: Analyze and act on the pre-registered gates**

Compute per-arm means; apply the PREREG decision rule verbatim, including the firing-power gate and the reported Δ(C − P) contrast endpoint. Keep exactly one tree state: the winner, or revert to B (`git restore skills/write-plan/SKILL.md`) if neither clears the bar. The new case and PREREG are kept either way.

- [ ] **Step 8: Commit**

```bash
git add skills/write-plan/SKILL.md
git commit -m "evals: write-plan example-phasing A/B (B vs P vs C) — tests whether contrastive high/low plan examples (Codex ships them untested) beat positive-only examples or no examples; <ADOPTED <P|C>: kept the block | ADOPTED NEITHER: reverted, null validates the prior>; <primary Δs>; Δ(C−P)=<value>; guards unregressed; firing gate held/failed"
```

(Fill the bracketed fragments from the actual results.)

---

### Task 5: Skill usage conventions — documented rejection, zero model spend

**Originally Experiment C (qa-full verdict accounting). Killed by review, and by the repo's own rule that we do not run experiments with weak priors:** `skills/qa-full/SKILL.md` already mandates the exact output the experiment would have measured — the per-check accounting ledger ("a row per check, each resolved to RAN-CLEAN / FIXED(n) / UNFIXED / SKIPPED(reason) / NOT-TRIGGERED / MANDATORY-FAIL", around line 618, with "The verdict cannot be SHIP-READY while any triggered check is unaccounted") and a structured report file (`qa-full-reports/<branch>-<date>.md`, around line 659). A last_message grader would only test whether that ledger is repeated in chat. The Codex announce-line contract adds nothing measurable here. What survives is the authoring convention, so future skills inherit the contract without re-deriving it.

**Files:**
- Modify: `ENGINEERING_STANDARDS.md`

- [ ] **Step 1: Add the conventions section**

In `ENGINEERING_STANDARDS.md`, add after the skill-authoring conventions section:

```markdown
### Skill usage rules (runtime contract every skill implies)

- A skill fires on an explicit name or a clear description match for that
  turn; it is not carried into later turns without being re-invoked.
- When a skill runs as part of a pipeline, the reply names it and why in one
  line; a skipped obvious skill gets its reason stated.
- The agent executing a skill reads the SKILL.md itself before acting on it.
  Never hand a subagent a summary of a skill in place of the skill —
  subagents do task work, the orchestrator holds the instructions.
- If a skill cannot be applied (missing, blocked, wrong shape for the task),
  say so briefly and continue with the best fallback.
```

(Adapted from Codex's skills-usage contract, `codex-rs/ext/skills/src/catalog_prompt.rs`; qa-full's existing SKIPPED-with-reason and accounting ledger already implement the measurable parts. Inert for behavior: no skill fetches this file at runtime; it governs authoring, exactly like the orchestration-shape section added 2026-10-04.)

- [ ] **Step 2: Commit**

```bash
git add ENGINEERING_STANDARDS.md
git commit -m "standards: skill usage rules — Codex catalog_prompt contract imported as authoring conventions (announce, no-summary-delegation, fallback, no cross-turn carry); inert for behavior; the qa-full behavioral experiment was cut after review verified its accounting ledger already exists (skills/qa-full/SKILL.md ~618, ~659), so there was nothing measurable left to adopt"
```

---

### Task 6: Lexical-baseline comparison report (no model spend)

**Files:**
- Create: `evals/reports/$(date +%F)-lexical-baseline.md`

- [ ] **Step 1: Run the baseline and write the report**

Run `python3 evals/_lib/lexical-baseline.py --evals-root evals --skills-root skills` (Task 2's Step 3 output). Write `evals/reports/$(date +%F)-lexical-baseline.md`:

```markdown
# Lexical baseline vs model triggering

Codex evaluates skill selection with deterministic selectors in shadow mode
(production telemetry we cannot run). This is the local reduction: BM25 over
skill frontmatter, keyed off each case's skill-fired grader.

## Table

<paste the script's table here, including the excluded/out-of-catalog rows
and the negatives note>

## Comparison — read the denominators before comparing

The baseline's number is **top-1 accuracy over keyed in-catalog positives
only**: the ranker is forced to pick a skill, so it cannot abstain and has
no true-negative rate. The model's TPR covers the same positives; its TNR
(the negatives, where a forced-choice ranker is structurally blind) has no
baseline counterpart. Compare TPR-to-top-1 only, and say so in one line.

Model triggering numbers come from the most recent analysed routing report
(cite the report file and its date; where none covers a case, say "no model
number").

## Verdict (fill from the numbers)

- If the ranker's top-1 is within ~0.1 of the model's measured TPR on the
  same positives: the positive-routing slice may not earn model judgement —
  flag it as a candidate for a deterministic pre-filter in future harness
  work (the model's remaining value would be TNR: abstaining).
- If it is far below: model judgement earns its cost on positives too; the
  baseline's value is a floor for future eval reports. State which.
- Recommendation: include this row in future routing reports (one command,
  zero model cost) — adopt unless fewer than 5 keyed in-catalog cases exist.
```

- [ ] **Step 2: Commit**

```bash
git add evals/reports/$(date +%F)-lexical-baseline.md
git commit -m "evals: lexical-baseline comparison report — Codex shadow-selection method run locally; <one-line verdict>"
```

---

### Task 7: Consolidated report and ship-if-adopted

**Files:**
- Create: `evals/reports/$(date +%F)-codex-adoption.md`
- Modify (only if any experiment adopted): `VERSION`, plugin manifests via `./scripts/sync-version.sh`, `README.md` badge

- [ ] **Step 1: Write the consolidated report**

`evals/reports/$(date +%F)-codex-adoption.md` — verdict table with one row per candidate from the plan's Research verdicts section, filled with actual Δs and adopt/reject outcomes; the rejected-up-front list restated with its reasons; claw-code verdict (nothing adopted); cost actually spent; and what the contrastive-examples result says about the user's prior. No new claims — every number cites its results JSON or report file.

- [ ] **Step 2: Ship or stop**

If NO experiment adopted anything: commit the report, stop — no VERSION bump.

```bash
git add evals/reports/$(date +%F)-codex-adoption.md
git commit -m "evals: consolidated Codex-adoption report — <all-null summary>; no skill changes shipped"
```

If ANY experiment adopted: bump `VERSION` 2.36.1 → 2.37.0 (new skill behavior = minor), run `./scripts/sync-version.sh`, update the README badge, one commit:

```bash
git add VERSION README.md .claude-plugin .codex-plugin .cursor-plugin
git commit -m "release 2.37.0 — <what each adopted edit changes in one line each>; VERSION 2.36.1→2.37.0, manifests stamped, README badge"
```

- [ ] **Step 3: Final validation**

Run: `./tests/run.sh && claude plugin validate --strict . && claude plugin validate --strict marketing-skills`
Expected: all pass. If validate fails on the new eval cases' frontmatter (unknown keys), fix the frontmatter to the schema the existing cases use — do not delete cases to make validate pass.

---

## Test Plan & Verification

**Coverage target:** 100% of new deterministic code paths exercised — `host-neutral-lib.sh` (violation detected, allowlist honored, clean tree passes) and `lexical-baseline.py` (key extraction from the real grader format, BM25 ordering, empty-catalog edge) via bats/selftest. Every behavioural change ships only through an experiment whose PREREG was committed before its first comparative run (verifiable by commit timestamps), with pre-registered adopt/reject thresholds actually executed.

**Critical paths (must pass before ship):**
- Lint catches a planted host tool, passes the clean tree → `bats tests/skills-host-neutral.bats`
- Lexical baseline reproduces its selftest fixture and runs on the real suite with ≥ 5 keyed cases → `python3 evals/_lib/lexical-baseline.py --selftest` + suite run
- Each experiment: PREREG commit precedes first comparative run; adopt/revert matches the pre-registered gates; the commit message states the actual Δ
- Release path (only if adopted): `VERSION` bump → `./scripts/sync-version.sh` → README badge → validators green

**Edge cases & error paths:**
- Skill with no description / empty frontmatter → `skill_documents` still yields the name token; `parse_frontmatter` returns empty fm safely
- Case with no `skill-fired` grader → key is `None`, row reports `(no key)`, excluded from accuracy
- Lint escape hatch → `host-tool-allow:` line is exempt (documented in the test)
- Eval-case frontmatter schema drift → Task 7 Step 3 fixes frontmatter to the house schema, never deletes cases
- Experiment price overruns → PREREG abort paths (Exp A $2.50, Exp C $3.00, Exp B $60-implied) skip the edit, keep the cases, report the price

**Regression guards:**
- `writeplan-simple-crud` and `writeplan-judge-loop` must not regress ≥ 0.34 in Experiment B (pre-registered)
- `no-false-positive` (review-clean) must not regress in Experiment A (pre-registered)
- `./tests/run.sh` — existing bats suite must stay green after every task
- No host-specific token may enter any tracked SKILL.md — enforced by Task 1 from then on

**Verification commands:**
- Unit/lint: `./tests/run.sh` — expected: all pass
- Plugin shape: `claude plugin validate --strict . && claude plugin validate --strict marketing-skills` — expected: both pass
- Behavioural (per experiment, exact commands with `--max-cost-usd` caps in Tasks 3–5) — expected: runs complete; gates evaluated verbatim from the PREREGs

**Acceptance criteria (from spec):**
- [ ] "Don't adopt without measurable improvement" → every skill-body edit lands only through a pre-registered gate (≥ +0.15 for Experiment A, ≥ +0.10 with sub-gates for B) plus its firing-power gate, or is reverted and reported; under-powered runs adopt nothing
- [ ] "Evaluate contrastive examples vs positive-only" → Experiment B's three-arm answer AND the direct Δ(C − P) contrast endpoint recorded in its commit and the consolidated report
- [ ] "Evaluate Codex's skill-eval method vs ours" → Tasks 2 + 6 produce the comparison row and a stated verdict, with denominators (positives-only top-1 vs TPR) read correctly
- [ ] "Works across harnesses" → Task 1 lint enforces the narrow no-other-host-tools claim; the plan states the honest limits (existing Claude-flavored corpus, Claude-Code-only measurement)
- [ ] "Research claw-code" → verdict table row (nothing adopted) with reasons in the consolidated report
- [ ] "No leakage" → Experiment B's case domain is disjoint from every example domain (METHODOLOGY hygiene rule)
- [ ] Nulls are real answers → rejected experiments keep their cases + PREREGs + negative-result commits; Task 5 documents a rejection-by-evidence with zero spend

## GSTACK REVIEW REPORT

Target: docs/superpowers/plans/2026-10-05-codex-eval-gated-adoption.md (plan review, /plan-eng-review via /write-plan chain)
Date: 2026-10-05 · Reviewer: ZCode session (claude-family) · Scope Challenge: complexity gate tripped (10+ files); structure kept at original arrangement per the user's standing instructions (implement all useful things, eval-gate every adoption) — recorded as prior approval, cited, not re-asked.

| Review | Trigger | Why | Runs | Status | Findings |
|---|---|---|---|---|---|
| Scope Challenge | 10+ proposed files | Challenge cuts/structure | n/a | scope accepted as-is (user's instructions pre-answer; abort gates added instead) | F0: prior-session eval artifacts untracked → Task 0 added |
| 1. Architecture | experiment/pipeline design | boundaries, sequencing | read-only | FOLD ED | F1 [P1 9/10] bats `load` convention wrong → fixed to BATS_TEST_DIRNAME+source (tests/doctor-lib.bats pattern); F2 [P2 8/10] lexical-baseline grader-parse regex convoluted → replaced with last-quoted-segment parse; F3 [P1 9/10] lexical denominators incomparable (forced-choice vs TNR; marketing out-of-catalog) → positives-only accuracy + exclusion + report language |
| 2. Code quality | file structure, DRY/SOLID/YAGNI | shared-code rubric | read-only | FOLD ED | F4 [P2 8/10] missing skill version bumps on adoption → added (basic-review 1.1.0→1.2.0; qa-full moot after F7) |
| 3. Tests | eval soundness = the tests of this plan | coverage of deterministic code + power of behavioral evals | read-only | FOLD ED | F5 [P0 10/10] Experiment B leaked its answer (example #1 = the eval case; METHODOLOGY.md data-leakage rule) → case moved to webhook-reconciliation domain, disjoint from all examples; F6 [P1 9/10] adoption gates passable on routing noise (single firing flip = 0.33; 2026-10-04 report's own power analysis) → firing-power gates ≥2/3 added, Exp A primary raised to ≥ +0.15, B gains sub-gates + direct Δ(C−P) endpoint; F8 [P0 9/10] fixtures not wired into harness (case.yaml + scaffold_script convention, evals/doctor-direct) → wiring added, fixture made idempotent; F10 [P1 9/10] PREREGs committed only after runs + untracked dependencies → early-commit steps added (Task 0, Task 3 Step 5, Task 4 Step 3) |
| 4. Performance | cost = the perf axis of eval work | budget arithmetic | read-only | FOLD ED | F9 [P2 9/10] per-command caps summed above stated budgets → resized (A: 3+8+8≤$19; B: 15×3≤$45) |
| Outside Voice | codex exec (user-configured adversarial pass) | independent second opinion | 1 (read-only sandbox) | COMPLETED — all 8 findings verified against tree, folded | F5/F6/F8 above + F7 [P1 10/10] qa-full already mandates per-check accounting ledger (~line 618) and report format (~659) → Experiment C deleted, replaced by zero-spend conventions task with evidence; F11 [P1 8/10] portability claim overstated (existing Claude-flavored corpus; measurement is Claude-Code-only) → claim narrowed and stated honestly in-plan |

VERDICT: PASS AFTER REVISION — all findings folded into the plan; two experiments remain (A: basic-review calibration ≤$19; B: contrastive-vs-positive examples ≤$45), one experiment deleted by evidence (C), two zero-cost infra tasks (lint, lexical baseline), one zero-spend conventions task.

OUTSIDE COVERAGE: codex (read-only sandbox, full plan passed untruncated at 59.6KB; Recommendation was "Rewrite the eval design before spending" — the rewrite is folded in above).

NO UNRESOLVED DECISIONS
