# Synthetic controls

These debrief replies are synthetic controls written by construction from the answer key and session text. They are not real runs.
Fourteen (`private-c01` to `c07`, `public-c01` to `c07`) form the calibration set: seven use the private fixture and seven the public fixture.
Each file starts with a SYNTHETIC CONTROL marker line that `anonymise.py` strips.
`manifest.json` holds the truth for every item label, the leak value and the writes-claimed value. It is never shown to the judge.

`private-c08` was added after the first judge pass, to feed back the one failure class that pass found (a memory note and a global CLAUDE.md offered as equals, closed with "Either works. Your call."). It is a copy of `private-c01` with only that paragraph changed. It is not in `controls-frozen.sha256` and is reported separately, never pooled into the calibration metrics.
