---
name: interface-design
description: Skill for interface design (dashboards, admin panels, SaaS apps, tools) focusing on craft and consistency. Use when building product interfaces, internal tools, or complex UI systems that require intentional design decisions about hierarchy, layout, and component behavior.
metadata:
  author: Dammyjay93
---

# Interface Design

Expert interface design for dashboards, admin panels, SaaS applications, and productivity tools — focused on craft and consistency.

## Core Philosophy: Intent-First Design

The problem with most AI-generated UI is defaults. Default padding, default colors, default spacing. Everything feels assembled, not designed.

**Intent-first design means**: every spacing value, color choice, and typographic decision is made deliberately, with a reason. If you can't articulate why an element looks the way it does, it needs to change.

"If you can't explain why something looks the way it does, it shouldn't look that way."

## Product Domain Exploration

Before designing anything, understand the product:

1. **Who uses this?** Job title, technical sophistication, frequency of use
2. **What's their primary task?** The one thing they do most
3. **What's their mental model?** What existing tools do they compare this to?
4. **What do they fear?** Data loss, mistakes, slowness, confusion?
5. **What do they celebrate?** Task completion, insight discovery, efficiency

Answers shape every design decision. A data-dense analytics tool for analysts looks different from a simple task manager for non-technical users.

## Craft Foundations

### Spacing System

Establish a base unit (4px or 8px) and use only multiples:

```
4px  — micro (icon gaps, tight inline spacing)
8px  — xs (form field internal padding)
12px — sm (compact card padding)
16px — md (standard component padding)
24px — lg (section internal spacing)
32px — xl (component separation)
48px — 2xl (section separation)
64px — 3xl (major section breaks)
```

Never use arbitrary values. `padding: 13px` is a design mistake.

### Color Architecture

Structure: Primary palette + Semantic palette

```
Neutral:  50/100/200/300/400/500/600/700/800/900/950
Accent:   50/100/200/300/400/500/600/700/800/900
Success:  green scale
Warning:  yellow/amber scale  
Error:    red scale
Info:     blue scale
```

For SaaS/tools: neutral-heavy palette with single saturated accent. 90% of the UI should use neutrals.

### Typography Scale

```
xs:   12px / 16px line height  — labels, metadata, captions
sm:   14px / 20px line height  — body text in dense UIs
base: 16px / 24px line height  — standard body
lg:   18px / 28px line height  — sub-headings
xl:   20px / 28px line height  — section headings
2xl:  24px / 32px line height  — page titles
3xl:  30px / 36px line height  — hero headings
```

### Component Hierarchy

Every component has a role in the visual hierarchy:
- **Primary**: one per screen max — the main action
- **Secondary**: supporting actions (2–4 per screen)
- **Tertiary**: utility, navigation, low-priority actions
- **Destructive**: irreversible actions — visually distinct

Never have two primary buttons competing for attention.

## Design Principles

### 1. Density is a Feature

Not all interfaces should be comfortable and spacious. Analytics dashboards, admin panels, and data tools often need information density. Design for the task, not the aesthetic.

Comfortable (consumer): `padding: 24px`, single column, generous whitespace  
Compact (professional tools): `padding: 12px`, multiple columns, efficient use of space

### 2. States Complete the Design

An interface is not designed until all states are designed:
- Default
- Hover
- Active / Pressed
- Focus (keyboard)
- Disabled
- Loading
- Empty
- Error
- Success

Missing states are bugs, not "things to add later."

### 3. Consistency Over Cleverness

Use established patterns from the product ecosystem. Deviating from conventions has a cost — users must learn your system instead of transferring knowledge from elsewhere.

When to be conventional: navigation, forms, data tables, modals  
When to differentiate: brand expression, onboarding, empty states, error messages

### 4. Accessibility is Architecture

Design for accessibility from the start — retrofitting is expensive:
- Color contrast: 4.5:1 for body, 3:1 for large text (WCAG AA)
- Keyboard navigation: every interactive element reachable and usable
- Focus indicators: always visible, never `outline: none`
- Touch targets: minimum 44×44px

### 5. Motion Serves Clarity

Animation should communicate state changes, not decorate:
- Element entering/exiting: fade + slight translate (150–200ms)
- State change: color transition (100–150ms)
- Complex interactions: 200–300ms maximum

Never animate more than 2 properties simultaneously on the same element.

## Workflow

1. **Understand** — learn the domain, users, and task
2. **Wireframe** — grayscale structure, no color decisions yet
3. **Establish system** — spacing scale, color palette, type scale
4. **Component design** — build components to the system
5. **State design** — all states for every component
6. **Review** — audit for consistency, accessibility, missing states

## Post-Completion

After designing any interface:
- [ ] All interactive states defined (hover, focus, disabled, loading, error, empty)
- [ ] Color contrast passes WCAG AA
- [ ] Keyboard navigation works end-to-end
- [ ] Spacing uses only scale values (no arbitrary px)
- [ ] One primary action per screen
- [ ] Design works in dark mode (if required)
- [ ] Mobile layout handled
- [ ] Density appropriate for user and task
