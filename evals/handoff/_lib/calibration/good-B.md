# Handoff — duration-parser extraction @ 2026-10-06

## Session
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"

## Goal
Replace all three ad-hoc duration parsers with the shared helper; full suite green; CHANGELOG entry.

## Done
- app/utils/duration_parser.rb + 12 unit tests — commit 4f21ab9
- app/models/video.rb:12 migrated — commit 8c03de1 (suite green at that commit)

## In flight
- app/services/caption.rb:48 — edit half-applied, unstaged, unverified
- spec/services/caption_spec.rb:210 — new failing test written, NOT yet run

## Next steps
1. bundle exec rspec spec/services/caption_spec.rb:210   (expect red)
2. Finish the caption.rb edit; re-run the same spec to green
3. Migrate lib/import/subtitles.rb:9
4. grep -rn "parse_duration\|legacy_parse" app lib   (deprecation sweep)
5. CHANGELOG entry

## Verify
bundle exec rspec   (full suite)

## Do not redo
- video.rb migration (committed, green)
- helper authoring (committed)

## Context
User: no monkey-patching; presenters over helpers for view-facing code; one
logical change per commit.
