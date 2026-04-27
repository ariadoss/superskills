Generate a database schema map for the current project and analyze indexes.

First, locate the repomap install. Search in this order and use the first hit:

1. `$REPOMAP_HOME` (if set)
2. `$HOME/claude-repomap-command`
3. `$HOME/.claude-repomap-command`
4. `$HOME/.local/share/claude-repomap-command`

If none of those contain a `scripts/run.sh` file, tell the user to clone the repo:

```bash
git clone https://github.com/ariadoss/repomap.git ~/claude-repomap-command
```

Then scan the project for database connection configurations (replace `<REPOMAP_DIR>` with the path you found):

```bash
<REPOMAP_DIR>/scripts/run.sh dbmap --list
```

The helper auto-detects a Python interpreter >= 3.8 and falls back to `uv`/`pyenv`/`asdf` if no compatible Python is on PATH.

This will detect database connections from .env files, Prisma schemas, Django settings, Rails database.yml, Knex configs, Sequelize configs, TypeORM configs, SQLAlchemy, Frappe site_config.json, Go config files, and docker-compose.yml.

Show the user the detected connections (with masked passwords). Ask which one to connect to. If no connections are found, ask the user for a DSN manually.

Once the user confirms a connection, run:

```bash
<REPOMAP_DIR>/scripts/run.sh dbmap --dsn '<confirmed_dsn>' -o DBMAP.md
```

Replace `<confirmed_dsn>` with the actual DSN string from the detected config (unmasked).

If tbls is not installed, the tool will attempt to install it via Homebrew or `go install`. If both fail, tell the user to install it manually: `brew install k1LoW/tap/tbls`

After the command completes:
- If DBMAP.md has content, confirm success and summarize the tables found. Then ask the user: "Want me to add a rule to CLAUDE.md so Claude automatically references this schema map in future sessions?" If yes:
  - Check whether CLAUDE.md at the project root already contains the marker `<!-- dbmap-rule -->`. If it does, the rule is already present — skip and tell the user.
  - Otherwise, append the block below to CLAUDE.md (create the file if it doesn't exist). Leave a blank line before the block if appending to existing content.

    ```
    <!-- dbmap-rule -->
    ## DBMAP.md

    DBMAP.md at the project root is the database schema map (tables, columns, types, constraints, relationships). Read it when the task involves the database: writing or reviewing queries, designing migrations, adding models or ORM mappings, debugging schema-related errors, or reasoning about joins and foreign keys. Skip it for pure application logic that doesn't touch the DB.
    ```
- If the command failed with a connection error, help the user troubleshoot (wrong host? DB not running? credentials?)
- If the command errored for another reason, share the error output

## Index Analysis

After generating DBMAP.md, automatically run an index analysis. Read DBMAP.md and examine every table for the following issues:

### 1. Foreign keys without indexes
For every foreign key column, check whether a corresponding index exists. A missing index on an FK column means every JOIN or lookup on that relationship does a full table scan.

Flag as: `⚠ MISSING INDEX: <table>.<column> (foreign key, no index)`

### 2. Columns likely used in WHERE / ORDER BY / GROUP BY without indexes
Scan the codebase for query patterns (ORM calls, raw SQL strings) referencing columns that lack indexes. Flag columns that appear frequently in filters but have no index.

Flag as: `⚠ LIKELY MISSING INDEX: <table>.<column> (used in queries, no index found)`

### 3. Composite index opportunities
If two or more columns on the same table frequently appear together in WHERE clauses, flag them as candidates for a composite index.

Flag as: `💡 COMPOSITE INDEX CANDIDATE: <table>(<col1>, <col2>)`

### 4. Primary key check
Confirm every table has a primary key. Flag any that don't.

Flag as: `⚠ NO PRIMARY KEY: <table>`

### 5. Report format
Output the index analysis as a section appended to DBMAP.md under the heading `## Index Analysis`. Use this format:

```
## Index Analysis

### Issues Found
- ⚠ MISSING INDEX: orders.user_id (foreign key, no index)
- ⚠ MISSING INDEX: posts.author_id (foreign key, no index)
- ⚠ LIKELY MISSING INDEX: events.created_at (filtered in queries, no index)
- 💡 COMPOSITE INDEX CANDIDATE: orders(user_id, created_at)
- ⚠ NO PRIMARY KEY: audit_logs

### Recommended Migrations
For each issue above, provide the SQL to fix it:

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_posts_author_id ON posts(author_id);
CREATE INDEX idx_events_created_at ON events(created_at);
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);

### Summary
X issues found across Y tables. Z are foreign key indexes (high priority), W are query pattern indexes.
```

If no issues are found, write: `## Index Analysis — No issues found. All foreign keys are indexed and no missing indexes detected.`

Ask the user: "Want me to generate and apply these index migrations now?"
