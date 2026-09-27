"""textio.py — the one way the toolkit's command-line tools read and write files."""
import os
import shutil
import sys
import tempfile
from pathlib import Path


def read_prose(path) -> str:
    """The file's text as UTF-8, or exit 2 with a one-line reason; never a traceback."""
    try:
        return Path(path).read_text(encoding="utf-8")
    except UnicodeDecodeError as e:
        reason = (f"not valid UTF-8 (byte {e.start}); convert it first, "
                  "e.g. iconv -f latin1 -t utf-8")
    except OSError as e:
        reason = e.strerror or str(e)
    print(f"{Path(sys.argv[0]).name}: cannot read {path}: {reason}", file=sys.stderr)
    sys.exit(2)


def write_prose(path, text: str) -> None:
    """Write UTF-8 text atomically: a temp file beside the target, then a rename, so a
    failure never leaves a truncated original. Keeps the file's permissions and
    writes through a symlink to its target. Exit 2 with a one-line reason on error."""
    target = Path(os.path.realpath(path))
    try:
        fd, tmp = tempfile.mkstemp(dir=target.parent, prefix=f".{target.name}.", suffix=".tmp")
    except OSError as e:
        print(f"{Path(sys.argv[0]).name}: cannot write {path}: {e.strerror or e}", file=sys.stderr)
        sys.exit(2)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        if target.exists():
            shutil.copymode(target, tmp)
        os.replace(tmp, target)
    except BaseException as e:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        if not isinstance(e, OSError):
            raise
        print(f"{Path(sys.argv[0]).name}: cannot write {path}: {e.strerror or e}", file=sys.stderr)
        sys.exit(2)
