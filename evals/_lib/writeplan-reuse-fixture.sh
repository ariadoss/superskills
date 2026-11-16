#!/usr/bin/env bash
# writeplan_reuse_fixture <dir>: builds the writeplan-reuse-trap fixture repo.
# The repo already ships humanize_count (src/acme/numbers.py), used by two
# callers — the reuse rung. The feature spec asks for human-friendly numbers
# (naive plans re-implement a formatter) plus two soft asks (CSV export,
# precision flag) that the skip rung should shed. Tests are green on HEAD so
# the planner is not distracted. Idempotent: wipes <dir> first; body runs in a
# subshell so the caller's cwd is never touched (the convention _lib set).
writeplan_reuse_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: writeplan_reuse_fixture <dir>" >&2; return 2; }
  (
  set -e
  rm -rf "$dir"
  mkdir -p "$dir/acme" "$dir/tests"
  cd "$dir" || exit 1
  git init -q -b main
  git config user.email fixture@example.com
  git config user.name fixture

  cat > acme/__init__.py <<'EOF'
EOF

  cat > acme/numbers.py <<'EOF'
_SUFFIXES = [(1_000_000_000, "B"), (1_000_000, "M"), (1_000, "k")]


def humanize_count(n):
    """Abbreviate a count for display: 1234 -> "1.2k", 2500000 -> "2.5M"."""
    n = int(n)
    for threshold, suffix in _SUFFIXES:
        if abs(n) >= threshold:
            return f"{n / threshold:.1f}{suffix}"
    return str(n)
EOF

  cat > acme/stats.py <<'EOF'
def fetch_weekly_stats():
    """This week's counters from the ops store (stubbed, deterministic)."""
    return {
        "active_users": 18437,
        "files_stored": 4210,
        "api_calls": 7345502,
    }
EOF

  cat > acme/report.py <<'EOF'
from acme.numbers import humanize_count
from acme.stats import fetch_weekly_stats


def cli_summary():
    """Two-line terminal summary printed by the acme-report CLI."""
    stats = fetch_weekly_stats()
    return (
        f"users this week: {humanize_count(stats['active_users'])}\n"
        f"api calls: {humanize_count(stats['api_calls'])}"
    )
EOF

  cat > tests/__init__.py <<'EOF'
EOF

  cat > tests/test_numbers.py <<'EOF'
import unittest

from acme.numbers import humanize_count


class TestHumanizeCount(unittest.TestCase):
    def test_thousands(self):
        self.assertEqual(humanize_count(1234), "1.2k")

    def test_millions(self):
        self.assertEqual(humanize_count(2_500_000), "2.5M")

    def test_millions_rounding(self):
        self.assertEqual(humanize_count(7_345_502), "7.3M")

    def test_small_counts(self):
        self.assertEqual(humanize_count(4210), "4.2k")
        self.assertEqual(humanize_count(7), "7")


if __name__ == "__main__":
    unittest.main()
EOF

  cat > tests/test_report.py <<'EOF'
import unittest

from acme.report import cli_summary


class TestCliSummary(unittest.TestCase):
    def test_summary_mentions_humanized_counters(self):
        summary = cli_summary()
        self.assertIn("18.4k", summary)
        self.assertIn("7.3M", summary)


if __name__ == "__main__":
    unittest.main()
EOF

  cat > README.md <<'EOF'
# acme-reporter

Small ops-reporting service. `acme.stats` holds the weekly counters,
`acme.numbers` the display formatting helpers, `acme.report` the CLI summary.

Run tests: `python3 -m unittest discover -s tests -t .`
EOF

  git add -A && git commit -qm "base: acme-reporter with counters and CLI summary"
  )
}
