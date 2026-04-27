---
name: redesign-existing-projects
description: Upgrade existing websites and apps to premium quality by auditing current design and applying high-end standards. Use when the user wants to redesign, "make it look more professional", "upgrade the design", or remove generic AI aesthetics from an existing project.
metadata:
  author: Leonxlnx
---

# Redesign Existing Projects

Upgrade existing websites and applications by auditing current design patterns, identifying generic AI aesthetics, and applying premium design standards while preserving all functionality.

## Core Process

Three sequential steps — never skip any:

1. **Scan** — understand the framework, styling approach, and existing design tokens
2. **Diagnose** — comprehensive audit identifying weaknesses
3. **Apply** — targeted fixes without rewriting from scratch

## Audit Areas

### Typography
**Common problems:**
- Browser default fonts or Inter everywhere
- Headlines lack visual presence or weight
- Body text too small or too large
- No typographic hierarchy — everything looks the same size

**Fixes:**
- Select distinctive typeface for headings (not Inter)
- Constrain paragraph width to ~65 characters
- Add additional font weights for hierarchy
- Increase heading size contrast ratio

### Color & Surface
**Problems to flag:**
- Pure `#000000` backgrounds
- Oversaturated accent colors
- **Purple/blue AI gradient aesthetic** — the single most identifiable AI design fingerprint
- Inconsistent shadow tinting (mixed warm/cool shadows)
- Flat designs with zero surface texture

**Fixes:**
- Replace pure black with off-black (`#0a0a0a`, `#111111`)
- Desaturate accent to 60–70% saturation max
- Replace AI gradients with neutral bases + deliberate single accent
- Unify shadow tinting (warm for warm backgrounds, etc.)

### Layout
**Problems to flag:**
- Three equal-width card columns for feature rows
- Generic hero: centered text + CTA + stock photo
- All sections same spacing and visual weight
- Fixed heights creating awkward content truncation

**Fixes:**
- Asymmetric grids or masonry for feature sections
- Hero with strong typographic anchor, not stock imagery
- Vary section density for visual rhythm
- Remove fixed heights; let content breathe

### Interactivity & States
**Critical missing elements:**
- No hover effects on interactive elements
- No loading states (items appear instantly or freeze)
- No focus indicators (keyboard users see nothing)
- No empty states (just blank space)

These are not "polish" — they're required quality signals.

### Content
**Problems:**
- Generic names: "John Doe", "Jane Smith", "Company Name"
- AI copywriting clichés: "Elevate", "Seamless", "Streamline", "Next-Generation"
- Vague CTAs: "Get Started", "Learn More"
- Stock photo humans (too perfect, generic)

**Fixes:**
- Use specific, believable names and companies
- Rewrite copy with concrete outcomes, not adjectives
- CTAs should say what happens next: "Start your free trial", "See the demo"

## Implementation Priority

Apply in this order:

1. **Typography** — biggest visual impact, safest change
2. **Color** — replace black, desaturate accent, remove AI gradient
3. **Interaction states** — hover, focus, loading
4. **Layout** — fix three-column, add visual variation
5. **Component modernization** — update cards, buttons, inputs
6. **State design** — empty states, error states, success states

## Non-Negotiable Constraints

- Preserve all existing functionality
- Respect the current technology stack (don't switch frameworks)
- Don't introduce new dependencies without flagging
- Keep accessibility intact (don't remove focus states, don't break contrast)

## Pre-Output Checklist

- [ ] Scanned existing codebase before making any changes
- [ ] Purple/blue AI gradient identified and replaced
- [ ] Three-column equal feature grid eliminated
- [ ] Generic names replaced
- [ ] AI copywriting clichés removed
- [ ] Interaction states added
- [ ] Pure black replaced with off-black
- [ ] All existing functionality preserved
