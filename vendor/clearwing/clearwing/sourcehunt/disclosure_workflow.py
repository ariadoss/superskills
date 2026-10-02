"""Disclosure workflow lifecycle management — spec 011.

Orchestrates human-validation and coordinated-disclosure on top of
DisclosureDB. Provides review context formatting, state transitions,
batching rules, and timeline alerting.
"""

from __future__ import annotations

import json
import logging
import time
from datetime import datetime, timezone
from typing import Any

from .disclosure import DisclosureGenerator
from .disclosure_db import DisclosureDB, _DAY
from .state import DisclosureState

logger = logging.getLogger(__name__)

_ALERT_DAYS = [60, 75, 90, 120]
_MAX_BATCH_SIZE = 5


class DisclosureWorkflow:
    """Human-validation and coordinated-disclosure lifecycle."""

    def __init__(self, db: DisclosureDB, *, max_batch_size: int = _MAX_BATCH_SIZE):
        self._db = db
        self._max_batch_size = max_batch_size

    def format_review_context(self, finding_id: str) -> str:
        """Build human-readable review context for a finding."""
        finding = self._db.get_finding(finding_id)
        if finding is None:
            return f"Finding {finding_id} not found."

        reviews = self._db.get_reviews(finding_id)
        timeline = self._db.get_timeline(finding_id)

        lines = [
            f"# Review: {finding_id}",
            "",
            f"**State:** {finding['state']}",
            f"**Priority:** {finding['priority_score']:.0f}",
            f"**Repo:** {finding['repo_url']}",
            f"**File:** {finding.get('file', '?')}:{finding.get('line_number', '?')}",
            f"**Type:** {finding.get('finding_type', '?')}",
            f"**CWE:** {finding.get('cwe', 'N/A')}",
            f"**Severity:** {finding.get('severity', '?')}",
        ]
        if finding.get("severity_verified"):
            lines.append(f"**Severity (validated):** {finding['severity_verified']}")
        if finding.get("severity_disagreement"):
            lines.append(f"**Severity disagreement:** {finding['severity_disagreement']}")
        lines.append(f"**Evidence:** {finding.get('evidence_level', '?')}")
        lines.append("")

        if finding.get("stability_classification"):
            rate = (finding.get("stability_success_rate") or 0) * 100
            lines.append(
                f"**Stability:** {finding['stability_classification']} "
                f"({rate:.0f}% reproduction rate)"
            )
            lines.append("")

        lines.append("## Description")
        lines.append(finding.get("description") or "(no description)")
        lines.append("")

        if finding.get("crash_evidence"):
            lines.append("## Crash Evidence")
            lines.append("```")
            lines.append(finding["crash_evidence"][:2000])
            lines.append("```")
            lines.append("")

        if finding.get("poc"):
            lines.append("## PoC")
            lines.append("```")
            lines.append(finding["poc"][:2000])
            lines.append("```")
            lines.append("")

        if reviews:
            lines.append("## Review History")
            for r in reviews:
                ts = datetime.fromtimestamp(r["timestamp"], tz=timezone.utc)
                lines.append(
                    f"- [{ts:%Y-%m-%d %H:%M}] {r['action']} by {r['reviewer']}"
                    + (f": {r['reason']}" if r.get("reason") else "")
                )
            lines.append("")

        if timeline:
            lines.append("## Timeline")
            if timeline.get("disclosed_at"):
                ts = datetime.fromtimestamp(timeline["disclosed_at"], tz=timezone.utc)
                lines.append(f"- Disclosed: {ts:%Y-%m-%d}")
            if timeline.get("deadline_90"):
                ts = datetime.fromtimestamp(timeline["deadline_90"], tz=timezone.utc)
                lines.append(f"- 90-day deadline: {ts:%Y-%m-%d}")
            if timeline.get("extension_granted") and timeline.get("deadline_extended"):
                ts = datetime.fromtimestamp(timeline["deadline_extended"], tz=timezone.utc)
                lines.append(f"- Extended deadline: {ts:%Y-%m-%d}")
            lines.append("")

        return "\n".join(lines)

    def validate(
        self,
        finding_id: str,
        reviewer: str = "cli",
        notes: str = "",
    ) -> None:
        """Mark finding as validated by a human reviewer."""
        self._db.transition(
            finding_id, DisclosureState.VALIDATED, reviewer, notes,
        )

    def reject(
        self,
        finding_id: str,
        reviewer: str = "cli",
        reason: str = "",
    ) -> None:
        """Mark finding as rejected."""
        self._db.transition(
            finding_id, DisclosureState.REJECTED, reviewer, reason,
        )

    def request_revision(
        self,
        finding_id: str,
        reviewer: str = "cli",
        reason: str = "",
    ) -> None:
        """Send finding back for revision."""
        self._db.transition(
            finding_id, DisclosureState.NEEDS_REVISION, reviewer, reason,
        )

    def prepare_disclosure_batch(
        self,
        batch_key: str,
        repo_url: str = "",
    ) -> list[dict]:
        """Get validated findings ready for disclosure, respecting batching rules.

        - Critical findings are always included (no batching delay)
        - Max 5 non-critical findings per batch
        """
        all_in_batch = self._db.get_batch(batch_key)
        validated = [
            f for f in all_in_batch
            if f["state"] == DisclosureState.VALIDATED.value
        ]

        critical = [
            f for f in validated
            if (f.get("severity_verified") or f.get("severity") or "").lower() == "critical"
        ]
        non_critical = [
            f for f in validated
            if f not in critical
        ]

        return critical + non_critical[:self._max_batch_size]

    def send_disclosure(
        self,
        finding_id: str,
        reviewer: str = "cli",
        repo_url: str = "",
        reporter_name: str = "(your name)",
        reporter_affiliation: str = "(your affiliation)",
        reporter_email: str = "(your email)",
    ) -> dict[str, str]:
        """Mark as disclosed, start 90-day timeline, generate templates.

        Returns dict with 'mitre' and 'hackerone' template bodies.
        """
        finding_row = self._db.get_finding(finding_id)
        if finding_row is None:
            raise ValueError(f"Finding {finding_id} not found")

        finding_json = finding_row.get("finding_json")
        if finding_json:
            finding_dict = json.loads(finding_json)
        else:
            finding_dict = dict(finding_row)

        self._db.transition(
            finding_id, DisclosureState.PENDING_DISCLOSURE, reviewer,
            "preparing disclosure",
        )
        self._db.transition(
            finding_id, DisclosureState.DISCLOSED, reviewer,
            "disclosure sent",
        )
        self._db.start_timeline(finding_id)

        generator = DisclosureGenerator(
            repo_url=repo_url or finding_row.get("repo_url", ""),
            reporter_name=reporter_name,
            reporter_affiliation=reporter_affiliation,
            reporter_email=reporter_email,
        )
        bundle = generator.generate_bundle([finding_dict])
        templates: dict[str, str] = {}
        for tmpl in bundle.templates:
            templates[tmpl.format] = tmpl.body

        return templates

    def check_timeline_alerts(self) -> list[dict[str, Any]]:
        """Return findings with approaching or passed deadlines."""
        now = time.time()
        alerts: list[dict[str, Any]] = []

        rows = self._db.get_queue(state=None)
        for row in rows:
            if row["state"] not in (
                DisclosureState.DISCLOSED.value,
                DisclosureState.ACKNOWLEDGED.value,
                DisclosureState.PATCH_IN_PROGRESS.value,
            ):
                continue
            timeline = self._db.get_timeline(row["id"])
            if not timeline or not timeline.get("disclosed_at"):
                continue

            disclosed_at = timeline["disclosed_at"]
            deadline = timeline.get("deadline_extended") or timeline.get("deadline_90")
            if not deadline:
                continue

            days_elapsed = (now - disclosed_at) / _DAY
            days_remaining = (deadline - now) / _DAY

            for alert_day in _ALERT_DAYS:
                if days_elapsed >= alert_day:
                    alerts.append({
                        "finding_id": row["id"],
                        "repo_url": row["repo_url"],
                        "severity": row.get("severity_verified") or row.get("severity"),
                        "days_elapsed": int(days_elapsed),
                        "days_remaining": int(days_remaining),
                        "alert_day": alert_day,
                        "state": row["state"],
                        "deadline": datetime.fromtimestamp(
                            deadline, tz=timezone.utc,
                        ).strftime("%Y-%m-%d"),
                    })
                    break

        return alerts

    def get_dashboard(self) -> dict[str, Any]:
        """Aggregate stats for the CLI status display."""
        stats = self._db.get_dashboard_stats()
        approaching = self._db.get_approaching_deadlines(30)
        stats["approaching_deadlines"] = len(approaching)
        return stats
