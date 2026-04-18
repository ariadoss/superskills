Generate a database schema map for the current project.

First, scan the project for database connection configurations by running:

```bash
PYTHONPATH=/Users/danilosapad/claude-repomap-command python3.11 -m dbmap --list
```

This will detect database connections from .env files, Prisma schemas, Django settings, Rails database.yml, Knex configs, Sequelize configs, TypeORM configs, SQLAlchemy, Frappe site_config.json, Go config files, and docker-compose.yml.

Show the user the detected connections (with masked passwords). Ask which one to connect to. If no connections are found, ask the user for a DSN manually.

Once the user confirms a connection, run:

```bash
PYTHONPATH=/Users/danilosapad/claude-repomap-command python3.11 -m dbmap --dsn '<confirmed_dsn>' -o DBMAP.md
```

Replace `<confirmed_dsn>` with the actual DSN string from the detected config (unmasked).

If tbls is not installed, the tool will attempt to install it via Homebrew or `go install`. If both fail, tell the user to install it manually: `brew install k1LoW/tap/tbls`

After the command completes:
- If DBMAP.md has content, confirm success and summarize the tables found. Then ask the user: "Want me to add a rule so Claude automatically references this schema map in future sessions?" If yes, create `.claude/rules/dbmap.md` in the project directory with the content: "Reference DBMAP.md at the project root for the database schema map. Use it to understand table structure, columns, types, constraints, and relationships before writing queries or migrations." Create the `.claude/rules/` directory if needed.
- If the command failed with a connection error, help the user troubleshoot (wrong host? DB not running? credentials?)
- If the command errored for another reason, share the error output
