# /humanize description selection eval (2026-10-13)

Question: after widening /humanize from ".md prose" to "any user-facing copy" and excluding
code, comments and prompts, does a model still pick it for copy-cleanup requests and leave it
alone for code, comment and prompt requests?

## Method

Free in-session method, no billed `claude plugin eval`. Four Sonnet subagents (BEFORE x2,
AFTER x2), each judging 12 independent cases as one JSON array, no tools. Batching 12 cases
per agent cut plan usage but lets earlier cases influence later ones; the earlier /handoff eval
ran one case per agent. BEFORE = description at main (ef2f66f), AFTER = working tree. Both saw
the same eight distractor skills. Grader: exact match on skill name. Positive class: humanize fires.

Gates, written before the runs: AFTER fires on at least 9/10 gated positives, false-fires on at
most 1/14 gated negatives, and false-fires no more than BEFORE.

## Cases

| id | request | expected |
|---|---|---|
| P1 | Humanize README.md, it reads like AI wrote it. | humanize |
| P2 | Remove the AI slop from this blog post draft in content/blog/launch.md | humanize |
| P3 | Clean up the marketing copy on site/pricing.html so it sounds human. | humanize |
| P4 | The strings in locales/en.json feel robotic. Fix the wording without changing the meaning. | humanize |
| P5 | /humanize docs/getting-started.md | humanize |
| N1 | Refactor the retry logic in uploader.go to use exponential backoff. | not humanize |
| N2 | Fix the typos in the code comments of src/billing.py. | not humanize |
| N3 | Rewrite the system prompt in prompts/support.md so the agent follows instructions more reliably. | not humanize |
| N4 | Write a README for this new CLI project from scratch. | not humanize |
| N5 | Tighten the instructions in skills/review/SKILL.md so the agent skips fewer steps. | not humanize |
| N6 | Translate docs/guide.md into Spanish. | not humanize |
| N7 | Add a unit test for parseDate and make it pass. | not humanize |

## Results

| arm | gated positives fired | gated negatives false-fired |
|---|---|---|
| BEFORE (2 reps) | 10/10 | 0/14 |
| AFTER (2 reps) | 10/10 | 0/14 |

All gates pass. The four runs were identical: N4 went to document-generate, N7 to tdd, the rest
to no skill.

## What this does and does not show

- No regression: widening the scope did not make the skill fire on code, comment, prompt or
  agent-instruction requests, and it still fires on copy cleanup in markdown, html and locale files.
- No measured improvement: BEFORE already scored perfectly on this set (ceiling effect), so it
  cannot show the new description is better. The widened scope is covered by deterministic
  tests in tests/humanize-toolkit.bats, not by this selection eval.
- Small n, one model family, batched cases: the counts are the signal.
