#!/usr/bin/env python3
"""Calibrate a pass/fail judge against a hand-labeled answer key.

Reads one label pair per line, either JSONL ({"human": ..., "judge": ...}) or
two-column CSV (human first), from a file argument or stdin, and prints the
confusion counts, the four calibration metrics (TPR, TNR, accuracy,
precision), and a one-line directional bias reading (harsh vs lenient) for
the declared positive class.

Standard library only, and importable as well as a CLI: the functions
``confusion(human, judge, positive)`` and ``metrics(c)`` are the public
surface, ported from the superskills evaluation methodology. The class
treated as positive must be stated next to any number you report, because
swapping it swaps TPR and TNR and changes what precision means.
"""

import argparse
import json
import sys
from collections import Counter
from dataclasses import dataclass

USAGE = __doc__


class DataError(Exception):
    """Bad input: unreadable, undecodable, or a malformed line."""


@dataclass
class Confusion:
    tp: int = 0
    tn: int = 0
    fp: int = 0
    fn: int = 0


def confusion(human, judge, positive="FAIL"):
    """Tally a confusion matrix from equal-length label lists.

    `positive` names the class treated as positive. Any label that is not
    `positive` counts as the negative class: the matrix is binary by
    contract, so decide up front how in-between outcomes map onto the two
    labels.
    """
    if len(human) != len(judge):
        raise ValueError("human and judge label lists differ in length")
    c = Confusion()
    for h, j in zip(human, judge):
        if h == positive:
            if j == positive:
                c.tp += 1
            else:
                c.fn += 1
        else:
            if j == positive:
                c.fp += 1
            else:
                c.tn += 1
    return c


def metrics(c):
    """The four calibration metrics, rounded to 4 decimals.

    A metric whose denominator is zero is None (printed as n/a), not a crash
    and not a silent 0. Report all four together, never accuracy alone:
    accuracy hides which way the errors go.
    """

    def ratio(num, den):
        return round(num / den, 4) if den else None

    return {
        "TPR (recall)": ratio(c.tp, c.tp + c.fn),
        "TNR (specificity)": ratio(c.tn, c.tn + c.fp),
        "accuracy": ratio(c.tp + c.tn, c.tp + c.tn + c.fp + c.fn),
        "precision": ratio(c.tp, c.tp + c.fp),
        "counts": {"TP": c.tp, "TN": c.tn, "FP": c.fp, "FN": c.fn},
    }


def polarity(positive, labels):
    """Decide which label plays the adverse (FAIL-like) side.

    The usual convention declares the adverse class positive, so a false
    positive is a wrongly failed run and a false negative a waved-through
    one. Declaring PASS the positive class inverts that mapping, and a bias
    reading computed without the inversion names the wrong direction, so the
    swap happens here. A custom positive label is treated as the adverse
    side by contract.
    """
    others = [l for l in labels if l != positive]
    if not others:
        return positive, None
    other = Counter(others).most_common(1)[0][0]
    if positive.upper() == "FAIL":
        return positive, other
    if positive.upper() == "PASS":
        return other, positive
    return positive, other


def bias_line(c, positive, labels):
    """One-line directional reading from the two error rates.

    Wrongly failed: the judge labels the adverse label where the human did
    not. Waved through: the judge labels the non-adverse label where the
    human labeled the adverse one. Which confusion cell feeds which name
    depends on the declared positive class; harsh means the errors lean
    toward failing good work, lenient toward waving bad work through.
    """
    fail_side, pass_side = polarity(positive, labels)
    if pass_side is None:
        return "bias: n/a - only one label present (%s)" % positive

    if fail_side == positive:
        wrongly_failed = (c.fp, c.fp + c.tn)   # judge FAIL, human PASS
        waved_through = (c.fn, c.tp + c.fn)    # judge PASS, human FAIL
    else:
        wrongly_failed = (c.fn, c.tp + c.fn)   # positive is PASS-like
        waved_through = (c.fp, c.fp + c.tn)

    def share(num, den):
        # Rounded for the comparison too, so the verdict never contradicts
        # the printed numbers.
        return round(num / den, 4) if den else None

    def clause(judge_label, human_label, pair):
        num, den = pair
        s = share(num, den)
        return "judge %s where human %s: %d/%d (%s)" % (
            judge_label, human_label, num, den,
            "n/a" if s is None else "%.4f" % s,
        )

    wrong = clause(fail_side, pass_side, wrongly_failed)
    waved = clause(pass_side, fail_side, waved_through)
    wf = share(*wrongly_failed)
    wt = share(*waved_through)
    if wf is None or wt is None:
        return "bias: n/a - %s vs %s" % (wrong, waved)
    if wf > wt:
        return "bias: harsh - %s > %s" % (wrong, waved)
    if wt > wf:
        return "bias: lenient - %s > %s" % (waved, wrong)
    return "bias: none - %s = %s" % (wrong, waved)


