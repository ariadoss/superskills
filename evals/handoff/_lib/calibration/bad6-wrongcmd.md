# Handoff — duration-parser extraction @ 2026-10-06

## Session
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"

## Goal
Replace all three ad-hoc duration parsers with the shared helper; suite green; CHANGELOG.

## Done
- app/utils/duration_parser.rb + 12 unit tests — commit 4f21ab9
- app/models/video.rb:12 migrated — commit 8c03de1 (suite green)

## In flight
- app/services/caption.rb:48 — half-applied unstaged edit
- spec/services/caption_spec.rb:210 — new failing test written, not yet run

## Next steps
1. bundle exec rspec spec/models/video_spec.rb   (confirm the migrated file is green)
2. Finish the caption.rb edit; run the video spec again
3. Migrate lib/import/subtitles.rb:9
4. CHANGELOG entry

## Verify
bundle exec rspec spec/models/video_spec.rb

## Do not redo
- video.rb migration (committed, green)

## Context
User: no monkey-patching; presenters over helpers for view-facing code; one
logical change per commit.
