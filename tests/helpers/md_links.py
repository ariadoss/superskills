#!/usr/bin/env python3
"""md_links.py <file...> — report relative markdown links that do not resolve.

Resolves each `[text](path#anchor)` against the linking file's real directory
(following symlinks, so a skill reached through the marketing plugin's shim tree
resolves exactly as it does in place). External links (http, mailto) and pure
in-page anchors are skipped. For a .md target with an anchor, the anchor must
match a heading slug, GitHub-style. Prints one `file:line: link -> reason` per
failure and exits 1 if any.
"""
import functools
import os
import re
import sys

LINK = re.compile(r"\]\(([^)\s]+)\)")


def slug(heading):
    h = heading.strip().lower()
    h = re.sub(r"[^\w\s-]", "", h)
    return re.sub(r"\s", "-", h)


def prose_lines(path):
    """(line number, line) for every line outside a ``` fence."""
    in_fence = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for n, line in enumerate(fh, 1):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
            elif not in_fence:
                yield n, line


@functools.lru_cache(maxsize=None)
def anchors(path):
    return {slug(line.lstrip("#")) for _, line in prose_lines(path) if line.startswith("#")}


def check(path):
    bad = []
    base = os.path.dirname(os.path.realpath(path))
    for n, line in prose_lines(path):
        for target in LINK.findall(line):
            if re.match(r"^[a-z]+:", target) or target.startswith("#"):
                continue
            rel, _, anchor = target.partition("#")
            full = os.path.normpath(os.path.join(base, rel))
            if not os.path.exists(full):
                bad.append(f"{path}:{n}: {target} -> missing {rel}")
            elif anchor and full.endswith(".md") and anchor not in anchors(full):
                bad.append(f"{path}:{n}: {target} -> no heading #{anchor}")
    return bad


def main(argv):
    bad = []
    for p in argv[1:]:
        bad += check(p)
    for b in bad:
        print(b)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
