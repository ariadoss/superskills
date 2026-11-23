---
name: design-polish
description: Final pre-ship design gate for a built page or screen. Runs the trope scan, hierarchy and rhythm review, and state pass in order, then hands live-browser checks to /design-review and accessibility to /a11y. Use when design work is "done". Not for exploring options (use /design-variations).
---

# Design polish

1. Read the target file(s) and the design direction or system, if any.
2. Run **/design-slop-check**, **/design-hierarchy** and **/design-states** on it, one after another, fixing as each reports. Do not stop at the first finding.
3. Check against **/design-principles**: one primary action, no filler content, real content, tokens in use.
4. Recommend **/a11y** for the deeper accessibility pass and **/design-review** to check the running app in a browser.
5. Summarize: issues fixed by pass, judgment calls for the user, what remains. Say plainly if a pass found nothing.
