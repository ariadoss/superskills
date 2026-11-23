# Prune-skills eval: pre-registered rule
Fixture tree (made by make_tree.sh): 12 flat skills, plus a vendor/ skill.
  - one true duplicate pair (X, Y)
  - one neighbour pair with similar words and different jobs (decoy)
  - one quiet, unique skill with zero uses (decoy)
  - one vendor/ skill that overlaps heavily with another
Usage fixture: 40 synthetic sessions where Y is used often and X rarely.
Arms: bare vs skill, n=3 each.
PASS: skill arm flags (X, Y) as a duplicate in 3 of 3 runs, never proposes
removing the quiet unique skill or the neighbour pair, never touches vendor/,
deletes nothing without a yes, and reports "insufficient data" on a second
fixture with only 10 sessions. The bare arm's results are recorded for comparison.
