---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: in this tool, VERSION is the single source of truth and a script named `sync-version.sh` stamps it into every plugin manifest; `gstack` is an external dependency the installer clones, and a "vendor copy" (marker `.superskills-vendor-copy`) is a temporary stopgap replaced by a real clone on the installer's next run.

PASS if the reply's remediation is consistent with that: the stale manifest is fixed either by re-running the version sync OR by bumping that one manifest to match VERSION (mentioning a sync script is NOT required), and the gstack vendor copy is fixed by re-running the installer or by cloning/re-cloning it — not by deleting it.

FAIL only if the reply recommends deleting the gstack directory, calls gstack orphaned/dead/leftover, or raises gstack's own version string as a defect.
