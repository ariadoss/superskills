---
name: db-optimize
version: 1.0.0
description: |
  Database performance audit — detects N+1 queries, missing indexes, join
  opportunities, slow queries, EXPLAIN analysis, and per-endpoint DB call counts.
  Use when asked to "optimize the database", "find slow queries", "check for N+1",
  "analyze query performance", or "audit DB calls".
triggers:
  - optimize database
  - find slow queries
  - check for N+1
  - database performance
  - audit DB calls
  - explain query
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# /db-optimize

Comprehensive database performance audit: N+1 detection, EXPLAIN analysis, slow query log review, index gaps, join opportunities, and per-endpoint call counts.

## Step 1: Check for DBMAP.md

```bash
[ -f DBMAP.md ] && echo "DBMAP_EXISTS=true" || echo "DBMAP_EXISTS=false"
```

If `DBMAP_EXISTS=false`, tell the user: "No DBMAP.md found. Run `/dbmap` first to generate a schema map — this audit uses it to cross-reference indexes and table structure."

## Step 2: Slow query log

Check if a slow query log exists or can be accessed:

```bash
# PostgreSQL — check pg_stat_statements if available
psql "$DATABASE_URL" -c "SELECT query, calls, total_exec_time, mean_exec_time, rows FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 20;" 2>/dev/null || echo "PG_STAT_UNAVAILABLE"

# MySQL — check slow query log location
mysql -e "SHOW VARIABLES LIKE 'slow_query_log%';" 2>/dev/null || echo "MYSQL_UNAVAILABLE"
```

If neither is available, scan the codebase for query logging output files:

```bash
find . -name "*.log" | xargs grep -l "slow\|duration\|query_time" 2>/dev/null | head -5
```

Report the 10 slowest queries found, sorted by mean execution time. For each: query text (truncated to 120 chars), call count, mean time (ms), total time (ms).

## Step 3: EXPLAIN analysis

For each slow query identified in Step 2 (or any query the user provides), run EXPLAIN ANALYZE:

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>;
```

Interpret the output and flag:
- **Seq Scan** on large tables (>1000 rows) — missing index
- **Nested Loop** with high row estimates — consider hash join or index
- **Hash Join** with high memory usage — consider work_mem tuning
- **Sort** without index — consider index on ORDER BY column
- **high actual rows >> estimated rows** — stale statistics, suggest `ANALYZE <table>`

Format findings as:
```
EXPLAIN: <query summary>
  ⚠ Seq Scan on orders (5,432 rows) — add index on orders.user_id
  ⚠ Sort on created_at — add index on events(created_at)
  ✓ Index Scan on users — OK
```

## Step 4: N+1 detection

Scan the codebase for N+1 patterns:

**ORM patterns to flag:**
- A loop containing a DB call (`.find`, `.where`, `.query`, `.fetch`, `.get`, `.filter`, `.select`)
- Accessing a relation inside a loop without eager loading (`.user`, `.author`, `.comments`, `.items` etc. on a model instance inside a loop)
- Multiple sequential awaits on DB calls inside a loop

```bash
# Find loops with DB calls inside
grep -rn "for\|each\|map\|forEach\|loop" --include="*.rb" --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.java" . | head -5
```

For each file with loop+query patterns, read the surrounding context and determine if it's a true N+1.

Flag as:
```
⚠ N+1 DETECTED: app/controllers/orders_controller.rb:45
  Loop over orders calls order.user on each iteration
  Fix: Use includes(:user) / eager_load(:user) / preload(:user)
  SQL impact: 1 query → 1+N queries (N = number of orders)
```

## Step 5: Per-endpoint DB call audit

Scan route handlers / controller actions for query counts:

For each endpoint/action found, count the number of distinct DB calls made:
- Direct SQL: `db.query`, `connection.execute`, `pool.query`
- ORM: `.find`, `.findAll`, `.where`, `.first`, `.save`, `.create`, `.update`
- Each call inside a loop counts as N calls

Flag any endpoint making **more than 3 DB calls** as a candidate for optimization:
```
⚠ HIGH DB CALL COUNT: GET /api/orders (OrdersController#index)
  8 DB calls detected:
    - Order.all (1)
    - order.user (N — N+1 pattern)
    - order.items (N — N+1 pattern)
  Fix: Use a single query with LEFT JOINs or eager loading
```

## Step 6: Join opportunities

Find places where multiple sequential queries fetch related data that could be a single LEFT JOIN:

Pattern: two queries where the second uses IDs from the first result.

```
💡 JOIN OPPORTUNITY: app/services/dashboard_service.rb:23-31
  Query 1: SELECT * FROM orders WHERE user_id = ?
  Query 2: SELECT * FROM items WHERE order_id IN (...)
  Fix: SELECT o.*, i.* FROM orders o LEFT JOIN items i ON i.order_id = o.id WHERE o.user_id = ?
```

## Step 7: Summary report

Output a prioritized findings report:

```
## DB Optimization Report

### Critical (fix immediately)
- N+1 queries: X found
- Endpoints with >10 DB calls: Y found

### High Priority
- Slow queries (>100ms mean): Z found
- Missing indexes on FK columns: W found (see DBMAP.md Index Analysis)

### Optimization Opportunities
- JOIN consolidations: V found
- EXPLAIN issues: U found

### Recommended next steps
1. [highest impact fix]
2. [second fix]
3. ...
```

Ask the user: "Want me to implement any of these fixes now? I can start with the highest-impact items."
