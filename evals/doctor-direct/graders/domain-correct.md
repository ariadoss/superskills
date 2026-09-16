---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: in this tool, `gstack` is an external dependency that the installer clones from GitHub; when the clone fails it installs a "vendor copy" (marked `.superskills-vendor-copy`) as a temporary stopgap that the installer replaces with a real clone on its next run. Skills become visible by re-running the installer (`./setup`, or the `/superskills-upgrade` command), which creates symlinks.

PASS if the reply's diagnosis and remediation are consistent with that: the missing skill is fixed by re-running the installer (or the upgrade command), and gstack — if mentioned — is described as a vendor/stopgap copy to be replaced by a real clone (or simply as a warning).

FAIL if the reply recommends or suggests any of: deleting or pruning the gstack directory; copying skill files into the home directory by hand; rewriting or "implementing" the setup script; adding or normalising vendor-marker files; or if it calls gstack orphaned/dead/leftover, or presents the plugin manifests as malformed.
