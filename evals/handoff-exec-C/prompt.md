---
max_turns: 8
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Bash]
tags: [handoff, exec, C]
---

The repo at ./fixture-repo is the state a prior session left behind.
Below is its handoff.md. You are the fresh agent this note was written
for. Execute the single next action the note names, then report exactly
what happened.

--- handoff.md (verbatim) ---
# Handoff — extract shared parse_duration() helper in the Rails app @ 2026-10-06

## Session
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"

## Goal
Three ad-hoc duration parsers ("90s", "1:30", "h:mm:ss") are replaced by the shared `parse_duration()` in app/utils/duration_parser.rb. No old callers remain, a CHANGELOG entry exists, and the full suite is green.

## Done
- Helper written: app/utils/duration_parser.rb, with unit tests passing 12/12 (commit 4f21ab9).
- app/models/video.rb:12 migrated to `parse_duration()`, full suite green (commit 8c03de1).

## In flight
- spec/services/caption_spec.rb:210: a new failing test for the caption.rb migration exists. It has never been run, so nobody has seen it fail for the right reason.
- app/services/caption.rb:48: the migration edit is half-applied and unstaged in the working tree. What is missing and what is broken in the partial edit has not been checked.
- Unverified: `bundle exec rspec spec/services/caption_spec.rb` has not run since the test at :210 was written.

## Next steps
1. Save the partial caption.rb edit, then restore the file so the new test can be shown failing against the old code: `git diff app/services/caption.rb > /tmp/caption-wip.patch && git checkout -- app/services/caption.rb`
2. Prove the test fails: `bundle exec rspec spec/services/caption_spec.rb:210`. It should fail on duration behavior, not on a load or syntax error. If it passes, fix the test before continuing.
3. Reapply the partial edit with `git apply /tmp/caption-wip.patch`, then finish replacing the ad-hoc parser at app/services/caption.rb:48 with a call to `parse_duration()`.
4. Run `bundle exec rspec spec/services/caption_spec.rb` (green), then `bundle exec rspec` (full suite green).
5. Commit only caption.rb and caption_spec.rb, as one logical change.
6. Migrate lib/import/subtitles.rb:9 with the same TDD loop: write a failing spec, see it fail, replace the parser, run the full suite, then commit on its own. The subtitles spec path is not recorded, so find it with `ls spec/lib/import/`.
7. Deprecation sweep: get the old parser method names from `git show 8c03de1 -- app/models/video.rb` and the pre-migration versions of caption.rb and subtitles.rb, then run `git grep -n '<old_name>'` for each one. Migrate or remove any remaining callers, one commit per logical change.
8. Add a CHANGELOG entry for `parse_duration()` and commit it separately.

## Verify
- `bundle exec rspec` (full suite green)
- `git grep -n '<each old parser name>'` returns no callers
- `git log --oneline` shows one commit per logical change

## Do not redo
- Do not rewrite app/utils/duration_parser.rb or its 12 unit tests (4f21ab9). To find the tests, run `git show --stat 4f21ab9`.
- Do not re-migrate app/models/video.rb (8c03de1).
- Do not rewrite the test at spec/services/caption_spec.rb:210. Run it first.
- No failed approaches have been recorded so far.

## Context
- User preference: no monkey-patching (for example, no `String#to_duration`). Expose duration parsing only through `parse_duration()`.
- User preference: anything view-facing goes in a presenter, not a helper.
- User preference: each commit is one logical change. Never combine a migration, the sweep and the CHANGELOG entry in one commit.
- Each of the three original parsers handled "90s", "1:30" and "h:mm:ss" differently. Expect behavior differences when you swap in the helper, and cover them in specs.
--- end handoff.md ---
