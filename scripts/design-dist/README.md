# design-skills

Ten short skills that make a coding agent design like someone with taste: a whole page instead of a hero and three cards, the product shown working in the first screen, real copy, a look a company could own, and a check of the rendered page before it calls the work done.

They are plain `SKILL.md` files. They work in Claude Code and in any agent that reads skill files.

## The skills

Start with `/design-principles`. The others build on it.

| Skill | Use it when |
|---|---|
| `/design-principles` | Before designing anything visual. The shared baseline. |
| `/design-brief` | The request is vague and you need the audience, goal and content pinned down first. |
| `/design-direction` | There is no brand or design system and you need a concrete look: type, color, layout, shape, motion. |
| `/design-variations` | You want a few different options to choose from. |
| `/design-prototype` | You want a clickable prototype of a flow. |
| `/design-system-extract` | A brand or product already exists and the agent should follow it. |
| `/design-slop-check` | A built page looks templated or AI-generated. |
| `/design-hierarchy` | A page is hard to scan, or everything on it shouts at once. |
| `/design-states` | Buttons, inputs and forms need hover, focus, error, loading and empty states. |
| `/design-polish` | The work is "done" and needs a final pass before it ships. |

A typical new page: `/design-principles`, then `/design-direction`, build, then `/design-polish`.

## Install

These skills install through [superskills](https://github.com/ariadoss/superskills), which keeps them up to date and brings the review skills they hand off to. In Claude Code:

```
/plugin marketplace add ariadoss/superskills
/plugin install superskills-design@superskills
```

From a superskills checkout, which also covers Codex, Cursor and OpenCode: `./setup --packs coding,design`.

Start a new session, then type `/design-principles`, or ask for a design and name the skill ("use the design-direction skill").

## Skills they point to

Some steps hand off to `/design-review` (checks the running app in a browser) and `/a11y` (accessibility audit). Both come with superskills.

## How they were tested

Each skill change is measured on rendered pages: the same brief is built with no skill, with the earlier skills and with these, and the pages are screenshotted at desktop and phone width and compared blind by a person. The protocol and results, including what still fails, are in superskills under `evals/reports/`.

Known gaps: agents often pick the same display font across unrelated briefs, and often skip the phone-width check unless reminded.

## Provenance

Canonical source: [ariadoss/superskills](https://github.com/ariadoss/superskills) (`design-skills/`). This repo is its export, so file issues and changes there. A direct edit here is overwritten by the next export.

Written by [Danilo Stern-Sapad](https://danilosapad.com). MIT licensed.
