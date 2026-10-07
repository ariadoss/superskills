#!/usr/bin/env bats
# handoff-resume-fixture.sh — the exec-eval fixture's git shape, pinned for
# free. The bake-off paid once to discover drift here (caption edits
# untracked instead of unstaged-modified); this file makes that class a
# red test instead of a uniform-0/3 eval signature.

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  source "$REPO_ROOT/evals/_lib/handoff-resume-fixture.sh"
  FIX="$BATS_TEST_TMPDIR/repo"
}

@test "fixture realizes the digest: 3 commits, unstaged half-edit, spec anchored near line 210" {
  handoff_resume_fixture "$FIX"
  [ "$(git -C "$FIX" rev-list --count HEAD)" = "3" ]
  git -C "$FIX" status --porcelain | grep -q '^ M app/services/caption.rb$'
  git -C "$FIX" status --porcelain | grep -q '^ M spec/services/caption_spec.rb$'
  # subtitles untouched, nothing untracked
  ! git -C "$FIX" status --porcelain | grep -q 'subtitles' || false
  ! git -C "$FIX" status --porcelain | grep -q '^??' || false
  # the new migration test lands around spec line 210 (the digest's anchor)
  line="$(grep -n 'CaptionDurationMigrationTest' "$FIX/spec/services/caption_spec.rb" | cut -d: -f1)"
  [ "$line" -ge 200 ] && [ "$line" -le 215 ]
}

@test "the planted failure manifests when the spec runs" {
  handoff_resume_fixture "$FIX"
  if command -v ruby >/dev/null 2>&1; then
    run ruby "$FIX/spec/services/caption_spec.rb"
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "CaptionDurationMigrationTest\|test_minutes_seconds"
  else
    # no ruby: assert the bug is present statically (normalize appends to m:ss)
    grep -q 'BUG: m:ss becomes m:ss0' "$FIX/app/services/caption.rb"
  fi
}

@test "committed history carries helper tests and the video migration" {
  handoff_resume_fixture "$FIX"
  git -C "$FIX" show HEAD:app/models/video.rb | grep -q "DurationParser.parse"
  git -C "$FIX" show HEAD~1:test_duration_parser.rb | grep -q "DurationParserTest"
  git -C "$FIX" show HEAD~2:app/services/caption.rb | grep -q "parse\|split"
}
