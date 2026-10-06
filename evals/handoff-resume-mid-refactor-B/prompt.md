---
max_turns: 4
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [handoff, resume, B]
---

You are a fresh agent with no memory of any prior session. Below is
the handoff.md the previous session left for you. Read it and answer, in
your reply, each of these five questions with specifics:
1. What is the task's definition of done, and what proves it?
2. What is already finished (with its commit hashes / file:line)?
3. What is the single next action, as an exact command?
4. What must you NOT redo, and which known-dead approaches were tried?
5. How would you resume the original session (harness + exact command)?

--- handoff.md (verbatim) ---
~~~markdown
# Handoff — extract shared parse_duration() helper and migrate three ad-hoc parsers @ 2026-10-06

## Session
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"

## Goal
All three ad-hoc duration parsers (video.rb, caption.rb, subtitles.rb) call the shared `parse_duration()` in app/utils/duration_parser.rb. No old callers remain, the CHANGELOG has an entry, and the full suite is green.

## Done
- Shared helper `parse_duration()` at app/utils/duration_parser.rb, with unit tests (12/12 green). Commit 4f21ab9.
- app/models/video.rb:12 migrated to the helper, full suite green. Commit 8c03de1.

## In flight
- spec/services/caption_spec.rb:210: a new test for the caption.rb migration exists. It has **never been run**, so nobody has seen it fail, or seen it fail for the right reason.
- app/services/caption.rb (old parser at :48): the migration edit is **half-applied** in the working tree and unstaged. It is incomplete. Whether it loads or passes is unknown.
- Unverified: `bundle exec rspec spec/services/caption_spec.rb` has not run since the test was written.

## Next steps
1. Inspect the partial work before touching it:
   `git status && git diff app/services/caption.rb spec/services/caption_spec.rb`
2. Set the half-applied edit aside so the test can be seen red against the original code:
   `git diff app/services/caption.rb > /tmp/caption-wip.patch && git checkout -- app/services/caption.rb`
3. Run the new test and confirm it fails for the expected reason, not a typo or load error:
   `bundle exec rspec spec/services/caption_spec.rb:210`
4. Restore the partial edit and finish it, replacing the parser at caption.rb:48 with `parse_duration()`:
   `git apply /tmp/caption-wip.patch`
5. Run until green: `bundle exec rspec spec/services/caption_spec.rb`, then `bundle exec rspec`.
6. Commit the caption migration as one change (spec plus caption.rb only):
   `git add app/services/caption.rb spec/services/caption_spec.rb && git commit -m "Migrate Caption duration parsing to parse_duration"`
7. Do the same failing-test-first migration for lib/import/subtitles.rb:9. See red, migrate, `bundle exec rspec` green, then commit on its own.
8. Deprecation sweep: grep for leftover callers of the old ad-hoc parsing, e.g. `git grep -n -i duration -- app lib`. This note does not record the old method names, so read the three original sites in `git show 8c03de1` and the diffs from steps 6 and 7 to get them, then grep for those exact names. Remove or migrate what you find. Commit separately.
9. Add a CHANGELOG entry for the shared helper and the migration. Commit separately.

## Verify
- `bundle exec rspec` (full suite green)
- Grep using the old parser names from step 8 returns no callers outside the helper.

## Do not redo
- Do not rewrite the helper or its 12 unit tests (4f21ab9).
- Do not re-migrate video.rb (8c03de1).
- No approaches have been tried and abandoned yet. Monkey-patching is ruled out by user preference (see Context), so do not add a core extension like a `String` duration method.

## Context
- User preferences stated this session:
  - No monkey-patching.
  - Use presenters instead of helpers for anything view-facing. The duration parser is a plain util, not a view helper. If any migrated caller turns out to be view-facing formatting, put it in a presenter.
  - Each commit is one logical change. Caption migration, subtitles migration, deprecation sweep and CHANGELOG each get their own commit.
- The three original parsers each handled "90s", "1:30" and "h:mm:ss" differently. That is why one helper replaces them all.
- Helper: app/utils/duration_parser.rb. Remaining sites: app/services/caption.rb:48, lib/import/subtitles.rb:9.
- This file stays uncommitted.
~~~
--- end handoff.md ---
