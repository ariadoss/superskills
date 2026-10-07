app/controllers/blog_controller.py:
⋮
│def subject_for(post):
│    return slugify(post["title"])
⋮

app/controllers/notification_controller.py:
⋮
│def create(user_id, items):
│    return {"receipt": send_digest(user_id, items)}
⋮

app/helpers/admin_notifier.py:
│def notify_admin(msg):
│    print("admin:", msg)
⋮

app/helpers/slug.py:
│def slugify(text):
│    return "-".join(text.lower().split())
⋮

app/jobs/digest_job.py:
⋮
│def run_nightly(users, catalog):
│    receipts = {}
⋮

app/mailers/template_renderer.py:
│def render(subject, body):
│    return f"<h1>{subject}</h1><p>{body}</p>"
⋮

app/models/notification.py:
│class Notification:
│    """A queued outbound message. priority: 0=low 1=normal 2=urgent (UNUSED today)."""
│    def __init__(self, user_id, subject, body, channel="email"):
│        self.user_id, self.subject, self.body, self.channel = user_id, subject, body, channel
⋮

app/models/settings.py:
│class NotificationSettings:
│    frequency = "weekly"
⋮

app/services/notification_service.py:
⋮
│def send(notification):
│    """Delivers via the channel. Returns a receipt id."""
⋮
│def send_digest(user_id, items):
│    n = Notification(user_id, "Your digest", "\n".join(items))
⋮

app/services/user_service.py:
│def find(user_id):
│    return {"id": user_id, "email": f"user{user_id}@example.com"}
│def mute(user_id):
│    return {"id": user_id, "muted": True}
⋮

db/migrations/001_notifications.sql:
│CREATE TABLE notifications (
│  id INTEGER PRIMARY KEY,
│  user_id INTEGER NOT NULL,
│  subject TEXT,
⋮

tests/test_digest.py:
⋮
│class T(unittest.TestCase):
│    def test_digest(self):
│    def test_digest(self):
│        self.assertTrue(send_digest(1, ["a"]).startswith("rcpt-"))
⋮

web/hooks/notification_hook.py:
⋮
│def handle(payload):
│    n = Notification(payload["user"], payload["subject"], payload["body"], channel=payload.get("channel", "email"))
⋮
