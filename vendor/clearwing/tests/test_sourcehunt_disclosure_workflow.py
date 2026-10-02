"""Tests for disclosure workflow (spec 011).

Covers:
- DisclosureDB: queue, dedup, priority scoring, transitions, timelines
- DisclosureWorkflow: validate, reject, review context, send, batching, alerts
- CLI registration
"""

from __future__ import annotations

import json
import sqlite3
import tempfile
import time
from pathlib import Path

import pytest

from clearwing.sourcehunt.disclosure_db import DisclosureDB, _compute_priority
from clearwing.sourcehunt.disclosure_workflow import DisclosureWorkflow
from clearwing.sourcehunt.state import DisclosureState


def _make_finding(**kwargs) -> dict:
    base = {
        "id": "hunter-abc",
        "file": "src/codec.c",
        "line_number": 42,
        "finding_type": "memory_safety",
        "cwe": "CWE-787",
        "severity": "high",
        "description": "heap-buffer-overflow in memcpy",
        "code_snippet": "memcpy(dst, src, len);",
        "crash_evidence": "==1==ERROR: AddressSanitizer: heap-buffer-overflow",
        "poc": "AAAA" * 100,
        "evidence_level": "crash_reproduced",
        "verified": True,
    }
    base.update(kwargs)
    return base


def _tmp_db() -> DisclosureDB:
    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    return DisclosureDB(path=Path(tmp.name))


# --- DisclosureDB tests -------------------------------------------------------


class TestDisclosureDBQueue:
    def test_queue_findings(self):
        db = _tmp_db()
        try:
            findings = [_make_finding(id="f1"), _make_finding(id="f2")]
            count = db.queue_findings(findings, "https://repo", "sess-1")
            assert count == 2
            queue = db.get_queue()
            assert len(queue) == 2
            assert all(f["state"] == "pending_review" for f in queue)
        finally:
            db.close()

    def test_queue_dedup(self):
        db = _tmp_db()
        try:
            findings = [_make_finding(id="f1")]
            db.queue_findings(findings, "https://repo", "sess-1")
            count = db.queue_findings(findings, "https://repo", "sess-2")
            assert count == 1  # INSERT OR IGNORE succeeds but doesn't insert
            queue = db.get_queue()
            assert len(queue) == 1
        finally:
            db.close()

    def test_queue_skips_empty_id(self):
        db = _tmp_db()
        try:
            count = db.queue_findings([_make_finding(id="")], "https://repo", "s")
            assert count == 0
        finally:
            db.close()


class TestPriorityScoring:
    def test_critical_highest(self):
        assert _compute_priority({"severity": "critical"}) > _compute_priority({"severity": "high"})

    def test_disagreement_boost(self):
        base = _compute_priority({"severity": "high"})
        boosted = _compute_priority({"severity": "high", "severity_disagreement": "high vs low"})
        assert boosted == base + 50

    def test_stable_boost(self):
        base = _compute_priority({"severity": "medium"})
        boosted = _compute_priority({"severity": "medium", "stability_classification": "stable"})
        assert boosted == base + 10

    def test_priority_ordering(self):
        db = _tmp_db()
        try:
            findings = [
                _make_finding(id="low", severity="low"),
                _make_finding(id="crit", severity="critical"),
                _make_finding(id="high", severity="high"),
            ]
            db.queue_findings(findings, "https://repo", "s")
            queue = db.get_queue()
            ids = [f["id"] for f in queue]
            assert ids[0] == "crit"
            assert ids[1] == "high"
            assert ids[2] == "low"
        finally:
            db.close()


