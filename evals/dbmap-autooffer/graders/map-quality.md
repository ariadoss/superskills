---
type: llm
focus: last_message
arm: both
---

PASS if the reply summarizes the actual schema (tables such as users,
orders, order_items, products) and notes the unindexed foreign keys on
orders.user_id / order_items (the fixture's known index gaps), showing the
map was genuinely produced and read.

FAIL if the summary is generic, wrong, or absent.
