#!/usr/bin/env bash
# db_fixture <dir>: sqlite-backed fixture for the dbmap utility experiment.
db_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: db_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"/{app/queries,app/models,scripts,tests}
  cd "$dir" || exit 1
  git init -q && git config user.email fixture@example.com && git config user.name fixture
  python3 - <<'PY'
import sqlite3
c = sqlite3.connect("app.db")
c.executescript("""
CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL UNIQUE, created_at TEXT);
CREATE TABLE addresses (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), line1 TEXT, city TEXT, country TEXT);
CREATE INDEX idx_addresses_user ON addresses(user_id);
CREATE TABLE products (id INTEGER PRIMARY KEY, sku TEXT NOT NULL, title TEXT, price_cents INTEGER NOT NULL);
CREATE TABLE orders (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), status TEXT NOT NULL DEFAULT 'new', placed_at TEXT NOT NULL);
CREATE TABLE order_items (id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL REFERENCES orders(id), product_id INTEGER NOT NULL REFERENCES products(id), qty INTEGER NOT NULL DEFAULT 1);
CREATE INDEX idx_items_order ON order_items(order_id);
CREATE INDEX idx_items_product ON order_items(product_id);
CREATE TABLE payments (id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL REFERENCES orders(id), amount_cents INTEGER NOT NULL, provider TEXT, created_at TEXT);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE TABLE events (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), kind TEXT NOT NULL, occurred_at TEXT NOT NULL);
CREATE INDEX idx_events_occurred ON events(occurred_at);
CREATE INDEX idx_events_user ON events(user_id);
CREATE TABLE audit_logs (id INTEGER PRIMARY KEY, actor TEXT, action TEXT, at TEXT);
""")
for i in range(1, 21):
    c.execute("INSERT INTO users VALUES (?,?,datetime('now'))", (i, f"user{i}@example.com"))
    c.execute("INSERT INTO orders(user_id,status,placed_at) VALUES (?,?,datetime('now'))", (i, "new" if i % 2 else "shipped"))
c.commit()
PY
  cat > app/queries/orders_by_user.py <<'EOF'
import sqlite3

def open_orders_for(db, user_id):
    """Every non-shipped order for a user, newest first."""
    rows = db.execute(
        "SELECT id, status, placed_at FROM orders WHERE user_id = ? AND status != 'shipped' ORDER BY placed_at DESC",
        (user_id,)).fetchall()
    return rows
EOF
  cat > app/queries/spend_report.py <<'EOF'
def lifetime_spend(db, user_id):
    """Sum of payments for a user's orders."""
    return db.execute(
        "SELECT COALESCE(SUM(p.amount_cents),0) FROM payments p JOIN orders o ON p.order_id = o.id WHERE o.user_id = ?",
        (user_id,)).fetchone()[0]
EOF
  printf 'class Order:\n    table = "orders"\n    fields = ["id", "user_id", "status", "placed_at"]\n' > app/models/order.py
  printf 'import sqlite3, sys\ndb = sqlite3.connect("app.db")\nsys.path.insert(0, ".")\n' > scripts/repl.py
  printf 'DATABASE_URL=sqlite:///%s/app.db\n' "$PWD" > .env
  printf '# fixture shop\nOrders live in the orders table.\nQuery paths: app/queries/*.py\n' > README.md
  git add -A && git commit -qm "fixture: sqlite shop schema + raw-SQL query app"
  )
}
