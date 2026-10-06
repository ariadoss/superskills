# Handoff — duration-parser extraction @ 2026-10-06

## Session
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"

## Goal
Replace all three ad-hoc duration parsers with the shared helper; suite green; CHANGELOG.

## Done
- app/utils/duration_parser.rb + tests — commit 4f21ab9
- app/models/video.rb:12 migrated — commit 8c03de1

## In flight
- app/services/caption.rb:48 half-edited (unstaged); new spec written but not run

## Next steps
1. Continue the caption migration
2. Then handle subtitles
3. Do the sweep and the changelog

## Verify
bundle exec rspec

## Do not redo
- video.rb migration (committed, green)

## Context
User: no monkey-patching; presenters over helpers; one change per commit.
