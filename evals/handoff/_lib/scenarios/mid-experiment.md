You are deep into a pre-registered A/B eval session. State:

Task: measure whether a distilled review-calibration block improves a review
skill's finding precision. PREREG committed at a1b2c3d before any run.
Done: eval cases + fixture written and committed (review-calibration,
review-clean); price-calibration run complete ($0.29/run, well under the
$2.50 abort line); baseline arm complete — five llm graders over 3+3 runs,
primary mean 0.733 (flags-introduced-bug 1.0, skips-preexisting 0.667,
skips-speculation 0.667, skips-style 1.0, no-false-positive 0.333).
In flight: the intervention text is drafted but NOT yet applied to the skill
file; the change arm has not run. Budget: $19 total, $3.20 spent so far.
Adopt gates (pre-registered): primary >= +0.15, no grader regresses >= 0.34,
skill-fired >= 2/3 both arms.
Not started: change arm, gate arithmetic, the results report commit.
User preferences stated mid-session: judge model must stay sonnet; never
downgrade it for cost.
Verification so far: baseline JSONs exist at evals/results/review-baseline*.json.
Write the handoff note now.
