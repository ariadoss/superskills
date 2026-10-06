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
        '---\ntype: tool_used\ntool: Skill\ninput_match: \'"skill"\\s*:\\s*"(?:[\\w-]+:)?banana-peeler"\'\n---\n')
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
