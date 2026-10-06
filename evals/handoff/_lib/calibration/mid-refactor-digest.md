You are 40+ turns into a session. State:

Task: extract a shared `parse_duration()` helper in a Rails app; three ad-hoc
parsers to replace (app/models/video.rb:12, app/services/caption.rb:48,
lib/import/subtitles.rb:9 — each parses "90s"/"1:30"/"h:mm:ss" differently).
Done: helper written at app/utils/duration_parser.rb with unit tests (12/12
green, commit 4f21ab9); video.rb migrated (commit 8c03de1, full suite green).
In flight: caption.rb migration started — new failing test written
(spec/services/caption_spec.rb:210) but NOT yet run red; the file's edit is
half-applied in the working tree (unstaged).
Not started: subtitles.rb; the deprecation sweep (grep for old callers); the
CHANGELOG entry.
User preferences stated mid-session: no monkey-patching; prefer presenters
over helpers for anything view-facing; commits must be one logical change
each.
Verification so far: bundle exec rspec spec/services/caption_spec.rb has not
been run since the test was written.
Write the handoff note now.
