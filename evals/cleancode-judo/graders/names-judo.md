---
type: llm
focus: last_message
arm: both
---

The diff adds export_yaml as a fourth copy of the per-format export
functions. The structural reframe available: one spec-driven exporter — a
per-format table (serialize function + headers rule) with a single export()
loop — deletes the whole category of per-format copies and can swallow the
one-method Dispatcher. The smaller fix (extract one shared escaping helper)
leaves the four-copies shape intact.

PASS if the reply NAMES the structural reframe (a spec/table-driven single
exporter replacing the per-format copies, or equivalent language about
deleting the per-format category / making the Dispatcher disappear), whether
or not it applies it.

FAIL if the reply tops out at the smaller fix (extract-a-helper, dedupe two
lines) with no structural reframe named anywhere.

Boundary ruling: naming the reframe and then deliberately applying the
smaller fix, recording the reframe as deferred with its content written out,
PASSES — the measured thing is seeing the reframe. Applying the reframe
behavior-preservingly with a green suite also PASSES.
