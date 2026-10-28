#!/usr/bin/env bash
set -eu
case "$1" in
  marketing)
    cat > draft.md <<'COPY'
Imagine this: Cedar sends your invoice at noon UTC on the first business day of each month.

Here's the thing: the plan costs $29 per month and includes two workspaces.

The practical test: can you export your invoices as CSV? Yes. Exports remain available after cancellation.

A customer wrote, "Imagine this: I finally found my missing invoice."

Get your invoice from Billing > Documents.
COPY
    ;;
  docs)
    cat > draft.md <<'COPY'
Picture this. The worker retries a failed job three times.

The key question: what happens after the third failure? The job moves to the dead-letter queue.

Imagine two workers reading the same queue. Both receive job 42; the idempotency key prevents a duplicate charge.

The practical test starts at nine and lasts an hour.

```python
message = "Imagine this: a retry"
```

> "Here's the thing: keep the receipt," said Jo.
COPY
    ;;
  clean)
    cat > draft.md <<'COPY'
Imagine a triangle rotated ninety degrees clockwise. Its side lengths do not change.

I can't imagine this being useful without a diagram.

The practical test starts at nine and lasts an hour.

Can the worker restart without losing a job?

Open the file with `reader --mode safe`.

> "Imagine this: two shadows," wrote Jo.
COPY
    ;;
  fiction-edit)
    cat > draft.md <<'COPY'
Mara crouched beneath the stairs, a brass key pressed into her palm.

The practical test: could she reach the gate before the bell rang? She had seven minutes.

Here's the thing: the guard knew her name.

"Imagine this: we both walk out alive," she whispered.

He lifted the lantern. The light caught a second key hanging from his wrist.
COPY
    ;;
  fiction-voice)
    cat > draft.md <<'COPY'
Imagine a city where every window opens onto a different year.

Yours opens onto tomorrow. A child stands in the rain on the other side, wearing your father's coat.

Who would leave a child out in weather like that?

"Here's the thing," your father used to say. "A door only owes you a way through."

The child raises a hand. You raise yours. Neither of you smiles.
COPY
    ;;
  fiction-quotes)
    cat > draft.md <<'COPY'
Mara unfolded the letter.

'Here's the thing. Imagine this: a city without a shore,' it began.

“The tide is coming.
The practical test: can you keep the lamp lit?”

> I saw the gate open.
Then I heard your name. Imagine this: you came back.

She folded the paper along the old crease.
COPY
    ;;
  *) exit 2 ;;
esac