class TestTransitions:
    def test_valid_transition(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            db.transition("f1", DisclosureState.IN_REVIEW, "alice")
            f = db.get_finding("f1")
            assert f["state"] == "in_review"
            reviews = db.get_reviews("f1")
            assert len(reviews) == 1
            assert reviews[0]["action"] == "in_review"
            assert reviews[0]["reviewer"] == "alice"
        finally:
            db.close()

    def test_invalid_transition_raises(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            with pytest.raises(ValueError, match="Invalid transition"):
                db.transition("f1", DisclosureState.DISCLOSED)
        finally:
            db.close()

    def test_nonexistent_finding_raises(self):
        db = _tmp_db()
        try:
            with pytest.raises(ValueError, match="not found"):
                db.transition("nonexistent", DisclosureState.IN_REVIEW)
        finally:
            db.close()

    def test_full_lifecycle(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            db.transition("f1", DisclosureState.IN_REVIEW, "alice")
            db.transition("f1", DisclosureState.VALIDATED, "alice", "looks good")
            db.transition("f1", DisclosureState.PENDING_DISCLOSURE, "alice")
            db.transition("f1", DisclosureState.DISCLOSED, "alice")
            f = db.get_finding("f1")
            assert f["state"] == "disclosed"
            reviews = db.get_reviews("f1")
            assert len(reviews) == 4
        finally:
            db.close()


class TestTimelines:
    def test_start_timeline(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            db.start_timeline("f1")
            tl = db.get_timeline("f1")
            assert tl is not None
            assert tl["disclosed_at"] is not None
            assert tl["deadline_90"] > tl["disclosed_at"]
            expected = tl["disclosed_at"] + 90 * 86400
            assert abs(tl["deadline_90"] - expected) < 1

        finally:
            db.close()

    def test_grant_extension(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            db.start_timeline("f1")
            db.grant_extension("f1")
            tl = db.get_timeline("f1")
            assert tl["extension_granted"] == 1
            expected = tl["deadline_90"] + 45 * 86400
            assert abs(tl["deadline_extended"] - expected) < 1
        finally:
            db.close()

    def test_extension_without_timeline_raises(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            with pytest.raises(ValueError, match="No timeline"):
                db.grant_extension("f1")
        finally:
            db.close()


class TestDashboard:
    def test_dashboard_stats(self):
        db = _tmp_db()
        try:
            db.queue_findings(
                [_make_finding(id="f1"), _make_finding(id="f2")],
                "https://repo", "s",
            )
            db.transition("f1", DisclosureState.IN_REVIEW)
            stats = db.get_dashboard_stats()
            assert stats["total"] == 2
            assert stats["by_state"]["pending_review"] == 1
            assert stats["by_state"]["in_review"] == 1
            assert stats["by_repo"]["https://repo"] == 2
        finally:
            db.close()


class TestBatch:
    def test_get_batch(self):
        db = _tmp_db()
        try:
            db.queue_findings(
                [_make_finding(id="f1"), _make_finding(id="f2")],
                "https://repo", "s",
            )
            batch = db.get_batch("https://repo")
            assert len(batch) == 2
        finally:
            db.close()


# --- DisclosureWorkflow tests -------------------------------------------------


class TestDisclosureWorkflow:
    def test_validate_transition(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            db.transition("f1", DisclosureState.IN_REVIEW)
            wf = DisclosureWorkflow(db)
            wf.validate("f1", "alice", "confirmed real")
            f = db.get_finding("f1")
            assert f["state"] == "validated"
        finally:
            db.close()

    def test_reject_transition(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            wf = DisclosureWorkflow(db)
            wf.reject("f1", "bob", "false positive")
            f = db.get_finding("f1")
            assert f["state"] == "rejected"
        finally:
            db.close()

    def test_review_context_format(self):
        db = _tmp_db()
        try:
            db.queue_findings(
                [_make_finding(
                    id="f1",
                    stability_classification="stable",
                    stability_success_rate=0.95,
                )],
                "https://repo", "s",
            )
            wf = DisclosureWorkflow(db)
            ctx = wf.format_review_context("f1")
            assert "f1" in ctx
            assert "stable" in ctx.lower()
            assert "heap-buffer-overflow" in ctx
            assert "CWE-787" in ctx
        finally:
            db.close()

    def test_review_context_not_found(self):
        db = _tmp_db()
        try:
            wf = DisclosureWorkflow(db)
            ctx = wf.format_review_context("nonexistent")
            assert "not found" in ctx.lower()
        finally:
            db.close()

    def test_send_disclosure_starts_timeline(self):
        db = _tmp_db()
        try:
            db.queue_findings(
                [_make_finding(id="f1", evidence_level="root_cause_explained")],
                "https://repo", "s",
            )
            db.transition("f1", DisclosureState.IN_REVIEW)
            db.transition("f1", DisclosureState.VALIDATED)
            wf = DisclosureWorkflow(db)
            templates = wf.send_disclosure("f1", repo_url="https://repo")
            f = db.get_finding("f1")
            assert f["state"] == "disclosed"
            tl = db.get_timeline("f1")
            assert tl is not None
            assert tl["disclosed_at"] is not None
            assert "mitre" in templates or "hackerone" in templates
        finally:
            db.close()

    def test_batch_max_5(self):
        db = _tmp_db()
        try:
            findings = [_make_finding(id=f"f{i}", severity="high") for i in range(8)]
            db.queue_findings(findings, "https://repo", "s")
            for f in findings:
                db.transition(f["id"], DisclosureState.IN_REVIEW)
                db.transition(f["id"], DisclosureState.VALIDATED)
            wf = DisclosureWorkflow(db)
            batch = wf.prepare_disclosure_batch("https://repo")
            assert len(batch) <= 5
        finally:
            db.close()

    def test_critical_not_batched(self):
        db = _tmp_db()
        try:
            findings = [
                _make_finding(id=f"crit{i}", severity="critical") for i in range(7)
            ]
            db.queue_findings(findings, "https://repo", "s")
            for f in findings:
                db.transition(f["id"], DisclosureState.IN_REVIEW)
                db.transition(f["id"], DisclosureState.VALIDATED)
            wf = DisclosureWorkflow(db)
            batch = wf.prepare_disclosure_batch("https://repo")
            assert len(batch) == 7  # critical bypasses max-5

        finally:
            db.close()

    def test_dashboard_aggregation(self):
        db = _tmp_db()
        try:
            db.queue_findings(
                [_make_finding(id="f1"), _make_finding(id="f2")],
                "https://repo", "s",
            )
            wf = DisclosureWorkflow(db)
            dash = wf.get_dashboard()
            assert dash["total"] == 2
            assert "approaching_deadlines" in dash
        finally:
            db.close()


class TestTimelineAlerts:
    def test_alerts_for_old_disclosures(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            db.transition("f1", DisclosureState.IN_REVIEW)
            db.transition("f1", DisclosureState.VALIDATED)
            db.transition("f1", DisclosureState.PENDING_DISCLOSURE)
            db.transition("f1", DisclosureState.DISCLOSED)
            db.start_timeline("f1")

            # Backdate the timeline to 65 days ago
            now = time.time()
            old = now - 65 * 86400
            db._conn.execute(
                "UPDATE timelines SET disclosed_at = ?, deadline_90 = ? WHERE finding_id = ?",
                (old, old + 90 * 86400, "f1"),
            )
            db._conn.commit()

            wf = DisclosureWorkflow(db)
            alerts = wf.check_timeline_alerts()
            assert len(alerts) == 1
            assert alerts[0]["finding_id"] == "f1"
            assert alerts[0]["alert_day"] == 60
        finally:
            db.close()

    def test_no_alerts_for_fresh_disclosures(self):
        db = _tmp_db()
        try:
            db.queue_findings([_make_finding(id="f1")], "https://repo", "s")
            db.transition("f1", DisclosureState.IN_REVIEW)
            db.transition("f1", DisclosureState.VALIDATED)
            db.transition("f1", DisclosureState.PENDING_DISCLOSURE)
            db.transition("f1", DisclosureState.DISCLOSED)
            db.start_timeline("f1")

            wf = DisclosureWorkflow(db)
            alerts = wf.check_timeline_alerts()
            assert len(alerts) == 0
        finally:
            db.close()


# --- CLI registration tests ---------------------------------------------------


class TestCLIRegistration:
    def test_disclose_in_all_commands(self):
        from clearwing.ui.commands import ALL_COMMANDS, disclose
        assert disclose in ALL_COMMANDS

    def test_add_parser(self):
        import argparse
        from clearwing.ui.commands import disclose

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        disclose.add_parser(subs)
        args = parser.parse_args(["disclose", "queue"])
        assert args.disclose_action == "queue"

    def test_validate_subcommand(self):
        import argparse
        from clearwing.ui.commands import disclose

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        disclose.add_parser(subs)
        args = parser.parse_args(["disclose", "validate", "finding-123", "--notes", "ok"])
        assert args.disclose_action == "validate"
        assert args.finding_id == "finding-123"
        assert args.notes == "ok"

    def test_timeline_subcommand(self):
        import argparse
        from clearwing.ui.commands import disclose

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        disclose.add_parser(subs)
        args = parser.parse_args(["disclose", "timeline", "--days", "60"])
        assert args.disclose_action == "timeline"
        assert args.days == 60
