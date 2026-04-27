---
name: renaissance-architecture
description: Software architecture and UI/UX principles for building genuinely new solutions, not derivative work. Use when designing features, architecting software, brainstorming apps, reviewing designs, or during strategy discussions. Focuses on first-principles thinking, simplicity where it matters, and creating rather than commenting.
---

# Renaissance Architecture

Build genuinely new things. Not "X but for Y."

---

## Core Philosophy

The problem isn't modern tools. It's building **commentaries instead of creations**.

Medieval scholars wrote commentaries on Aristotle instead of new philosophy. We build Star Wars spin-offs instead of new sci-fi. We add AI to existing workflows instead of asking what workflows become possible.

**Renaissance architecture means:**
- First-principles thinking about WHAT to build
- Pragmatic choices about HOW to build it
- Creating new paradigms, not extending old ones
- Using modern tools to make genuinely new things possible

---

## Architecture Principles

### 1. Simplicity as Default, Complexity When Earned

**Start simple, add complexity when pain is measurable.**

| Start With | Move To | When |
|------------|---------|------|
| SQLite | Postgres | >10 concurrent writers, >100GB, need PostGIS/full-text |
| Single file | Multiple files | File exceeds ~500 LOC or has multiple responsibilities |
| Monolith | Services | Team can't work on same codebase, or genuine scale isolation needed |
| Static hosting | Server | Need auth, real-time, or server-side computation |
| Local state | Cloud sync | Multi-device is a real user need, not assumed |

**Not dogma, but defaults.** Violate with documented reasoning.

---

### 2. Framework Choices

| Framework | When to Use | When to Avoid |
|-----------|-------------|---------------|
| **Next.js** | Full-stack React apps, SSR matters, team knows it | Simple static sites, non-React teams |
| **Remix** | Data-heavy apps, progressive enhancement priority | Simple SPAs, unfamiliar teams |
| **Astro** | Content sites, partial hydration valuable | Highly interactive apps |
| **SvelteKit** | Smaller bundles critical, team willing to learn | Large existing React codebases |
| **Rails/Django** | Rapid CRUD apps, admin panels, proven patterns | Real-time heavy, team prefers JS |
| **FastAPI** | Python APIs, async matters | Simple scripts, team prefers other languages |
| **Hono/Elysia** | Edge functions, lightweight APIs | Complex apps needing full framework |

**The question isn't "framework or not" but "does this framework serve the thing we're creating, or are we creating something that serves the framework?"**

---

### 3. Human-Legible Systems

**Configuration**
- Good: Config a new team member can read and modify in 10 minutes
- Document non-obvious settings inline

**Error messages that teach**
- What happened
- Why it happened
- What to do about it
- Link to docs if complex

**Documentation lives WITH code**
- README in each significant directory
- API docs generated from code
- Architecture decisions recorded (ADRs)

---

### 4. Local-First Where It Matters

| Feature | Local-First Approach | Cloud When |
|---------|---------------------|------------|
| Core functionality | Works offline | Never required for core |
| Data storage | SQLite/local storage | Sync, backup, multi-device |
| Computation | Client-side where possible | Heavy processing, shared resources |
| Auth | Local sessions work | OAuth for third-party, enterprise SSO |

**Sync as enhancement** — local is source of truth where possible. Conflict resolution explicit, user-controlled.

---

## UI/UX Philosophy

### 1. Immediate Feedback

**<100ms for user actions, honest progress for longer operations**

- Optimistic updates where safe (can rollback)
- Progress indicators that reflect actual work
- Never fake progress

### 2. Visible State

**User always knows what the system is doing**

- Status visible without digging
- Background processes surfaced
- Errors prominent, not hidden
- System explains its decisions when non-obvious

### 3. Spatial Consistency

**Things stay where you put them**

- No layout shifts after load
- No rearranging "for the user"
- Muscle memory works
- Back button works, URLs are bookmarkable

### 4. Undo & Recovery

**Implemented at the data layer, not just UI**

- Soft delete by default
- Versioned state where valuable
- "Are you sure?" is not a substitute for undo
- Clear communication of consequences for destructive actions

### 5. Respect Attention

- Notifications: user opts in explicitly, meaningful, easy to disable
- Modals: user-initiated, dismissable
- Autoplay: never for audio, motion respects prefers-reduced-motion
- Good defaults eliminate settings

---

## What This Rejects

### Derivative Thinking
- "X but for Y" without asking if Y needs X
- Features because competitors have them
- Architecture because FAANG does it

### Cargo Cult Engineering
- Microservices for 3-person teams
- Kubernetes for single-server loads
- OAuth for internal tools

### Premature Complexity
- Abstraction layers "for future flexibility"
- Scale architecture before scale problems

---

## Application

### When Reviewing Designs

- [ ] What new thing does this create? (Not "what existing thing does it extend?")
- [ ] Is complexity earned or assumed?
- [ ] Do tool choices serve the creation, or does creation serve the tools?
- [ ] Can someone read the config and understand it?
- [ ] Is feedback immediate or honestly progressive?
- [ ] Can users see what the system is doing?
- [ ] Is everything recoverable/undoable?

### Threshold Triggers

| From | To | Trigger |
|------|-----|---------|
| SQLite | Postgres | >10 concurrent writers OR >100GB data OR need PostGIS/full-text search |
| Monolith | Services | Team can't work on same codebase OR genuine scale isolation needed |
| Static | Server | Need auth, real-time, or server-side computation |
| Local storage | Cloud sync | Multi-device is validated user need, not assumption |

---

## Anti-Dogma Clause

**These are defaults, not laws. Violate with documented reasoning.**

Valid reasons to deviate: team expertise, business timeline, regulatory/compliance requirements, measured performance needs, user research that contradicts assumptions.

**When you deviate, write down why.** One sentence in a comment, ADR, or README.

---

## The Core Question

When designing anything, ask:

**"Am I creating something new, or commenting on something that exists?"**
