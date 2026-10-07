#!/usr/bin/env bash
# nav_fixture <dir>: builds the repomap experiment's fixture repo — a small
# multi-module app whose "notification priority" feature is split across six
# directories, with two real consumers of the service and realistic ballast.
nav_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: nav_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"/{app/{models,services,controllers,jobs,mailers,helpers},web/hooks,db/migrations,tests,config,docs}
  cd "$dir" || exit 1
  git init -q && git config user.email fixture@example.com && git config user.name fixture

  cat > app/models/notification.py <<'EOF'
class Notification:
    """A queued outbound message. priority: 0=low 1=normal 2=urgent (UNUSED today)."""
    def __init__(self, user_id, subject, body, channel="email"):
        self.user_id, self.subject, self.body, self.channel = user_id, subject, body, channel
        self.priority = 1
EOF
  cat > app/services/notification_service.py <<'EOF'
from app.models.notification import Notification

def send(notification):
    """Delivers via the channel. Returns a receipt id."""
    return f"rcpt-{notification.user_id}-{notification.channel}"

def send_digest(user_id, items):
    n = Notification(user_id, "Your digest", "\n".join(items))
    return send(n)
EOF
  cat > app/controllers/notification_controller.py <<'EOF'
from app.services.notification_service import send_digest

def create(user_id, items):
    return {"receipt": send_digest(user_id, items)}
EOF
  cat > app/jobs/digest_job.py <<'EOF'
from app.services.notification_service import send_digest

def run_nightly(users, catalog):
    receipts = {}
    for uid in users:
        items = [t for t in catalog if t["owner"] == uid]
        receipts[uid] = send_digest(uid, items)
    return receipts
EOF
  cat > web/hooks/notification_hook.py <<'EOF'
import json
from app.models.notification import Notification

def handle(payload):
    n = Notification(payload["user"], payload["subject"], payload["body"], channel=payload.get("channel", "email"))
    return json.dumps({"ok": True})
EOF
  cat > app/services/user_service.py <<'EOF'
def find(user_id):
    return {"id": user_id, "email": f"user{user_id}@example.com"}

def mute(user_id):
    return {"id": user_id, "muted": True}
EOF
  cat > app/mailers/template_renderer.py <<'EOF'
def render(subject, body):
    return f"<h1>{subject}</h1><p>{body}</p>"
EOF
  cat > app/helpers/slug.py <<'EOF'
def slugify(text):
    return "-".join(text.lower().split())
EOF
  printf 'CREATE TABLE notifications (\n  id INTEGER PRIMARY KEY,\n  user_id INTEGER NOT NULL,\n  subject TEXT,\n  body TEXT,\n  channel TEXT DEFAULT '"'"'email'"'"'\n);\n' > db/migrations/001_notifications.sql
  printf 'import unittest\nfrom app.services.notification_service import send_digest\n\nclass T(unittest.TestCase):\n    def test_digest(self):\n        self.assertTrue(send_digest(1, ["a"]).startswith("rcpt-"))\n\nif __name__ == "__main__":\n    unittest.main()\n' > tests/test_digest.py
  printf 'DEBUG=1\nSECRET_KEY=fixture-not-a-secret\n' > .env.example
  printf '# fixture app\nRun tests: python3 -m unittest discover tests\n' > README.md
  # ballast: near-miss names that a naive search would trip on
  printf 'def notify_admin(msg):\n    print("admin:", msg)\n' > app/helpers/admin_notifier.py
  printf 'class NotificationSettings:\n    frequency = "weekly"\n' > app/models/settings.py
  printf 'from app.helpers.slug import slugify\n\ndef subject_for(post):\n    return slugify(post["title"])\n' > app/controllers/blog_controller.py
  git add -A && git commit -qm "fixture: multi-module app with scattered notification feature"
  )
}
