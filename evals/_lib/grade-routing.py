#!/usr/bin/env python3
"""grade-routing.py <tasks-dir> <skills-dir> [arm]

Grades the negative-scope routing eval (evals/reports/2026-09-25-*). Reads the
subagent JSONL transcripts in <tasks-dir>, matches each to its case by the
per-run fixture path in the opening user message (`<arm>-<CASE>-r<N>`), and
reports which owned skills each run loaded via the Skill tool.

Prints aggregates only: never the transcript text.
"""
import json
import os
import re
import sys
from collections import defaultdict

INTENDED = {
    "A1": "debug", "A2": "test-coverage", "A3": "verify",
    "B1": "clean-code", "B2": None, "B3": "clean-code",
    "C1": "qa-full", "C2": "daily-qa", "C3": "qa-full",
    "D1": "perf-profile", "D2": "web-perf", "D3": "db-optimize",
    "E1": "iac-scan", "E2": "defense", "E3": "iac-scan",
}
# Neighbour-scoped negatives: the owned skills a case could plausibly be
# confused with. Pooling TNR over all 43 owned skills inflates the denominator
# with skills no request could have matched, so TNR is reported over these.
# A skill that fans out (daily-qa, qa-full) can spawn its own subagents, and each
# child gets its own transcript whose prompt repeats the fixture path. Those
# children are not separate runs of the case: counting them inflates n and files a
# child's behaviour against the parent's case. Only a transcript whose opening
# user turn carries the launcher's own marker sentence is a run.
LAUNCHER_MARKER = "Work there; ignore the directory this session started in."

PEERS = {
    "A1": ["debug", "test-coverage", "verify", "tdd"],
    "A2": ["test-coverage", "debug", "tdd", "verify"],
    "A3": ["verify", "debug", "test-coverage", "qa-full"],
    "B1": ["clean-code", "test-coverage", "verify"],
    "B2": ["clean-code", "qa-full", "defense", "debug"],
    "B3": ["clean-code", "qa-full", "verify"],
    "C1": ["qa-full", "daily-qa", "clean-code", "finish-branch"],
    "C2": ["daily-qa", "qa-full", "clean-code"],
    "C3": ["qa-full", "daily-qa", "clean-code", "finish-branch"],
    "D1": ["perf-profile", "web-perf", "db-optimize"],
    "D2": ["web-perf", "perf-profile", "a11y"],
    "D3": ["db-optimize", "perf-profile", "dbmap"],
    "E1": ["iac-scan", "defense", "pentest"],
    "E2": ["defense", "iac-scan", "pentest", "fuzz"],
    "E3": ["iac-scan", "defense", "pentest"],
}


def texts(msg):
    c = msg.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return " ".join(b.get("text", "") for b in c if isinstance(b, dict))
    return ""


# Sub-skills each ORCHESTRATOR is specified to invoke. A sub-skill firing on its
# orchestrator's own case is the pipeline working, not a misroute, so it is not
# a false positive.
#
# Explicit on purpose. This used to be derived from every /slash-mention in the
# intended skill's SKILL.md, which also swept in callers and out-of-scope
# pointers: test-coverage names /debug as a neighbour, clean-code names its
# caller /qa-full, and both then became "allowed" -- hiding exactly the
# neighbour misroutes this grader exists to count. Only real invocations belong
# here, transcribed from each skill's own run list; recommend-only mentions
# (daily-qa's /pentest, /qa, /web-perf) are deliberately absent.
FANOUT = {
    # skills/qa-full/SKILL.md "Auto-run" + "Ask-first" (Related commands).
    # dbmap: /db-optimize asks for a schema map first.
    "qa-full": {"clean-code", "defense", "iac-scan", "fuzz", "db-optimize",
                "dbmap", "web-perf", "perf-profile", "a11y", "test-coverage",
                "playwright", "pentest", "tdd", "debug", "verify"},
    # skills/daily-qa/SKILL.md §7a, §7b, §7i -- the only owned auto-runs.
    "daily-qa": {"db-optimize", "defense", "iac-scan"},
}


def grade(path, arm, owned):
    case = None
    complete = False
    skills = set()
    slash = set()
    last_assistant = ""
    pat = re.compile(rf"{re.escape(arm)}-([A-E]\d)-r(\d)")
    with open(path, errors="replace") as fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if not isinstance(rec, dict):
                continue
            t = rec.get("type")
            if t == "user":
                msg = rec.get("message")
                body = texts(msg) if isinstance(msg, dict) else ""
                if case is None:
                    m = pat.search(body)
                    if m and LAUNCHER_MARKER in body:
                        case = m.group(1) + "-r" + m.group(2)
                if not complete:
                    for m in re.finditer(r"<command-name>/([a-z0-9:-]+)</command-name>", body):
                        slash.add(m.group(1).split(":")[-1])
            elif t == "assistant":
                msg = rec.get("message")
                content = (msg.get("content") if isinstance(msg, dict) else None) or []
                if isinstance(content, list):
                    for b in content:
                        if not isinstance(b, dict):
                            continue
                        if b.get("type") == "tool_use" and b.get("name") == "SubagentHandback":
                            # Stop at the FIRST handback. The qa-full ledger Stop
                            # hook can send an agent back for another turn, and
                            # skills it loads only because the hook told it to are
                            # not the routing decision under test.
                            if complete:
                                continue
                            complete = True
                            # The agent's real report goes through the handback
                            # tool, not a trailing text block.
                            last_assistant = str((b.get("input") or {}).get("message", ""))
                        if complete:
                            continue
                        if b.get("type") == "tool_use" and b.get("name") == "Skill":
                            s = (b.get("input") or {}).get("skill")
                            if s:
                                skills.add(str(s).split(":")[-1])
                        elif b.get("type") == "text":
                            last_assistant = b.get("text", "")
    if case is None:
        return None
    fired = {s for s in (skills | slash) if s in owned}
    return {
        "case": case,
        "complete": complete,
        "all_skills": sorted(skills | slash),
        "owned_fired": sorted(fired),
        "final": last_assistant,
    }


