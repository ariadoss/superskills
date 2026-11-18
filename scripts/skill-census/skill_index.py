#!/usr/bin/env python3
"""Load skills from the flat trees of a superskills checkout.

Usage: skill_index.py <repo_root>
Prints one line per skill: name <TAB> relative_dir <TAB> description_bytes <TAB> total_bytes
Only skills/ and design-skills/ are walked. vendor/, marketing-skills/,
plugin-skills/, dist/ and node_modules are never entered. Paths come from the
directory walk, never from frontmatter, so a hostile name cannot steer a path.
"""
import re
import sys
from pathlib import Path

TREES = ("skills", "design-skills")
TOP_KEY = re.compile(r"^([A-Za-z_-]+):\s*(.*)$")
BLOCK = {"|", ">", "|-", ">-"}


def parse_frontmatter(text):
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}
    out, key = {}, None
    for line in lines[1:]:
        if line.strip() == "---":
            break
        m = TOP_KEY.match(line)
        if m and not line.startswith(" "):
            key, val = m.group(1), m.group(2).strip()
            out[key] = "" if val in BLOCK else val.strip("\"'")
        elif key is not None:
            out[key] = (out[key] + " " + line.strip()).strip()
    return out


def load_skills(root):
    skills = []
    for tree in TREES:
        for md in sorted(Path(root, tree).glob("*/SKILL.md")):
            if md.parent.name == "node_modules" or not md.is_file():
                continue
            text = md.read_text(encoding="utf-8", errors="replace")
            fm = parse_frontmatter(text)
            # Matches bash skill_name_from (whitespace removed, empty falls
            # back to the directory). Accepted divergences: a quoted name is
            # unquoted here (bash keeps the quotes), and a `name:` line outside
            # the frontmatter is ignored here (bash greps the whole file).
            name = "".join(fm.get("name", "").split()) or md.parent.name
            skills.append({
                "name": name,
                "dir": f"{tree}/{md.parent.name}",
                "description": fm.get("description", ""),
                "triggers": fm.get("triggers", ""),
                "bytes": len(text.encode("utf-8")),
            })
    return skills


def main(argv):
    if len(argv) != 2:
        print("usage: skill_index.py <repo_root>", file=sys.stderr)
        return 2
    for s in load_skills(argv[1]):
        print(f"{s['name']}\t{s['dir']}\t{len(s['description'])}\t{s['bytes']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
