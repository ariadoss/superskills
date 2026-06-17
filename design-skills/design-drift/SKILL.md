---
name: design-drift
description: Detect and fix design drift — the ad-hoc colors, spacing, type sizes, shadows, and duplicate component variants that accumulate outside the design system and harden into debt. Use when the user mentions "design drift", "inconsistent UI", "one-off styles", "magic numbers in CSS", "consolidate styles", "design tokens are a mess", "too many shades of gray", or wants to align an existing codebase back to its design system before patterns calcify.
metadata:
  author: superskills
---

# Design Drift

I find where the UI has quietly diverged from its own design system and pull it back — consolidating one-off values into tokens, collapsing duplicate component variants, and promoting recurring exceptions into the system *before* they calcify into debt.

This is not a taste audit. `design-audit` asks "does this look good?" I ask "is this **consistent with the system that already exists**, and what should be normalized or promoted?" Drift is a refactor problem, not an aesthetics problem.

## Core Principle

Every visual value in the codebase is one of three things:
1. **On-system** — references a token (`var(--space-4)`, `theme.colors.primary`). Leave it.
2. **Drift to normalize** — a hardcoded value that is *close to* an existing token (`padding: 15px` next to a `16px` scale, `#3b82f7` vs the brand `#3b82f6`). Snap it back to the token.
3. **Drift to promote** — a hardcoded value that recurs deliberately and has no token (`#0a0a0a` used in 14 places). It's a real system value that was never named. Add it to the system, then reference it.

The skill is deciding which bucket each value falls in — never blindly find-and-replacing.

## Evidence First — No Guessing

I report only drift I can point to. Every finding cites file:line and a count. If I can't locate the design system's source of truth, I stop and ask rather than inventing tokens.

1. **Locate the system.** Find the token source: `tailwind.config.*`, `theme.ts`, `:root` custom properties, `tokens.json`, a `DESIGN_SYSTEM.md`, Style Dictionary, etc. This is ground truth. If there is no system, this skill doesn't apply yet — recommend `interface-design` or `high-end-visual-design` to establish one first.
2. **Scan for raw values.** Grep the styling surface (CSS/SCSS, styled-components, Tailwind arbitrary values `[...]`, inline `style=`, RN `StyleSheet`) for:
   - **Color**: hex, `rgb(`, `hsl(`, named colors outside the token layer
   - **Spacing**: raw `px`/`rem` in padding/margin/gap not drawn from the scale
   - **Type**: `font-size` / `font-weight` / `line-height` literals off the type scale
   - **Radii & shadows**: `border-radius` and `box-shadow` literals
   - **Z-index**: bare integers (a classic drift hotspot)
   - **Breakpoints**: media queries with literal widths
3. **Cluster by proximity.** Group near-identical values (`#fafafa`, `#fbfbfb`, `#f9f9f9` → one cluster). The cluster size is the signal: how many shades of gray actually ship?
4. **Find duplicate components.** Look for `Button2`, `CardNew`, `PrimaryButtonV2`, copy-pasted variants, and components that reimplement an existing primitive with slightly different values.

## Classification

For each cluster, decide and justify:

| Bucket | Test | Action |
|--------|------|--------|
| Normalize | Within rounding distance of an existing token, or a clear typo/near-dupe | Replace with the token |
| Promote | Recurs ≥3× intentionally, no token exists, semantically distinct | Add a named token, then reference it |
| Leave | Genuinely one-off and intentional (e.g. a marketing hero) | Document why; don't touch |

State the count and the decision for every cluster. "14 hardcoded grays collapse to 4 existing tokens + 1 new `--surface-sunken`" is the deliverable, not "cleaned up colors."

## Deliverable

Present a **drift report** before changing anything:

1. **Token source of truth** — what the system is and where it lives.
2. **Drift inventory** — clustered findings with counts, file:line evidence, and the Normalize/Promote/Leave decision per cluster. Order by blast radius (most occurrences first).
3. **Proposed token additions** — any new named values, with rationale for the name and where they slot into the scale.
4. **Consolidation plan** — phased like a refactor: high-confidence mechanical swaps first (typos, exact near-dupes), judgment calls last.

Wait for approval. The user reorders, cuts, or rejects promotions. Execute only what's approved, one phase at a time, presenting a diff after each.

## Guardrails

- **Never** introduce a new visual value while fixing drift — that *is* drift. Promotions go through the token layer, named and reviewed.
- **Pixel-faithful by default.** Normalizing should not visibly change the UI unless the user opts into "snap to nearest." If a swap shifts a value by more than a rounding margin, flag it as a visual change, not a silent fix.
- **One axis at a time** when the surface is large — colors, then spacing, then type. Mixing axes makes diffs unreviewable.
- **Touch styling only.** Logic, state, props, and behavior are out of scope. Flag functional coupling (e.g. a component that can't be deduped without a prop change) for the build agent.
- **Re-drift prevention.** After consolidating, recommend the cheap guardrail: a lint rule (`stylelint` `declaration-property-value-allowed-list`, ESLint `no-restricted-syntax` for arbitrary Tailwind values) or a token-only convention note, so the same drift can't silently return.

## Scope Boundaries

**I touch:** hardcoded visual values, duplicate component variants, token definitions, references to tokens.

**I don't touch:** application logic, new features, visual taste decisions (use `design-audit`), establishing a system from scratch (use `interface-design` / `high-end-visual-design`).
