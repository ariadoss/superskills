Handoff summary for the agent resuming this session.

Progress and decisions: the shared parse_duration() helper exists at
app/utils/duration_parser.rb with 12/12 unit tests green (commit 4f21ab9);
video.rb's ad-hoc parser was replaced with calls to it (commit 8c03de1, full
suite green at that commit). Decision: one helper, three call sites; no
monkey-patching per the user's instruction.

Context and constraints: user prefers presenters over helpers for
view-facing code; one logical change per commit; the three legacy parsers
are app/models/video.rb:12 (done), app/services/caption.rb:48,
lib/import/subtitles.rb:9.

Remaining work, in order:
1. Run the new caption spec red: bundle exec rspec spec/services/caption_spec.rb:210
2. Finish the caption.rb edit (half-applied, unstaged) and make it green
3. Migrate lib/import/subtitles.rb:9 the same way
4. Deprecation sweep: grep -rn "parse_duration\|legacy_parse" app lib
5. CHANGELOG entry

Critical data: session file /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl;
resume with: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
(fallback: claude -c -p "<prompt>"). Do not re-run the video.rb migration —
it is committed and green. The unstaged caption.rb edit has not been
verified against its new spec.
