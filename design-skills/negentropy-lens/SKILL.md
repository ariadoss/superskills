---
name: negentropy-lens
description: Evaluate systems through an entropy/negentropy lens — is this system decaying or growing? Use when making architecture decisions, evaluating system health, or when the user mentions "entropy", "negentropy", "technical debt", "system decay", or "tacit knowledge".
metadata:
  author: bencium
---

# Negentropy Lens

A decision-support framework for evaluating systems through two fundamental states.

## Core Definitions

- **Entropy**: "the natural tendency of systems toward decay, disorder, and complexity without value"
- **Negentropy**: "the deliberate reversal of decay — growth, compounding value, increasing order"
- **Tacit knowledge**: "the unwritten, unspoken knowledge of how things actually work — assumptions, workarounds, and institutional memory"

**Central principle:** "Every system exists in one of two states. Every decision either accelerates entropy or drives negentropy. There is no neutral."

---

## Five-Phase Decision Process

### Phase 1: Map the System
- Define boundaries and components
- Identify information flows and interfaces
- Map connection points and dependencies

### Phase 2: Diagnose the State
- Classify entropic decay vs. negentropic growth indicators
- Identify stability traps masquerading as health
- Rate the current trajectory

### Phase 3: Surface Tacit Knowledge
- Probe for hidden assumptions
- Find undocumented workarounds
- Uncover institutional memory dependencies
- Ask: "What does the system actually do vs. what the docs say it does?"

### Phase 4: Evaluate the Decision
- Assess entropy alignment
- Compounding potential (does this create more value over time?)
- Knowledge externalization (does this reduce tacit knowledge debt?)
- Reversibility (how hard to undo?)

### Phase 5: Challenge Constructively
- Flag false progress (complexity disguised as improvement)
- Identify local optimization at global expense
- Challenge assumptions about what "growth" means

---

## Key Warnings

### Anti-Patterns

- **Entropy cosplay**: complexity disguised as progress — adding abstractions that solve no real problem
- **Premature formalization**: documenting tacit knowledge before understanding it fully
- **Negentropy theater**: refactoring for its own sake, no value created
- **Symptom management**: fixing surface issues without addressing root causes

---

## Output Approach

Adapt format to context:
- **Full structured reviews** for architecture decisions
- **Brief nudges** when detecting decision points in conversation
- **Naturally integrated language** for content creation and code reviews

When evaluating any decision, ask: "Does this build order, or does it defer disorder?"
