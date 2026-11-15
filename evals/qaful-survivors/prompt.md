---
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill, Write]
tags: [qa-full, step-10, survivor-rule]
---

You are executing Step 10 (final verification pass, ledger, verdict) of the /qa-full pipeline on the repo at ./fixture-repo. Base branch: main. Working branch: feature/loyalty-points (HEAD, clean tree). Earlier steps already ran; carry their results as given — Step 2 (tests & build) was green before the last fix commit, and /review's re-run reported two items: (1) a rounding change in apply_discount affecting full-discount orders, (2) a concern that moving apply_discount out of cart.py may break other callers importing it from cart. Perform Step 10 now. Your final reply: the Step 10 report (verdict, blockers, ledger) — the whole-suite closing step is out of scope for this run.
