Enable automatic database schema map updates. When enabled, DBMAP.md is regenerated every time a database migration command runs in the project.

The hook fires PostToolUse on `Bash` tool calls and matches common migration commands across frameworks (Rails `db:migrate`, Django `manage.py migrate`, Alembic, Prisma, Knex, Sequelize, Goose, Dbmate, Flyway, Liquibase, TypeORM, Drizzle).

This requires a DSN stored in `.dbmap-auto` so the hook can connect without prompting. **The DSN contains credentials — `.dbmap-auto` must be gitignored.**

Steps:

1. Ask the user which DSN to use. Either run detection:

   ```bash
   PYTHONPATH=/Users/danilosapad/claude-repomap-command python3.11 -m dbmap --list
   ```

   …and have the user confirm one of the detected connections, or ask them to provide a DSN directly.

2. Write the confirmed DSN to `.dbmap-auto`:

   ```bash
   printf '%s\n' '<confirmed_dsn>' > .dbmap-auto
   ```

3. Ensure `.dbmap-auto` is gitignored:

   ```bash
   touch .gitignore && grep -qxF '.dbmap-auto' .gitignore || printf '\n.dbmap-auto\n' >> .gitignore
   ```

Confirm that auto-updating is now enabled. Remind the user:
- DBMAP.md must already exist — run `/dbmap` first if it doesn't.
- The hook only fires after migration commands actually run; editing a migration file doesn't trigger it (the schema hasn't changed yet).
- Delete `.dbmap-auto` or run `/dbmap-auto-off` to disable.
