"""Enforce the plugin warning policy against Claude's structured validator output."""
import json
import sys


def unexpected_findings(report):
    findings = []
    if report.get("success") is not True:
        findings.append("validation did not succeed")
    for result in [report.get("manifest") or {}, *report.get("contents", [])]:
        findings.extend(result.get("errors", []))
        findings.extend(
            warning for warning in result.get("warnings", [])
            if not warning.get("message", "").startswith(
                "CLAUDE.md at the plugin root is not loaded"
            )
        )
    directory = report.get("directory") or {}
    findings.extend(
        finding for finding in directory.get("findings", [])
        if not (finding.get("code") == "ICON_MISSING"
                and finding.get("severity") == "warning")
    )
    if directory.get("incomplete") or directory.get("failure"):
        findings.append("plugin directory checks did not complete")
    # directory.notes are informational context (for example README inheritance),
    # not warnings. Text output uses the same bullet marker for both categories.
    return findings


if __name__ == "__main__":
    try:
        findings = unexpected_findings(json.load(sys.stdin))
    except (ValueError, TypeError, AttributeError) as error:
        print(f"invalid validation report: {error}", file=sys.stderr)
        sys.exit(1)
    if findings:
        print(json.dumps(findings, indent=2))
        sys.exit(1)
