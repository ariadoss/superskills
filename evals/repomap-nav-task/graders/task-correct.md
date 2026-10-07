---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: the fixture's notification feature lives in
app/models/notification.py (the Notification class with the priority field)
and app/services/notification_service.py (send/send_digest). The TWO real
consumers that send through the service are app/jobs/digest_job.py (calls
send_digest) and web/hooks/notification_hook.py (constructs Notification —
the task's "both places that send" means these two). app/controllers/
notification_controller.py calls send_digest too but only via the job-facing
helper — accepting it as a third edit is fine, never required.

Ground truth (corrected — plan-eng-review finding 3): the service-CALLERS
are app/jobs/digest_job.py and app/controllers/notification_controller.py
(both call send_digest); web/hooks/notification_hook.py CONSTRUCTS a
Notification (a priority-carrier site, not a sender).

PASS if: the model or service is updated to accept priority AND all three
carrier sites (job, controller, hook) forward/accept it, AND the reply's
list matches the Edit-tool edit-proofs (below) — claims without matching
edits FAIL.

FAIL if any carrier site is missing, priority is settable nowhere, or the
reply claims edits the edit-proof graders did not observe. Vocabulary
irrelevant.
