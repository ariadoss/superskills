#!/usr/bin/env python3
"""Read-only scanner for a third-party skill, plugin or MCP server directory.

Usage: vet_scan.py <dir>
Prints JSON: {"findings": [...], "skipped": [...], "skipped_overflow": int, "truncated": bool, "floor": "clean|caution|block"}
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
    from vet_rules import FLOORS, INVISIBLE, RULES
except ImportError:  # run by file path under -I, where the script dir is not on sys.path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from vet_rules import FLOORS, INVISIBLE, RULES

MAX_FILE = 1_000_000
MAX_FILES = 5_000
MAX_TOTAL = 50_000_000
SNIPPET = 160
MAX_SKIPPED = 200
BINARY_SNIFF = 4_096
BOMS = (b"\xff\xfe", b"\xfe\xff")
TEXT_EXTS = (".md", ".txt", ".json", ".sh", ".py", ".js", ".ts", ".yaml", ".yml", ".toml", ".mdc")
ARCHIVES = (".zip", ".tar", ".tgz", ".gz", ".bz2", ".xz", ".7z", ".whl", ".jar", ".rar")
CONTROL = re.compile("[\x00-\x08\x0b-\x1f\x7f-\x9f\u200d\u2028\u2029" + INVISIBLE + "]")


def clean(text):
    """Make a quoted snippet safe to show a reviewer: no control, zero-width or bidi characters."""
    return CONTROL.sub(lambda m: "\\u%04x" % ord(m.group()), text)[:SNIPPET]


class Skipped(list):
    """Skip records, capped at MAX_SKIPPED; the rest are only counted in .overflow."""
    overflow = 0

    def add(self, path, reason):
        if len(self) < MAX_SKIPPED:
            self.append({"path": path, "reason": reason})
        else:
            self.overflow += 1


def walk(root):
    """Return (files, skipped, truncated): regular files as (relative path, path) plus skips.
    Stops walking as soon as a file or byte cap is hit."""
    skipped, files, total, truncated = Skipped(), [], 0, False

    def unreadable_dir(err):  # os.walk would otherwise drop a directory it cannot list without a trace
        skipped.add(str(Path(err.filename).relative_to(root)), "unreadable")

    for dirpath, dirnames, filenames in os.walk(root, followlinks=False, onerror=unreadable_dir):
        keep = []
        for d in sorted(dirnames):
            d_path = Path(dirpath) / d
            rel_dir = str(d_path.relative_to(root))
            try:
                is_link = d_path.is_symlink()  # os.walk lists a symlinked directory in dirnames and never descends it
            except OSError:  # for example a path longer than PATH_MAX
                skipped.add(rel_dir, "unreadable")
                continue
            if is_link:
                skipped.add(rel_dir, "symlink")
            elif rel_dir != ".git":  # only the root .git is skipped; a nested one is scanned
                keep.append(d)
        dirnames[:] = keep
        for name in sorted(filenames):
            p = Path(dirpath) / name
            rel = str(p.relative_to(root))
            try:
                st = p.lstat()  # lstat: never follow, and never open a FIFO or device (a read would hang)
            except OSError:
                skipped.add(rel, "unreadable")
                continue
            mode = st.st_mode
            if stat.S_ISLNK(mode):
                skipped.add(rel, "symlink")
            elif not stat.S_ISREG(mode):
                skipped.add(rel, "special file")
            elif len(files) >= MAX_FILES or total >= MAX_TOTAL:
                return files, skipped, True
            elif name.lower().endswith(ARCHIVES):
                skipped.add(rel, "archive")
            elif st.st_size > MAX_FILE:
                skipped.add(rel, "too large")
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


def decode_text(raw):
    """A reader sees text in a file with a NUL byte or a UTF-16 BOM, so scan what the reader sees."""
    if raw[:2] in BOMS:
        return raw.decode("utf-16", "replace").replace("\x00", "")  # a UTF-32 BOM lands here too
    return raw.decode("utf-8", "replace").replace("\x00", "")


def scan(root):
    files, skipped, truncated = walk(root)
    findings, texts = [], {}
    for rel, p in files:
        try:
            raw = read_bytes(p)
        except OSError:
            raw = None
        if raw is None:
            skipped.add(rel, "special file")
            continue
        if b"\x00" in raw[:BINARY_SNIFF] and raw[:2] not in BOMS and not rel.lower().endswith(TEXT_EXTS):
            skipped.add(rel, "binary")
            continue
        texts[rel] = decode_text(raw)
    for rule in RULES:
        findings.extend(rule(texts))
    findings.sort(key=lambda f: (f["path"], f["line"], f["rule"]))
    return findings, skipped, truncated, skipped.overflow


def _finding_floor(f):
    """A documented install line in a prose file is the reviewer's call: caution.
    Judged by the final extension of the basename only."""
    level = FLOORS.get(f["rule"], "caution")
    if f["rule"] == "VS004" and f["path"].rsplit("/", 1)[-1].lower().endswith((".md", ".txt")):
        return "caution"
    return level


def floor(findings, skipped, truncated):
    order = ["clean", "caution", "block"]
    level = "caution" if (skipped or truncated) else "clean"
    for f in findings:
        level = max(level, _finding_floor(f), key=order.index)
    return level


def main(argv):
    if len(argv) != 2 or not Path(argv[1]).is_dir():
        print(__doc__, file=sys.stderr)
        return 2
    findings, skipped, truncated, overflow = scan(Path(argv[1]).resolve())
    for f in findings:
        f["snippet"] = clean(f["snippet"])
    print(json.dumps({"findings": findings, "skipped": skipped, "skipped_overflow": overflow, "truncated": truncated,
                      "floor": floor(findings, skipped, truncated)}, indent=1))
    if findings:
        return 1
    return 3 if (skipped or truncated) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
