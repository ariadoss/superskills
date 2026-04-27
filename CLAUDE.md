# Superskills

## Versioning

Always increment VERSION before committing and pushing any change:
- Patch (2.x.X) — bug fixes, typo corrections, small clarifications to existing skills
- Minor (2.X.0) — new skills, significant updates to existing skills, new tool support
- Major (X.0.0) — breaking changes, major new capability bundles

Update the version badge in README.md to match (e.g. `v2.1.0` → `v2.2.0`).

## Always keep a local copy of imported skills

Whenever you add a skill that originates from an external GitHub repo (or any other remote source), commit a local copy of its full contents into this repository. The remote could be deleted, renamed, or made private at any time, and the skill must keep working without it.

Two patterns are valid — pick the one that matches the skill's runtime needs:

- **In-tree (preferred for self-contained skills)** — copy the upstream repo's contents directly into the appropriate skills folder (`marketing-skills/<category>/<skill>/`, `design-skills/<skill>/`, or `skills/<skill>/`). The skill ships with the repo, the setup script symlinks it into the target tools, and no separate clone is needed at install time. This is how all marketing-skills, design-skills, and `marketing-skills/content/video-editing/` work.
- **Vendor + runtime clone (only when the upstream is updated frequently and managed by its own setup)** — clone the upstream into `~/.claude/skills/<name>` at install time, AND keep a snapshot at `vendor/<name>/` as a fallback if the remote disappears. This is how `vendor/gstack/` works.

Never reference an external repo as a live dependency without one of these two backups in place. Record the upstream URL in the skill's frontmatter (e.g. `metadata.upstream: https://...`) so the source is traceable.

<!-- superskills-workflow-rule -->
## Superskills Developer Workflow

Read DEVELOPER_WORKFLOW.md to understand how to use superskills commands together effectively — parallel agents, vertical slices, quality pipeline, performance optimization, and shipping workflow.
