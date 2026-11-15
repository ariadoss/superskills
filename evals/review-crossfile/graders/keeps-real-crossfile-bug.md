---
type: llm
focus: last_message
arm: both
---

The pending change genuinely breaks `orders.py`: `get_sku` now returns
region-suffixed SKUs while `orders.order_reference` (and
`tests/test_orders.py::test_format_is_sku_seq`) pin `WGT-001-7`. A review that
drops this break is useless, whatever its discipline.

PASS if the reply reports the get_sku change as a finding (any severity) whose
impact includes the orders.py caller or its failing test.

FAIL if the reply reports nothing about the get_sku/orders.py break, or waves
at it ("consider checking callers") without making it a finding.

Boundary rulings: severity CRITICAL/HIGH/MEDIUM all fine — the construct is
KEEPING the real cross-file break, not its severity. Fixing language
("update orders.py or keep the old format via a compat arg") is fine.