def parse_pairs(text):
    """Label pairs from JSONL or two-column CSV text, one pair per line."""
    pairs = []
    seen_data = False
    for lineno, line in enumerate(text.splitlines(), start=1):
        s = line.strip()
        if not s:
            continue
        if not seen_data and s.lower() == "human,judge":
            seen_data = True  # an optional CSV header; not data
            continue
        seen_data = True
        pairs.append(_parse_line(s, lineno))
    return pairs


def _parse_line(s, lineno):
    if s.startswith("{"):
        try:
            obj = json.loads(s)
        except ValueError as e:
            raise DataError("line %d: not valid JSON (%s): %s" % (lineno, e, s))
        if not isinstance(obj, dict):
            raise DataError("line %d: expected a JSON object: %s" % (lineno, s))
        missing = [k for k in ("human", "judge") if k not in obj]
        if missing:
            raise DataError(
                "line %d: missing key(s) %s: %s" % (lineno, ", ".join(missing), s))
        pair = (obj["human"], obj["judge"])
    else:
        cols = [c.strip() for c in s.split(",")]
        if len(cols) != 2:
            raise DataError(
                "line %d: expected 2 CSV columns (human,judge), got %d: %s"
                % (lineno, len(cols), s))
        pair = (cols[0], cols[1])
    if not isinstance(pair[0], str) or not isinstance(pair[1], str):
        raise DataError("line %d: human and judge must be strings: %s" % (lineno, s))
    if not pair[0] or not pair[1]:
        raise DataError("line %d: empty label in: %s" % (lineno, s))
    return pair


def _read_input(path):
    if path is None:
        data = sys.stdin.buffer.read()
        name = "<stdin>"
    else:
        try:
            with open(path, "rb") as f:
                data = f.read()
        except OSError as e:
            raise DataError("cannot read %s: %s" % (path, e.strerror or e))
        name = path
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        raise DataError("%s is not valid UTF-8; labels are text" % name)


def _fmt(value):
    return "n/a" if value is None else "%.4f" % value


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="calibrate.py",
        description=USAGE,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "labels: JSONL lines like {\"human\": \"FAIL\", \"judge\": \"PASS\"}, "
            "or two bare comma-separated columns per line (human first; no "
            "quoting). Any label that is not the declared positive counts as "
            "the negative class. The bias reading calls the judge harsh when "
            "it wrongly fails human-pass work more often than it waves "
            "human-fail work through, lenient when the reverse, for the "
            "declared positive class."
        ),
    )
    ap.add_argument("file", nargs="?",
                    help="label pairs as JSONL or two-column CSV (default: stdin)")
    ap.add_argument("--positive", default="FAIL", metavar="LABEL",
                    help="the class treated as positive (default: FAIL); "
                         "state it next to any number you report")
    args = ap.parse_args(argv)

    if args.file is None and sys.stdin.isatty():
        # An interactive call with no file is a usage error, not a silent hang
        # waiting on the terminal.
        print("usage: calibrate.py [FILE] [--positive LABEL] "
              "(or pipe label pairs on stdin)", file=sys.stderr)
        return 1
    try:
        pairs = parse_pairs(_read_input(args.file))
    except DataError as e:
        print("calibrate.py: %s" % e, file=sys.stderr)
        return 2

    positive = args.positive
    human = [h for h, _ in pairs]
    judge = [j for _, j in pairs]
    labels = sorted(set(human) | set(judge))
    c = confusion(human, judge, positive=positive)
    m = metrics(c)

    print("n=%d positive=%s labels: %s"
          % (len(pairs), positive, ", ".join(labels) if labels else "(none)"))
    print("TP=%d TN=%d FP=%d FN=%d" % (c.tp, c.tn, c.fp, c.fn))
    print("%s %s" % ("TPR (recall)".ljust(18), _fmt(m["TPR (recall)"])))
    print("%s %s" % ("TNR (specificity)".ljust(18), _fmt(m["TNR (specificity)"])))
    print("%s %s" % ("accuracy".ljust(18), _fmt(m["accuracy"])))
    print("%s %s" % ("precision".ljust(18), _fmt(m["precision"])))
    print(bias_line(c, positive, labels))
    return 0


if __name__ == "__main__":
    sys.exit(main())
