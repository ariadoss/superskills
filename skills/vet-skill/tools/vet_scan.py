#!/usr/bin/env python3
"""Read-only scanner for a third-party skill, plugin or MCP server directory.

Usage: vet_scan.py <dir>
Prints JSON: {"findings": [...], "skipped": [...], "truncated": bool, "floor": "clean|caution|block"}
Exit 0 nothing found, 1 findings, 2 bad input, 3 only skipped files (a coverage gap).
Never imports, executes or follows anything in the target. No network, no subprocess.
Files are read as bytes, capped, and decoded with errors replaced.
"""
import json
import os
import re
import stat
import sys
from pathlib import Path

try:
    from vet_rules import FLOORS, RULES
except ImportError:  # run by file path under -I, where the script dir is not on sys.path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from vet_rules import FLOORS, RULES

MAX_FILE = 1_000_000
MAX_FILES = 5_000
MAX_TOTAL = 50_000_000
MAX_LINE = 4_096
SNIPPET = 160
ARCHIVES = (".zip", ".tar", ".tgz", ".gz", ".bz2", ".xz", ".7z", ".whl", ".jar", ".rar")
SKIP_DIRS = {".git"}
CONTROL = re.compile(
    "[\x00-\x08\x0b-\x1f\x7f​-‏‪-‮⁦-⁩﻿]|[\U000e0000-\U000e007f]"
)


def clean(text):
    """Make a quoted snippet safe to show a reviewer: no control, zero-width or bidi characters."""
    return CONTROL.sub(lambda m: "\\u%04x" % ord(m.group()), text)[:SNIPPET]


def walk(root):
    """Return (files, skipped, truncated): regular files as (relative path, path) plus recorded skips."""
    skipped, files, total, truncated = [], [], 0, False
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        keep = []
        for d in sorted(dirnames):
            d_path = Path(dirpath) / d
            if d_path.is_symlink():  # os.walk lists a symlinked directory in dirnames and never descends it
                skipped.append({"path": str(d_path.relative_to(root)), "reason": "symlink"})
            elif d not in SKIP_DIRS:
                keep.append(d)
        dirnames[:] = keep
        for name in sorted(filenames):
            p = Path(dirpath) / name
            rel = str(p.relative_to(root))
            st = p.lstat()  # lstat: never follow, and never open a FIFO or device (a read would hang)
            mode = st.st_mode
            if stat.S_ISLNK(mode):
                skipped.append({"path": rel, "reason": "symlink"})
            elif not stat.S_ISREG(mode):
                skipped.append({"path": rel, "reason": "special file"})
            elif len(files) >= MAX_FILES or total >= MAX_TOTAL:
                truncated = True
            elif name.lower().endswith(ARCHIVES):
                skipped.append({"path": rel, "reason": "archive"})
            elif st.st_size > MAX_FILE:
                skipped.append({"path": rel, "reason": "too large"})
            else:
                files.append((rel, p))
                total += st.st_size
    return files, skipped, truncated


def read_bytes(p):
    """Read at most MAX_FILE bytes without following a symlink swapped in after the walk."""
    fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            return None
        with os.fdopen(fd, "rb", closefd=False) as fh:
            return fh.read(MAX_FILE)
    finally:
        os.close(fd)


def scan(root):
    files, skipped, truncated = walk(root)
    findings, texts = [], {}
    for rel, p in files:
        try:
            raw = read_bytes(p)
        except OSError:
            raw = None
        if raw is None:
            skipped.append({"path": rel, "reason": "special file"})
            continue
        if b"\x00" in raw[:4096]:
            skipped.append({"path": rel, "reason": "binary"})
            continue
        texts[rel] = raw.decode("utf-8", "replace")
    for rule in RULES:
        findings.extend(rule(texts))
    findings.sort(key=lambda f: (f["path"], f["line"], f["rule"]))
    return findings, skipped, truncated


def floor(findings, skipped, truncated):
    order = ["clean", "caution", "block"]
    level = "caution" if (skipped or truncated) else "clean"
    for f in findings:
        level = max(level, FLOORS.get(f["rule"], "caution"), key=order.index)
    return level


def main(argv):
    if len(argv) != 2 or not Path(argv[1]).is_dir():
        print(__doc__, file=sys.stderr)
        return 2
    findings, skipped, truncated = scan(Path(argv[1]).resolve())
    for f in findings:
        f["snippet"] = clean(f["snippet"])
    print(json.dumps({"findings": findings, "skipped": skipped, "truncated": truncated,
                      "floor": floor(findings, skipped, truncated)}, indent=1))
    if findings:
        return 1
    return 3 if (skipped or truncated) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
