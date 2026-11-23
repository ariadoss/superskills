#!/usr/bin/env python3
"""Score description overlap between skills, or between a lesson and each skill.

Usage:
  skill_overlap.py pairs <repo_root> [--threshold 0.15]
  skill_overlap.py query <repo_root> "<lesson text>" [--top 3]
  skill_overlap.py query <repo_root> --stdin [--top 3]   (lesson text on stdin)
Output is tab separated. pairs prints score, then the two names; query prints name, then score. Scores are token overlap on
description plus triggers (a coarse signal; a human or the model judges the
result). pairs uses Jaccard (default 0.15, calibrated on the 80-skill tree: 0.35 reports nothing there); query uses containment of the lesson's tokens.
"""
import argparse
import re
import sys

sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
from skill_index import load_skills  # noqa: E402

STOP = frozenset(
    "the and for with use when not this that from into your you are can to of in "
    "or on it is as be by an if at skill skills claude code agent agents run runs "
    "asked ask user users also any all one use used using".split()
)


def tokens(text):
    return {w for w in re.findall(r"[a-z][a-z0-9-]{2,}", text.lower()) if w not in STOP}


def skill_tokens(skill):
    return tokens(skill["description"] + " " + skill["triggers"])


def jaccard(a, b):
    union = a | b
    return len(a & b) / len(union) if union else 0.0


def pairs(skills, threshold):
    toks = [(s["name"], skill_tokens(s)) for s in skills]
    out = []
    for i in range(len(toks)):
        for j in range(i + 1, len(toks)):
            score = jaccard(toks[i][1], toks[j][1])
            if score >= threshold:
                out.append((score, toks[i][0], toks[j][0]))
    return sorted(out, reverse=True)


def query(skills, text, top):
    q = tokens(text)
    if not q:
        return []
    scored = [(len(q & skill_tokens(s)) / len(q), s["name"]) for s in skills]
    return sorted((x for x in scored if x[0] > 0), reverse=True)[:top]


def main(argv):
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=["pairs", "query"])
    p.add_argument("root")
    p.add_argument("text", nargs="?")
    p.add_argument("--threshold", type=float, default=0.15)
    p.add_argument("--stdin", action="store_true", help="read the lesson text from stdin")
    p.add_argument("--top", type=int, default=3)
    a = p.parse_args(argv[1:])
    skills = load_skills(a.root)
    if a.mode == "pairs":
        for score, x, y in pairs(skills, a.threshold):
            print(f"{score:.2f}\t{x}\t{y}")
    else:
        text = sys.stdin.read().strip() if a.stdin else a.text
        a.text = text
        if not a.text:
            print("query needs the lesson text", file=sys.stderr)
            return 2
        for score, name in query(skills, a.text, a.top):
            print(f"{name}\t{score:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