def main():
    tasks_dir, skills_dir = sys.argv[1], sys.argv[2]
    arm = sys.argv[3] if len(sys.argv) > 3 else "before"
    owned = {d for d in os.listdir(skills_dir)
             if os.path.isfile(os.path.join(skills_dir, d, "SKILL.md"))}
    fanout = {k: v & owned for k, v in FANOUT.items()}

    runs = []
    for name in sorted(os.listdir(tasks_dir)):
        if not name.endswith(".output"):
            continue
        r = grade(os.path.join(tasks_dir, name), arm, owned)
        if r:
            runs.append(r)
    incomplete = [r["case"] for r in runs if not r["complete"]]
    runs = [r for r in runs if r["complete"]]
    if incomplete:
        print(f"EXCLUDED (still running, no handback): {', '.join(sorted(incomplete))}\n")

    if not runs:
        print(f"no {arm} runs found in {tasks_dir}")
        return 1

    print(f"arm={arm}  runs={len(runs)}\n")
    print(f"{'case':8s} {'intended':14s} {'intended_fired':15s} owned skills fired")
    print("-" * 78)
    tp = fn = fp = 0
    named = 0
    named_any = 0
    named_any_total = 0
    peer_tn = peer_fp = 0
    per_skill = defaultdict(lambda: dict(tp=0, fn=0, fp=0, tn=0))
    any_fired = 0
    wrong_runs = []
    for r in sorted(runs, key=lambda x: x["case"]):
        cid = r["case"].split("-")[0]
        want = INTENDED[cid]
        got = r["owned_fired"]
        hit = want in got if want else None
        if got:
            any_fired += 1
        if want:
            if hit:
                tp += 1
            else:
                fn += 1
        if want and re.search(rf"/{re.escape(want)}\b|\b{re.escape(want)}\b", r["final"]):
            named += 1
        # Skills the reply mentions as a slash command but never loaded: the
        # router knew the skill existed and declined to invoke it.
        mentioned = {m for m in re.findall(r"/([a-z][a-z0-9-]{2,})\b", r["final"]) if m in owned}
        named_any_total += len(mentioned - set(got))
        if mentioned - set(got):
            named_any += 1
        allowed = fanout.get(want, set()) if want else set()
        for peer in PEERS.get(cid, []):
            if peer == want:
                continue
            if peer in got and peer not in allowed:
                peer_fp += 1
            else:
                peer_tn += 1
        wrong = [s for s in got if s != want and s not in allowed]
        fp += len(wrong)
        if wrong:
            wrong_runs.append((r["case"], want, wrong))
        for s in owned:
            cell = per_skill[s]
            if want == s:
                cell["tp" if s in got else "fn"] += 1
            elif s in allowed:
                continue  # documented fan-out of the intended skill
            else:
                cell["fp" if s in got else "tn"] += 1
        mark = "-" if want is None else ("YES" if hit else "no")
        print(f"{r['case']:8s} {str(want):14s} {mark:15s} {', '.join(got) or '(none)'}")

    n = len(runs)
    pos = sum(1 for r in runs if INTENDED[r["case"].split('-')[0]])
    print("\n== pooled ==")
    print(f"runs                        {n}")
    print(f"runs firing any owned skill {any_fired}  ({100*any_fired//n}%)  <- degeneracy check, floor 20%")
    print(f"TP (intended fired)         {tp} / {pos}")
    print(f"FN (intended missed)        {fn} / {pos}")
    print(f"FP (wrong owned skill)      {fp}")
    print(f"TPR (recall)                {tp/pos:.3f}" if pos else "")
    neg_cells = sum(c["tn"] + c["fp"] for c in per_skill.values())
    tn_cells = sum(c["tn"] for c in per_skill.values())
    print(f"TNR (pooled over skills)    {tn_cells/neg_cells:.4f}  (TN={tn_cells} FP={sum(c['fp'] for c in per_skill.values())})")
    prec_den = tp + fp
    print(f"Precision (case-level)      {tp/prec_den:.3f}" if prec_den else "Precision                   n/a")
    print(f"Accuracy (intended fired)   {tp/n:.3f}")
    print()
    print(f"TNR (neighbour-scoped)      {peer_tn/(peer_tn+peer_fp):.3f}  (TN={peer_tn} FP={peer_fp})")
    # pos is 0 when every graded run's intended target is not an owned skill
    # (e.g. only B2 has finished), so the percentages must be guarded.
    pct = lambda k: f"{100 * k // pos}%" if pos else "n/a"
    print(f"Reply NAMES intended skill  {named} / {pos}   ({pct(named)})  <- awareness proxy")
    print(f"  ... vs actually invoked   {tp} / {pos}   ({pct(tp)})")
    print(f"Runs naming a /skill they did NOT invoke  {named_any} / {n}  ({named_any_total} mentions)")

    print("\n== false positives by run ==")
    for case, want, wrong in wrong_runs:
        print(f"  {case:8s} intended={want}  fired={', '.join(wrong)}")
    if not wrong_runs:
        print("  (none)")

    print("\n== per-skill (non-zero rows) ==")
    print(f"{'skill':22s} {'TP':>3s} {'FN':>3s} {'FP':>3s} {'TN':>4s}")
    for s in sorted(per_skill):
        c = per_skill[s]
        if c["tp"] or c["fn"] or c["fp"]:
            print(f"{s:22s} {c['tp']:3d} {c['fn']:3d} {c['fp']:3d} {c['tn']:4d}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
