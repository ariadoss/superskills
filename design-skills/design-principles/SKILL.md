---
name: design-principles
description: Core design rules for building or reshaping any UI, page, slide or prototype in HTML/CSS. Use before designing anything visual, and as the shared baseline for the other design-* skills. Not a review pass (use /design-polish).
---

# Design principles

Work like the designer a good studio would put on this job: someone with taste who writes the copy, draws the hero and ships a finished page. Before any CSS, answer in one line each: who arrives here, what must they believe before they act, and what is the one action.

## Finish the thing

- **Build the whole page.** A page that stops after the hero is a draft. Give the visitor what they need to decide, in the order they need it: the promise, the product shown, how it works, reasons to trust it, answers to the obvious objections (price, effort, risk), and the action again at the end. Drop a part only when this visitor does not need it.
- **Decide when nobody answers.** If the user is reachable, ask about content you cannot know. If not, write it yourself and list your assumptions at the end. Never ship a thinner page because you could not ask.
- **Write real copy.** Say what it does, for whom, and what changes for them. Cut any line a competitor could paste onto their own page unchanged ("made easy", "all-in-one", "powerful insights"). Buttons name what happens next.
- **Be specific without lying.** Concrete names, amounts and rows make a mockup believable; label them once, small ("Sample data", "Example pricing"). Never invent customer logos, named testimonials, awards, certifications or measured results. Where proof belongs and none exists, state a commitment the business can keep, or show the mechanism.
- **No padding.** Every section does one of the jobs above. No bands of invented statistics, no icon rows that restate the headline, no lorem.

## Make it look like someone's

- **Context first.** Use the existing brand, design system, codebase or screenshots. With none, run /design-direction before building.
- **Show the thing working.** The first screen carries a picture of the product or subject at its most useful moment, built in HTML and CSS: the real interface with one telling detail highlighted, the real form, the real output. An idle table says nothing. A box labelled "photo placeholder" says less: never in the first screen, and below it only small, for a photo that truly has to be real.
- **One signature.** One ownable element (a type treatment, a motif from the subject's world, one confident use of color) in the hero, echoed twice further down. Everything around it stays quiet.
- **Pace.** Sections differ on purpose: at least one shift of background, density or layout, so the page does not repeat the same three-card row.

## Craft

- **Hierarchy.** Decide the first, second and third read; express them with size, weight, color, position and space. One primary action per view; secondary actions visibly quieter.
- **Type.** One or two named families, one scale, a headline clearly larger than anything else. Body 16px+ on web, 24px+ on slides. `text-wrap: balance` on headings, `pretty` on prose, lines near 65 characters.
- **Color.** Every color is a token, built in `oklch()`. Tinted whites and blacks, three to five colors plus tints. Contrast 4.5:1 for text, 3:1 for large text and UI.
- **Spacing.** One 4px or 8px scale, generous around what matters, no stray values.
- **Real controls.** `button`, `a`, `input`, `nav`, `main`; `lang`, alt text, keyboard reachable, visible `:focus-visible`, 44px targets, `prefers-reduced-motion`. Every interactive element gets its states (/design-states).
- **Systems.** Tokens as CSS variables, repeated parts identical, real grid and flex, works at 375px. A grid or flex child will not shrink below its widest content: give it `min-width: 0` (or `minmax(0, 1fr)` tracks) so a wide table or code block scrolls inside its own box instead of stretching the page.

## Look before you call it done

This step is not optional: a page you have not seen is not finished. Render it and look at a screenshot at desktop width and at 375px (any headless browser; only if none will run, say so and re-read the CSS line by line). Headless Chrome will not open a window narrower than about 500px, so for the phone check load the page in a 375px-wide iframe or use device emulation; a clipped screenshot is not a pass, and hiding overflow is not a fix. Check that the headline is the largest text, nothing overflows or overlaps (on a phone, tab rows, tables and chip rows wrap or scroll inside their own box, and the page itself never scrolls sideways), no box is empty or broken, every section has content, and the first screen alone says what this is and what to do. An invalid CSS value fails silently and takes its whole declaration with it (math inside `clamp()` needs spaces around `+` and `-`). Fix what you see, then report your assumptions and what is left.
