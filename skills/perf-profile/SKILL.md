---
name: perf-profile
version: 1.0.0
description: |
  Performance profiling — measures code execution time, DB call time, and
  identifies bottlenecks at both the application and database layer.
  Use when asked to "profile performance", "measure execution time",
  "find bottlenecks", "check response times", or "why is this slow".
triggers:
  - profile performance
  - measure execution time
  - find bottlenecks
  - why is this slow
  - check response times
  - performance profiling
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# /perf-profile

Profile application performance: code execution time, DB call time, and bottleneck identification at both the application and database layer.

## Step 1: Identify the target

Ask the user (or infer from context): what are we profiling?
- A specific endpoint / route
- A background job / worker
- A specific function or module
- The whole application (general audit)

## Step 2: DB call time profiling

### PostgreSQL
```bash
# Enable timing in psql
psql "$DATABASE_URL" -c "\timing on"

# Check pg_stat_statements for query timing (if available)
psql "$DATABASE_URL" -c "
  SELECT
    LEFT(query, 80) AS query,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS mean_ms,
    ROUND(total_exec_time::numeric, 2) AS total_ms,
    ROUND((total_exec_time / SUM(total_exec_time) OVER ()) * 100, 1) AS pct_total
  FROM pg_stat_statements
  ORDER BY mean_exec_time DESC
  LIMIT 20;
" 2>/dev/null || echo "pg_stat_statements not available — enable with: CREATE EXTENSION pg_stat_statements;"
```

### MySQL / MariaDB
```bash
mysql -e "
  SELECT
    LEFT(DIGEST_TEXT, 80) AS query,
    COUNT_STAR AS calls,
    ROUND(AVG_TIMER_WAIT/1e9, 2) AS mean_ms,
    ROUND(SUM_TIMER_WAIT/1e9, 2) AS total_ms
  FROM performance_schema.events_statements_summary_by_digest
  ORDER BY AVG_TIMER_WAIT DESC
  LIMIT 20;
" 2>/dev/null || echo "MySQL performance_schema unavailable"
```

Report: table of top 20 queries by mean execution time, with call count and % of total DB time.

## Step 3: Application-level profiling

### Detect the runtime and suggest the right profiler:

```bash
# Detect language/framework
[ -f package.json ] && echo "RUNTIME=node"
[ -f Gemfile ] && echo "RUNTIME=ruby"
[ -f requirements.txt ] || [ -f pyproject.toml ] && echo "RUNTIME=python"
[ -f go.mod ] && echo "RUNTIME=go"
[ -f pom.xml ] || [ -f build.gradle ] && echo "RUNTIME=java"
```

**Node.js:**
- Built-in: `node --prof app.js` + `node --prof-process isolate-*.log`
- For web: add `--inspect` and use Chrome DevTools profiler
- Suggest: `clinic.js` (`npx clinic doctor -- node app.js`) for flame graphs

**Ruby:**
- Suggest: `stackprof` or `rack-mini-profiler` for Rails
- For a specific method: wrap with `Benchmark.measure { ... }`

**Python:**
- Built-in: `python -m cProfile -s cumulative script.py`
- For web: `py-spy top --pid <pid>` for live profiling
- Suggest: `snakeviz` for visualization

**Go:**
- Built-in: `go tool pprof http://localhost:6060/debug/pprof/profile`
- Add `import _ "net/http/pprof"` to enable the endpoint

### Scan for existing timing instrumentation:
```bash
grep -rn "benchmark\|timing\|elapsed\|duration\|stopwatch\|time\.now\|Time\.now\|perf_hook\|performance\.now" \
  --include="*.rb" --include="*.py" --include="*.js" --include="*.ts" --include="*.go" \
  . 2>/dev/null | head -20
```

## Step 4: Code-level bottleneck scan

Scan for common performance anti-patterns in the codebase:

**Synchronous blocking in async contexts:**
```bash
grep -rn "fs\.readFileSync\|execSync\|spawnSync\|sleep\|time\.Sleep" \
  --include="*.js" --include="*.ts" --include="*.go" . 2>/dev/null | head -10
```

**Missing pagination (unbounded queries):**
```bash
grep -rn "\.all\b\|find_all\|SELECT \*\b" \
  --include="*.rb" --include="*.py" --include="*.js" --include="*.ts" . 2>/dev/null | head -10
```

**Repeated expensive calls in loops:**
```bash
grep -rn "each\|forEach\|for " \
  --include="*.rb" --include="*.py" --include="*.js" --include="*.ts" . 2>/dev/null | head -20
```

For each flagged file, read the context and assess impact.

## Step 5: Response time targets

Evaluate findings against these thresholds:

| Metric | Good | Acceptable | Needs Fix |
|--------|------|-----------|-----------|
| DB query mean time | <10ms | <100ms | >100ms |
| DB calls per request | ≤3 | ≤10 | >10 |
| Endpoint response time | <100ms | <500ms | >500ms |
| Background job duration | <1s | <30s | >30s |

## Step 6: Bottleneck report

```
## Performance Profile Report

### DB Layer
- Slowest query: <query> — Xms mean (Y calls/min)
- Total DB time as % of request: Z%
- Queries over 100ms: N

### Application Layer
- Blocking calls found: X
- Unbounded queries (no LIMIT): Y
- Loops with expensive operations: Z

### Top 3 Bottlenecks (by estimated impact)
1. <bottleneck> — estimated Xms saved per request
2. <bottleneck> — estimated Yms saved per request
3. <bottleneck> — estimated Zms saved per request

### Recommended profiling tools for this stack
- <tool 1>
- <tool 2>
```

Ask: "Want me to implement fixes for the top bottlenecks, or set up profiling instrumentation so you can measure before/after?"
