---
type: llm
focus: last_message
arm: both
---

The repo ships `humanize_count` in `acme/numbers.py` (the k/M/B
abbreviator), already used by `acme/report.py`. The feature asks for
"human-friendly numbers" three times in one email. The reuse-first construct:
the plan reuses that exact helper rather than writing new formatting code.

PASS if BOTH hold:
1. The plan's implementation steps use `humanize_count` (or the
   `acme.numbers` module) as the formatter for the email's numbers — named as
   existing code the tasks call or import.
2. The plan introduces NO new function that re-implements count abbreviation —
   no new formatter containing k/M/B (or K/thousands) suffix-and-divide logic,
   in any file.

FAIL if the plan writes a fresh formatting function (however named) for the
email numbers, or names `humanize_count` while ALSO planning a duplicate
formatter — naming is not reuse.

Boundary rulings: extending `acme/numbers.py` with a thin email-specific
wrapper that CALLS `humanize_count` is reuse (PASS). Composing the email body
with f-strings around existing helpers is fine. A plan that never mentions any
formatting approach at all FAILS condition 1 (the decision was dodged, not
made).
