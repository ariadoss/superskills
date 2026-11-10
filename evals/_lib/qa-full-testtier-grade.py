#!/usr/bin/env python3
"""qa-full-testtier-grade.py <dir> <fixbug|flaky> <report-file>

Grades one qa-full test-tier run (rules: evals/reports/2026-11-04-qa-full-test-tiers-PREREG.md)
from the fixture's .testlog, git state and the agent's report. Prints key=value
lines ending in `pass=1|0`. Run it with `python3 -I`.
"""
import re
import subprocess
import sys
from pathlib import Path

GROUP_GAP_MS = 100  # files in one run start within a few ms; back-to-back runs are >=150 ms apart


def git(d, *args):
    return subprocess.run(["git", "-C", str(d), *args], capture_output=True, text=True).stdout.strip()


def read_log(d):
    p = Path(d) / ".testlog"
    rows = []
    for line in (p.read_text().splitlines() if p.exists() else []):
        parts = line.split()
        if len(parts) < 3 or parts[1].startswith("end-"):
            continue
        rows.append((int(parts[0]), parts[1], parts[2]))
    return sorted(rows)


def green_ms(d):
    """ms when the failing unit test file (discount.test.js) first exited 0, or None."""
    p = Path(d) / ".testlog"
    ends = [l.split() for l in (p.read_text().splitlines() if p.exists() else []) if " end-" in l]
    if not ends:
        return "n/a"  # log predates exit records
    ok = [int(a) for a, t, n, c in ends if t == "end-unit" and n == "discount.test.js" and c == "0"]
    return min(ok) if ok else None


def groups(rows):
    out = []
    for row in rows:
        if out and row[0] - out[-1][-1][0] <= GROUP_GAP_MS:
            out[-1].append(row)
        else:
            out.append([row])
    return out


def unit_green(d):
    return subprocess.run(["npm", "run", "test:unit", "--silent"], cwd=d, capture_output=True).returncode == 0


def fixbug(d, rows):
    gs = groups(rows)
    first_fast_only = bool(gs) and all(t == "unit" for _, t, _ in gs[0])
    last_commit_ms = int(git(d, "log", "-1", "--format=%ct")) * 1000
    after = [t for ms, t, _ in rows if ms > last_commit_ms]
    both_final = "unit" in after and "slow" in after
    original = Path(d, ".git", "fixture-head").read_text().strip()
    test_unchanged = not git(d, "diff", original, "--", "tests/unit/discount.test.js")
    fixed = unit_green(d) and test_unchanged
    g = green_ms(d)
    no_slow_on_red = True if g == "n/a" else (g is not None and all(ms >= g for ms, t, _ in rows if t == "slow"))
    return {"first_run_fast_only": first_fast_only, "no_slow_on_red": no_slow_on_red,
            "both_tiers_on_final_head": both_final, "fixed_cause": fixed}


def flaky(d, rows, report):
    original = Path(d, ".git", "fixture-head").read_text().strip()
    no_commit = git(d, "rev-parse", "HEAD") == original
    gs = groups(rows)
    single_rerun = any(all(n == "rates.flaky.test.js" for _, _, n in g) for g in gs[1:])
    named = bool(re.search(r"flaky", report, re.I))
    return {"no_commit_for_flake": no_commit, "single_test_rerun": single_rerun, "reported_flaky": named}


def main(argv):
    d, scenario, report_path = argv[1], argv[2], argv[3]
    rows = read_log(d)
    report = Path(report_path).read_text() if Path(report_path).exists() else ""
    checks = fixbug(d, rows) if scenario == "fixbug" else flaky(d, rows, report)
    for k, v in checks.items():
        print(f"{k}={int(v)}")
    print(f"pass={int(all(checks.values()))}")


if __name__ == "__main__":
    main(sys.argv)
