---
name: ui-refactor
description: Tactical user interface design guide for fixing layouts, selecting colors and fonts, and creating professional UIs. Use when the user wants to improve an existing UI, fix visual problems, or apply systematic design principles to a layout.
metadata:
  author: LovroPodobnik
---

# UI Refactoring and Design Guide

Systematic approach to interface design, emphasizing logical principles over artistic intuition.

## Core Workflow

1. **Prioritize the main feature** — don't start with structural chrome (nav bars, sidebars). Start with the specific functionality: the search form, the contact card, the data table.
2. **Grayscale first** — resolve layout and hierarchy in grayscale before adding color.
3. **Establish constrained systems** — set spacing scale, type scale, and color palette before designing individual components.
4. **Refine with targeted polish** — depth, shadow, border, micro-interaction.

## Key Principles

### Foundation First

"Do not start by designing a 'shell' (nav bars, sidebars). Start with the specific functionality."

Design the thing that matters, then design around it.

### Systematic Constraints

Rather than arbitrary choices, establish restrictive systems:
- Spacing: multiples of 4px or 8px only
- Typography: defined scale (e.g., 12/14/16/20/24/32/48px)
- Colors: defined palette — no one-off hex values

"If you can't decide between two options, you have too many choices. Constrain your inputs."

### Visual Hierarchy

Every screen has one primary action. Everything else is secondary or tertiary.

Hierarchy tools (use in order of preference):
1. **Size** — bigger = more important
2. **Weight** — bold = more important
3. **Color** — saturated/dark = more important
4. **Spacing** — more whitespace = more importance through isolation

### Spacing & Density

- Err on more whitespace, not less — it's easier to tighten than loosen
- Group related items (reduce space between), separate unrelated items (increase space between)
- Consistent vertical rhythm: same spacing unit throughout

### Typography

**Selection criteria:**
- Serious/formal: serif typefaces, restrained weights
- Approachable/playful: rounded sans-serifs, friendlier weights

**Sizing:**
- Body: 16–18px
- Labels/metadata: 12–14px
- Headings: create clear size contrast (don't use 18px heading with 16px body)

**Never:**
- More than 2–3 typefaces
- Default system fonts for display/brand contexts
- Italic AND bold together

### Color

**Palette construction:**
1. Pick a primary accent (brand)
2. Build 8–10 neutral shades from that hue
3. Add semantic colors: error (red), warning (yellow), success (green)

**Rules:**
- Use color sparingly — most UI should be neutral
- Accent color for primary actions and key information only
- Never use pure black or pure white

### Depth & Polish

Adding depth without skeuomorphism:
- Subtle `box-shadow`: `0 1px 3px rgba(0,0,0,0.08)` for cards
- Border + background combination: light border + slightly elevated background
- Micro-interactions: hover states, focus states, transition timing

**Personality frameworks:**
- Serious designs: serif typography, formal restraint, muted palette, rectangular forms
- Approachable designs: rounded corners, energetic accent colors, sans-serif, friendly language

## Quick Diagnostic

| Problem | Fix |
|---------|-----|
| Everything looks the same importance | Establish hierarchy: one primary CTA, supporting secondaries |
| Design feels cluttered | Double all spacing values, see if it improves |
| Colors feel inconsistent | Create a 5-color palette and use nothing else |
| Typography feels chaotic | Reduce to 2 sizes + 2 weights maximum |
| Interactions feel dead | Add hover opacity, transition 150ms ease |
| Shadows feel harsh | Reduce opacity to 0.06–0.10, increase blur |
