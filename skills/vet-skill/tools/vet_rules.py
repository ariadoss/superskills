"""Rule table for vet_scan. Each rule is a function: {relative path: text} -> list of findings.
A finding is {"rule", "severity", "path", "line", "snippet", "note"}."""
RULES = []
FLOORS = {}  # rule id -> "caution" or "block": the minimum verdict that rule forces
