# Handoff — duration-parser extraction @ 2026-10-06

## Session
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"

## Goal
Replace all three ad-hoc duration parsers with the shared helper; suite green; CHANGELOG.

## Status
Various parser work is underway across app/models/video.rb, app/services/caption.rb,
and lib/import/subtitles.rb, with a shared helper at app/utils/duration_parser.rb.
A caption spec exists at spec/services/caption_spec.rb:210.

## Next steps
1. bundle exec rspec spec/services/caption_spec.rb:210
2. Finish the caption.rb edit; same spec to green
3. Migrate lib/import/subtitles.rb:9
4. grep -rn "parse_duration\|legacy_parse" app lib
5. CHANGELOG entry

## Verify
bundle exec rspec

## Context
User: no monkey-patching; presenters over helpers for view-facing code; one
logical change per commit.
