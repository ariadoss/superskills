# Pre-registration: deep-interview question-priority repair (2026-11-16)

Round 2 retained the original Q4 fixture and changed only the acceptance
criterion format. The script passed 3/3, but hand review found that two first
questions targeted component scope or code location after scoring success
criteria as the weakest dimension. Under the original Q4 requirement, the
human score is 1/3. The round-2 output remains unchanged on disk.

## Hypothesis and edit boundary

The skill's topology and repo-first rules can override its weakest-dimension
rule. Clarify priority once: when the user already names component boundaries,
record them provisionally and ask at the weakest requirement dimension; when
the checkout lacks relevant code, record the location as an open implementation
question unless it prevents framing that requirement question. Change no
scoring threshold, criterion format, approval gate, or interview cap.

## Run and gate

Export a separate third skill arm. Run three fresh two-turn `gpt-6-sol` medium
Codex simulations on the unchanged Q4 fixture and answer. Grade objective
checks with `evals/_lib/omc-deepinterview-grade.sh`; hand check the first
question's dimension. Keep the skill only if at least 2/3 pass every original
Q4 requirement (including weakest-dimension targeting and action-verb
acceptance criteria). Record script/human disagreements.
