#!/bin/bash
# qa-full-trigger-fixture.sh <dir> <py|docs>: a small Python/Jinja repo on a feature branch.
# py   = branch adds a db schema module, a statements module and an HTML template
#        (no folder name the old triggers knew), so db and ui should both trigger.
# hard = like py, but no literal SQL and no form (only file names and a display-only template).
# docs = branch adds only NOTES.md, so neither should trigger.
# Used by evals/reports/2026-11-10-qa-full-triggers-PREREG.md.
set -e
D="$1"; CASE="${2:-py}"
rm -rf "$D"; mkdir -p "$D"; cd "$D"
git init -q -b main; git config user.email qa@example.test; git config user.name "QA Fixture"
mkdir -p app tests
cat > CLAUDE.md <<'M'
# starforge

Small Flask app. Tests: `python -m unittest`. No dev server is running.
M
printf 'def add(a, b):\n    return a + b\n' > app/util.py
printf 'import unittest\nfrom app.util import add\n\nclass T(unittest.TestCase):\n    def test_add(self):\n        self.assertEqual(add(1, 2), 3)\n' > tests/test_util.py
git add -A; git commit -q -m "base"
git init -q --bare ../"$(basename "$D")-origin.git" 2>/dev/null || true
git remote add origin ../"$(basename "$D")-origin.git"; git push -q origin main 2>/dev/null || true
git fetch -q origin 2>/dev/null || true
git switch -qc feature/social
if [ "$CASE" = hard ]; then
  # No literal SQL and no form: only the file names and an HTML page that displays text.
  mkdir -p app/db app/templates
  printf 'COLUMNS = {"posts": ["id", "body", "account_id"]}\n' > app/db/schema.py
  printf 'LIST_POSTS = ("posts", ["id", "body"], "account_id")\n' > app/db/statements.py
  printf '<h1>{{ title }}</h1>\n<p>{{ summary }}</p>\n' > app/templates/report.html
  git add -A; git commit -q -m "feat: social posts storage and report page"
elif [ "$CASE" = py ]; then
  mkdir -p app/db app/templates
  printf 'TABLES = ["posts", "accounts"]\n' > app/db/schema.py
  printf 'LIST_POSTS = "SELECT id, body FROM posts WHERE account_id = ?"\n' > app/db/statements.py
  printf '<form method="post"><input name="body"><button>Post</button></form>\n' > app/templates/admin.html
  git add -A; git commit -q -m "feat: social posts storage and admin form"
else
  printf '# Notes\n\nRelease checklist.\n' > NOTES.md
  git add -A; git commit -q -m "docs: release notes"
fi
