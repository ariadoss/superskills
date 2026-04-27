---
name: human-architect-mindset
description: Systematic architectural thinking that emphasizes irreplaceable human capabilities. Use when designing system architecture, making technology decisions, navigating constraints, or decomposing problems for AI execution. Covers domain modeling, systems thinking, constraint navigation, and AI-aware decomposition.
metadata:
  author: bencium
---

# Human Architect Mindset

Framework for systematic architectural thinking that emphasizes the capabilities humans bring that AI cannot replace.

## Foundation: Loyalty

The human capacity to maintain architectural commitments despite optimization pressure or trending alternatives. AI optimizes for the current prompt; architects optimize for the whole system over time.

"The 'correct' technical solution is often unshippable. Architects navigate the gap between idealized examples and messy reality."

---

## Five Pillars

### 1. Domain Modeling
Understanding actual problem spaces — not just technical implementations.

Key questions:
- What is this system actually doing for its users?
- What are the domain entities and their relationships?
- Where are the invariants that must never be violated?
- What terms do domain experts use, and are we using them too?

### 2. Systems Thinking
Recognizing component interactions and failure modes before they happen.

Key questions:
- How do components fail, and what cascades from that failure?
- Where are the hidden coupling points?
- What changes slowly? What changes fast? Are they separated?
- What happens at scale? At 10x? At 100x?

### 3. Constraint Navigation
Managing technical, organizational, and political realities.

Key questions:
- What's the real budget (time, money, people)?
- What legacy systems must we integrate with?
- What regulatory or compliance requirements apply?
- What can we change, and what must we work around?

### 4. AI-Aware Decomposition
Breaking problems into AI-solvable chunks with clear boundaries.

Key questions:
- Which sub-problems have clear inputs, outputs, and success criteria?
- Where do we need human judgment vs. AI execution?
- How do we validate AI-generated components?
- What context does each AI task need to succeed?

### 5. AI-First Development
Evaluating modern tools, edge computing, and agentic patterns.

Key questions:
- Does AI solve this better than traditional code?
- What's the failure mode when AI gets it wrong?
- How do we maintain quality in AI-generated systems?
- What's the human review and override strategy?

---

## The Architect Process

**Phase 1: Domain Discovery**
- Talk to users and domain experts
- Map business processes before technical ones
- Identify core domain concepts and bounded contexts

**Phase 2: Systems Analysis**
- Document component interactions
- Map data flows and transformation points
- Identify failure modes and cascade risks

**Phase 3: Constraint Mapping**
- Document all constraints (technical, organizational, regulatory)
- Categorize: hard constraints (cannot change) vs. soft constraints (prefer not to change)
- Identify constraint conflicts

**Phase 4: AI Decomposition Planning**
- Identify sub-problems suitable for AI execution
- Define clear boundaries and success criteria for each
- Plan validation and review checkpoints

**Phase 5: Solution Synthesis**
- Design solution that satisfies constraints
- Document key decisions and trade-offs
- Plan the evolution path

---

## Spec Driven Development Extension

Three phases for working with AI precision:

1. **Constitution** — define immutable architectural rules the AI must never violate
2. **Blueprint** — hierarchical specifications that define the solution space
3. **Superhuman Execution** — AI executes within defined boundaries with machine-level consistency

Humans define constitutional rules; AI executes with precision. This prevents AI from optimizing locally while violating global constraints.

---

## Common Architectural Mistakes

- Designing for the happy path, ignoring failure modes
- Optimizing for the first version, not the 10th
- Letting data models be driven by UI requirements
- Conflating technical debt with necessary complexity
- Building what's technically interesting rather than what's needed
- Treating all constraints as negotiable when some are hard
