#!/usr/bin/env python3
"""qa-full-token-audit.py — per-run token sums and context attribution over
Claude Code subagent transcripts (stdlib only).

Usage: python3 qa-full-token-audit.py <transcripts-dir> [arm-prefix ...]

Classifies each agent-*.jsonl by its first user message: a /qa-full run
("pre-ship QA pipeline as a test" or "brief.txt and follow it" plus an fx/
fixture path), a child agent of a run (brief references the same fx/ path), or
unrelated. Sums input+cache_creation+cache_read ("run tokens") and output per
assistant message, and attributes tool-result and attachment (hook/skill-body)
bytes back to the call that produced them. With arm prefixes, prints combined
attribution for those runs; otherwise prints the per-run table and arm medians.

Method notes: run tokens include cache reads, so they measure processing
volume, not billed cost. Bytes are a proxy (~4 chars per token). Wrote the
2026-11-12 token audit (evals/reports/2026-11-12-qa-full-token-audit-RESULTS.md).
"""
import json, os, re, sys, statistics

RUN_PAT = re.compile(r"pre-ship QA pipeline as a test|brief\.txt and follow it")
FIX_PAT = re.compile(r"fx/([A-Za-z0-9_-]+)")
STEP_PAT = re.compile(r"qa-full step file (steps/\S+)")
SKILL_PAT = re.compile(r"^name:\s*([a-z0-9-]+)", re.M)
CD_PAT = re.compile(r"^\s*cd\s+\S+\s*&&\s*")


def first_user_text(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if o.get("type") != "user":
                continue
            m = o.get("message") or {}
            c = m.get("content")
            if isinstance(c, str):
                return c
            if isinstance(c, list):
                t = " ".join(x.get("text", "") for x in c
                             if isinstance(x, dict) and x.get("type") == "text")
                if t.strip():
                    return t
    return ""


def usage_of(o):
    u = (o.get("message") or {}).get("usage") or o.get("usage") or {}
    def g(k):
        v = u.get(k)
        return v if isinstance(v, (int, float)) else 0
    return (g("input_tokens"), g("cache_creation_input_tokens"),
            g("cache_read_input_tokens"), g("output_tokens"))


def content_blocks(o):
    c = (o.get("message") or {}).get("content")
    return c if isinstance(c, list) else []


def result_size(r):
    c = r.get("content")
    n = 0
    if isinstance(c, str):
        n = len(c)
    elif isinstance(c, list):
        for x in c:
            if isinstance(x, dict) and isinstance(x.get("text"), str):
                n += len(x["text"])
    return n


def bash_target(cmd):
    cmd = CD_PAT.sub("", cmd or "")
    words = cmd.split()
    head = words[0] if words else "?"
    if head == "git" and len(words) > 1:
        head = "git " + words[1]
    return "bash:" + head


def target_of(use):
    name = use.get("name", "?")
    inp = use.get("input") or {}
    if name == "Skill":
        return "skill-call:" + str(inp.get("skill", "?"))
    if name == "Read":
        return "read:" + os.path.basename(str(inp.get("file_path", "?")))
    if name == "Task":
        return "task:" + str(inp.get("subagent_type") or "general")
    if name == "Bash":
        return bash_target(str(inp.get("command", "")))
    return name.lower()


def classify_attachment(text):
    m = STEP_PAT.search(text)
    if m:
        return "hook-step:" + m.group(1)
    sm = SKILL_PAT.search(text[:400])
    if sm:
        return "skill-body:" + sm.group(1)
    return "attachment:other"


def scan(path):
    st = {"in": 0, "cc": 0, "cr": 0, "out": 0, "turns": 0, "final_ctx": 0,
          "attrib": {}}
    pending = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            t = o.get("type")
            if t == "assistant":
                i, cc, cr, out = usage_of(o)
                if i or cc or cr or out:
                    st["in"] += i; st["cc"] += cc; st["cr"] += cr
                    st["out"] += out; st["turns"] += 1
                    st["final_ctx"] = i + cc + cr
                for u in content_blocks(o):
                    if isinstance(u, dict) and u.get("type") == "tool_use":
                        pending[u.get("id")] = target_of(u)
            elif t == "user":
                for r in content_blocks(o):
                    if isinstance(r, dict) and r.get("type") == "tool_result":
                        tgt = pending.pop(r.get("tool_use_id"), "?")
                        st["attrib"][tgt] = st["attrib"].get(tgt, 0) + result_size(r)
            elif t == "attachment":
                txt = (o.get("attachment") or {}).get("stdout") or ""
                if isinstance(txt, str) and txt:
                    tgt = classify_attachment(txt)
                    st["attrib"][tgt] = st["attrib"].get(tgt, 0) + len(txt)
    return st


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    subs = sys.argv[1]
    prefixes = sys.argv[2:]
    files = sorted(os.path.join(subs, f) for f in os.listdir(subs)
                   if f.startswith("agent-") and f.endswith(".jsonl"))
    runs, children, misc = {}, {}, 0
    for p in files:
        brief = first_user_text(p)
        fix = FIX_PAT.search(brief)
        if RUN_PAT.search(brief) and fix:
            runs[fix.group(1)] = {"path": p}
        elif fix:
            children.setdefault(fix.group(1), []).append(p)
        else:
            misc += 1

    if prefixes:
        agg = {}
        for fix, r in runs.items():
            if not fix.startswith(tuple(prefixes)):
                continue
            for k, v in scan(r["path"])["attrib"].items():
                agg[k] = agg.get(k, 0) + v
        total = sum(agg.values())
        print(f"(combined tool-result + attachment bytes: {total:,})")
        for tgt, n in sorted(agg.items(), key=lambda kv: -kv[1]):
            print(f"  {n:>10,d}  {100*n/max(total,1):4.1f}%  {tgt}")
        return

    print(f"== {len(runs)} qa-full runs, {sum(len(v) for v in children.values())} child agents, {misc} unrelated ==\n")
    print("fixture      | run in+cc+cr (M) | run out | final ctx | children | child in+cc+cr (M)")
    arm_stats = {}
    for fix in sorted(runs):
        st = scan(runs[fix]["path"])
        ch = ch_in = ch_cc = ch_cr = 0
        for cp in children.get(fix, []):
            cs = scan(cp)
            ch += 1; ch_in += cs["in"]; ch_cc += cs["cc"]; ch_cr += cs["cr"]
        m = (st["in"] + st["cc"] + st["cr"]) / 1e6
        chm = (ch_in + ch_cc + ch_cr) / 1e6
        print(f"{fix:<12} | {m:16.2f} | {st['out']:>7,d} | {st['final_ctx']:>9,d} | "
              f"{ch:>7} | {chm:18.2f}")
        arm = fix.rsplit("-", 1)[0]
        a = arm_stats.setdefault(arm, {"runm": [], "chm": [], "out": [], "ctx": []})
        a["runm"].append(m); a["chm"].append(chm); a["out"].append(st["out"]); a["ctx"].append(st["final_ctx"])

    print("\n== arm medians (run tokens M | child M | out | final ctx) ==")
    for arm, a in sorted(arm_stats.items()):
        if a["runm"]:
            print(f"{arm:<10} n={len(a['runm'])}  run={statistics.median(a['runm']):.2f}M  "
                  f"child={statistics.median(a['chm']):.2f}M  out={int(statistics.median(a['out'])):,}  "
                  f"ctx={int(statistics.median(a['ctx'])):,}")


if __name__ == "__main__":
    main()
