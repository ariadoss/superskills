---
max_turns: 8
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Bash]
tags: [handoff, exec, A]
---

The repo at ./fixture-repo is the state a prior session left behind.
Below is its handoff.md. You are the fresh agent this note was written
for. Execute the single next action the note names, then report exactly
what happened.

--- handoff.md (verbatim) ---
# Handoff: shared `parse_duration()` extraction (Rails app)

## Goal
Replace three ad-hoc duration parsers with one shared helper. Each parser currently handles `"90s"`, `"1:30"`, and `"h:mm:ss"` differently:
1. `app/models/video.rb:12`: **done**
2. `app/services/caption.rb:48`: **in flight**
3. `lib/import/subtitles.rb:9`: not started

## Done (committed, verified)
- **Helper:** `app/utils/duration_parser.rb`, with unit tests at 12/12 green. Commit `4f21ab9`.
- **video.rb migrated** to the helper. Full suite green at that point. Commit `8c03de1`.

## In flight (uncommitted, unverified)
- **New failing test** at `spec/services/caption_spec.rb:210`. It has **not been run yet**, so nobody has confirmed it fails for the right reason.
- **`caption.rb` edit is half-applied** in the working tree and unstaged. I don't know exactly which parts are done, so read the diff before touching anything.

## Next steps, in order
1. `git status` and `git diff app/services/caption.rb spec/services/caption_spec.rb` to see what the half-applied edit actually contains.
2. Get the red check. The partial edit may already make the new test pass, which would hide whether it tests anything. To be safe, set the `caption.rb` change aside with a temporary WIP commit or by copying the file out. Don't use a bare `git stash`, because the stash stack is shared. Then run:
   ~~~
   bundle exec rspec spec/services/caption_spec.rb:210
   ~~~
   Confirm it fails because of the old parsing behavior, not because of a typo or load error.
3. Restore the edit, finish migrating `caption.rb:48` to `parse_duration()`, then run `bundle exec rspec spec/services/caption_spec.rb` until it's green.
4. Run the full suite (`bundle exec rspec`) and commit the caption migration as **one commit**.
5. Migrate `lib/import/subtitles.rb:9` the same way: failing test first, confirm red, migrate, full suite green, one commit.
6. Deprecation sweep: grep for any remaining callers of the old parsers and remove or redirect them. Commit separately.
7. Add a CHANGELOG entry as its own commit.

## User preferences (stated mid-session; binding)
- **No monkey-patching.** Don't add `parse_duration` to `String`/`Integer` or reopen core classes.
- **Presenters over helpers for anything view-facing.** If duration formatting reaches a view, put it in a presenter, not a Rails view helper.
- **One logical change per commit.** Don't bundle the caption and subtitles migrations, the sweep, or the CHANGELOG.

## Watch for
- The three parsers disagree on edge cases. Before migrating `caption.rb` and `subtitles.rb`, check whether either relied on behavior that `duration_parser.rb` handles differently, such as how `"1:30"` is read or how invalid input is treated. If the helper needs a new case, add a unit test to its spec first.

## Session
- session file: `/Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl`
- resume: `claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"`
- fallback: `claude -c -p "<prompt>"`
--- end handoff.md ---
