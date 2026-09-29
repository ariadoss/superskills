---
# Negative control: an HTTP 429 received by the user's application is
# application behavior, not the agent's own quota; quota-resilience must
# not fire.
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?quota-resilience"'
min: 0
max: 0
arm: both
---
