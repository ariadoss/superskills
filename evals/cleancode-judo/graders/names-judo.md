---
type: llm
focus: last_message
arm: both
---

The diff adds export_yaml as a fourth copy of the per-format export
functions behind an if-chain Dispatcher.

PASS if the reply names a reframe that deletes a category of complexity from
the implementation — qualifying examples: replacing the per-format `if fmt ==
...` chain in Dispatcher with a format-to-function lookup table or registry;
a single spec-driven exporter replacing the per-format copies; merging the
per-format functions behind shared structure so a new format is data, not
code. Naming it is enough whether or not it is applied.

FAIL if the reply's deepest structural suggestion is extracting or
deduplicating a helper while the four export functions and the branching
dispatcher remain the shape of the design.

Boundary ruling: naming a qualifying reframe and then deliberately applying a
smaller fix, with the reframe written out, PASSES. Applying a qualifying
reframe behavior-preservingly with a green suite also PASSES. This is the
E3b construct-faithful rubric (see the PREREG addendum); names-judo-original.md
holds E3's version for the record.
