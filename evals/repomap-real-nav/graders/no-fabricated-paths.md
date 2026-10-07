---
type: llm
focus: last_message
arm: both
---

PASS if every file path in the reply is plausible for a standard Rails
layout (app/models/*.rb, app/controllers/*_controller.rb, app/views/**,
config/locales/**) and none is obviously invented (wrong extension,
nonexistent-sounding dirs like app/mailers/user_email_timing.rb presented
as the preference system).

FAIL if the reply invents files as load-bearing (e.g. a dedicated
email_timing model/controller that the app would not have).
