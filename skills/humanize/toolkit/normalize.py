#!/usr/bin/env python3
"""normalize.py SRC OUT — step 1 of /humanize: em-dash fix, then MLA formatting.

Replaces the shell pipe `emdash_fix.py SRC | mla_format.py /dev/stdin > OUT`, which
exited 0 and wrote an empty OUT whenever the first stage failed (mla_format happily
formats empty stdin). Here both stages run in-process, the result is written to a
temporary file beside OUT and renamed into place only on success, so a failure
leaves no OUT at all. SRC is never overwritten.
"""
import sys
from pathlib import Path

# Sibling imports. Installed (or run with -m) the module sits in the
# humanize_toolkit package and uses relative imports; importing it never touches
# sys.path. Run by file path (the skill's scripts, hooks and evals) there is no
# package, so the script's own directory is put on sys.path and the siblings are
# imported bare, and no __pycache__ is written into the skill directory.
if __package__:
    from . import emdash_fix
    from .mla_format import mla_format
    from .textio import read_prose, write_prose
else:
    sys.dont_write_bytecode = True
    if str(Path(__file__).resolve().parent) not in sys.path:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
    import emdash_fix
    from mla_format import mla_format
    from textio import read_prose, write_prose


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: python3 normalize.py SRC OUT", file=sys.stderr)
        return 1
    src, out = Path(argv[1]), Path(argv[2])
    if out.exists() and src.exists() and out.resolve() == src.resolve():
        print(f"refusing to overwrite the source: {src}", file=sys.stderr)
        return 1
    text = mla_format(emdash_fix.fix_text(read_prose(src)))
    write_prose(out, text)
    emdash_fix.report_undecidable()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
