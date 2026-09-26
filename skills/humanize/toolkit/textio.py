"""textio.py — the one way the toolkit's command-line tools read their input file."""
import sys
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
