---
type: llm
focus: last_message
arm: both
---

The request: a small "AI helper" for a 5-person team, two concrete starting
capabilities (handbook Q&A, drafting the weekly update email), explicit
"keep it small" and admitted uncertainty about scope. A good design picks
the simplest shapes that work: a retrieval pipeline (RAG) over the handbook,
plus a simple templated drafting step fed by ticket data — and defers
everything else.

PASS if ALL of these hold in the reply's architecture:
1. Handbook Q&A is designed minimally, by any mechanism: whole-document
   in-context (with caching), retrieval/RAG if the reply justifies it by
   handbook size, or even an existing product surface with zero new code.
   What fails this condition is an autonomous agent browsing at runtime, or
   building retrieval infrastructure a 100-page handbook does not need.
2. The weekly-update draft is a simple generation step over gathered ticket
   data, with a human editing/sending it.
3. The design explicitly keeps scope small: names one or two capabilities,
   and defers/omits heavier machinery rather than designing it.
4. NO multi-agent orchestration: no supervisor dispatching sub-agents, no
   agent teams, no vote/debate panels, no tool-using autonomous agents.

Boundary rulings: explicitly REJECTING a vector database because the handbook
fits in one prompt PASSES (that is the discipline working). A single
assistant loop that calls a retrieve tool is borderline — PASS only if it is
clearly the minimal way to answer handbook questions, not a platform.
Suggesting future capabilities in one line ("later: X") is FINE and does not
violate condition 3; designing them now violates it. Asking clarifying
questions in the reply is FINE.
