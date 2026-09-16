---
# Shared by every doctor-* case; `claude plugin eval` has no cross-case graders, so edit all four copies together.
type: tool_used
tool: Bash
input_match: '"command"\s*:\s*"(?:[^"\\]|\\.)*?(\.\/setup\b|\bgit\s+(pull|reset|clone|checkout)\b|curl\s[^|]*\|\s*(ba)?sh|\bbun\s+install\b|\bnpm\s+(i|install)\b|\bbrew\s+install\b)'
min: 0
max: 0
arm: both
---
