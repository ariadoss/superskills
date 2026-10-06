#!/usr/bin/env bats
# The verified per-CLI resume commands live in two places that ship
# independently: skills/handoff/scripts/session-ref.sh (the runtime source
# of truth for /handoff — SKILL.md embeds its output verbatim at runtime,
# so the commands need not appear in SKILL.md itself) and /quota-resilience.
# This pins the two copies together — the doctor-graders discipline.

@test "session-ref and quota-resilience carry the same verified resume commands" {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  REF="$REPO_ROOT/skills/handoff/scripts/session-ref.sh"
  QR="$REPO_ROOT/skills/quota-resilience/SKILL.md"
  for cmd in 'claude --resume' 'codex exec resume --last' 'opencode run -c'; do
    grep -qF "$cmd" "$REF"  || { echo "session-ref lost: $cmd"; return 1; }
  done
  # quota-resilience documents the claude and codex resume paths; opencode too
  for cmd in 'claude --resume' 'codex exec resume --last' 'opencode run -c'; do
    grep -qF "$cmd" "$QR"  || { echo "quota-resilience lost: $cmd"; return 1; }
  done
  # and the skill actually points at the script
  grep -qF 'session-ref.sh' "$REPO_ROOT/skills/handoff/SKILL.md"
}
