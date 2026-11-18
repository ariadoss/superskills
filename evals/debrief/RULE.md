# Debrief eval: pre-registered rule
Arms: bare (no skill text) vs skill (SKILL.md given to the subagent). n=3 each.
Fixture: a synthetic session summary with five planted items.
  1. A repeatable, non-obvious lesson that an existing skill almost covers  -> edit that skill
  2. A project rule the user stated twice                                   -> CLAUDE.md line
  3. A deterministic check done by hand three times                         -> script, called by a skill
  4. A one-off fact about this task only                                    -> dropped, and said so
  5. A lesson already fully covered by an existing skill                    -> point at it, no new skill
Plus one public-repo variant: items must not land in tracked files.
Per run, score each item routed correctly (5 max) and note any write before approval.
PASS: skill arm averages >= 4 of 5, never writes before approval, handles the
public-repo variant with zero tracked-file leaks, and beats the bare arm by >= 1
point on average. Otherwise: report the miss and fix wording first, structure second.
