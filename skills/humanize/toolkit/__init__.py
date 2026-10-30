"""humanize_toolkit: deterministic prose-quality tools (AI-slop scan, dash and spacing fixes).

Importing this package is cheap and side-effect free: it loads no word lists, no
spaCy, and it never touches sys.path. Each function below imports its module on
first call.

Public API
----------
slop_index(text, exempt=None) -> dict
    EQ-Bench slop index plus word, bigram and trigram hit counts.
complexity_index(text) -> dict
    Flesch-Kincaid grade and a 0-100 vocabulary-complexity score.
scan(text, exempt_terms=None) -> str
    The full line-numbered slop report the command-line scan prints.
fix_dashes(text) -> str
    Replace em-dashes by clause role (needs spaCy for the ambiguous cases;
    undecidable dashes are kept).
format_spacing(text) -> str
    Collapse double spaces after sentence punctuation and similar spacing fixes.
normalize(text) -> str
    fix_dashes then format_spacing: the deterministic cleanup in one call.
classify(path) -> str
    What kind of user-facing file a path is (markdown, html, locale, source, none...).

Command line
------------
    humanize-scan FILE [--exempt terms.txt]
    python -m humanize_toolkit.slop_report FILE
    (also .normalize, .emdash_fix, .mla_format, .userfacing, .construction_scanner,
    .eq_bench_slop_index)
"""
__version__ = "0.1.0"

__all__ = [
    "__version__", "slop_index", "complexity_index", "scan",
    "fix_dashes", "format_spacing", "normalize", "classify",
]


def slop_index(text, exempt=None):
    from .eq_bench_slop_index import slop_index_new
    return slop_index_new(text, exempt)


def complexity_index(text):
    from .eq_bench_slop_index import complexity_index as _complexity
    return _complexity(text)


def scan(text, exempt_terms=None):
    """Run the full slop scan on `text` and return the report as a string.

    `exempt_terms` is an iterable of product names or terms of art to skip. The
    scan runs in a child interpreter, so it is safe to call from threads and
    in apps that own stdout.
    """
    import os
    import subprocess
    import sys
    import tempfile

    with tempfile.TemporaryDirectory(prefix="humanize-scan-") as tmp:
        src = os.path.join(tmp, "input.md")
        with open(src, "w", encoding="utf-8") as fh:
            fh.write(text)
        # By file path in isolated mode (-I): a same-named package in the
        # caller's directory or PYTHONPATH can never be picked up, and it works
        # however this package was found (installed or on sys.path).
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "slop_report.py")
        cmd = [sys.executable, "-I", script, src]
        if exempt_terms:
            ex = os.path.join(tmp, "exempt.txt")
            with open(ex, "w", encoding="utf-8") as fh:
                fh.write("\n".join(exempt_terms) + "\n")
            cmd += ["--exempt", ex]
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        run = subprocess.run(cmd, capture_output=True, text=True,
                             encoding="utf-8", env=env)
        if run.returncode != 0:
            raise RuntimeError(f"humanize scan failed: {run.stderr.strip()}")
        return run.stdout


def fix_dashes(text):
    from .emdash_fix import fix_text
    return fix_text(text)


def format_spacing(text):
    from .mla_format import mla_format
    return mla_format(text)


def normalize(text):
    return format_spacing(fix_dashes(text))


def classify(path):
    from .userfacing import classify_file
    return classify_file(path)
