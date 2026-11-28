---
name: design-direction
description: Commit to a concrete visual direction (type, color, density, shape, motion) when there is no brand or design system, before any high-fidelity work. Use for greenfield UI. Skip if a brand or system exists (use /design-system-extract instead).
---

# Design direction

A direction is a small brand: a look a real company could own, recognise and keep using. Aim for the page a visitor would trust and remember, not the one that breaks no rules.

1. **Confirm it is greenfield.** No brand guide, existing product, reference site or partial system. If any exists, use it and stop.
2. **Get the intent.** If the user is reachable, ask for three adjectives, audience, references and off-limits looks; if they are unsure, offer **four directions** that do not share a palette family (background and accent hex, display and body fonts, one-line rationale each, one deliberately unexpected). If not reachable, decide: name the audience, the feeling that earns their trust (calm, rigor, warmth, speed, play), and how the obvious competitors look, so you can differ.
3. **Start from the subject's world.** Its materials, documents, tools, places and rituals. Take the palette, one motif and the mood of the type from there. Test: swap in a competitor's name. If nothing looks wrong, it is not a direction yet.
4. **Commit on every axis** (words like "clean and modern" yield generic output):
   - **Type:** a display face with character and a body face that reads easily, both named, loaded, with fallbacks; one scale; headline large and tight. A serif is right when the subject wants warmth or authority, a grotesque for precision, a mono for technical work. Never an unexamined default (Inter, Roboto, Arial, system stack). The first display face that comes to mind is the one every other generated page is wearing this year: list three candidates from different families (say a serif, a grotesque and a slab, mono or humanist), then pick by the subject and say why in the comment block.
   - **Layout:** compose the first screen for this subject. Headline on the left with a floating card on the right is the reflex; keep it only if you chose it over a product shown full width under the headline, the form or tool itself as the hero, a type-led opening, or an off-center arrangement. Same for the row of three numbered steps and the one highlighted word in the headline: fine once chosen, a template when all three arrive together.
   - **Color:** one brand color deep enough to carry a dark section, at most one accent kept for actions and highlights, semantic colors, a tinted neutral ramp, all in `oklch()`. Use strong contrast somewhere: an all-pale page reads as unfinished.
   - **Density and shape:** 4px or 8px scale, tight, normal or loose; radius sharp, soft or pill; one elevation system.
   - **Motion:** quiet, expressive or playful. Pick one.
   - **Imagery, in this order:** the product itself built in code; simple flat drawings of objects or patterns from the subject's world, in brand colors, a few shapes each; icons from one set; real photos. No drawn people, faces or hands, no blob art. A placeholder box is the last resort and never the hero.
5. **Make the brand kit:** a wordmark (the name in the display face with a simple mark), a one-line voice ("plain, exact, a little dry"), and the signature element from /design-principles. Headlines and buttons speak in that voice.
6. **Mind the reflex.** Cream background, serif display and a terracotta accent is what a model produces without thinking. Warmth and serifs are fine when the subject is warm; then take the colors from this subject's world, not that recipe. Do not reach for it on dashboards, fintech, health or developer tools without a reason you can state.
7. **Write it down** as a comment block at the top of the file naming the direction, voice and tokens, define the tokens as CSS variables, then build within it.
