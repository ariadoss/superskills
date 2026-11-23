#!/usr/bin/env python3
"""Give each debrief v2 trace a random id and strip its identifying header.

Usage: anonymise.py --out DIR --map MAPFILE SRC.md [SRC.md ...]

Each SRC file name starts with its fixture, ``private-`` or ``public-``
(real traces are ``<fixture>-<arm>-<run>.md``, controls ``<fixture>-cNN.md``).
For each source the body is written to ``DIR/<id>.md`` with the first line
removed when it is a header: the real traces' ``agent id: ...`` line, which
names run, fixture and arm, or a control's ``SYNTHETIC CONTROL`` marker.
Blank lines left at the top are dropped too, and run ids such as ``r07``
in the body are masked as ``rNN``. ``DIR/fixtures.json`` maps
id -> fixture, the only metadata a grader may see. MAPFILE maps id -> source
path and must live outside the repo and out of every grader's reach.
Standard library only.
"""
import argparse
import json
import os
import re
import secrets
import sys

HEADERS = ("agent id:", "SYNTHETIC CONTROL")
FIXTURES = ("private", "public")


RUN_ID = re.compile(r"\br(0[1-9]|1[0-9]|2[0-9])\b")


def strip_header(text):
    lines = text.splitlines(keepends=True)
    if lines and lines[0].startswith(HEADERS):
        lines = lines[1:]
    while lines and not lines[0].strip():
        lines = lines[1:]
    # A run id such as "r07" inside a path resolves to an arm through the
    # earlier runner notes, so it is masked; nothing graded depends on it.
    return RUN_ID.sub("rNN", "".join(lines))


def fixture_of(path):
    name = os.path.basename(path)
    for f in FIXTURES:
        if name.startswith(f + "-"):
            return f
    raise ValueError(f"{name}: file name must start with private- or public-")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", required=True)
    ap.add_argument("--map", required=True)
    ap.add_argument("src", nargs="+")
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    mapping, fixtures, used = {}, {}, set()
    for src in a.src:
        fx = fixture_of(src)
        tid = secrets.token_hex(4)
        while tid in used:
            tid = secrets.token_hex(4)
        used.add(tid)
        with open(src, encoding="utf-8") as fh:
            body = strip_header(fh.read())
        with open(os.path.join(a.out, tid + ".md"), "w", encoding="utf-8") as fh:
            fh.write(body)
        mapping[tid] = src
        fixtures[tid] = fx
    with open(os.path.join(a.out, "fixtures.json"), "w", encoding="utf-8") as fh:
        json.dump(dict(sorted(fixtures.items())), fh, indent=1)
    with open(a.map, "w", encoding="utf-8") as fh:
        json.dump(mapping, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
