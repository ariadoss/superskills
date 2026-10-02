"""Tests for campaign runner and orchestration (spec 012)."""

from __future__ import annotations

import json
import tempfile
import time
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from clearwing.sourcehunt.campaign import (
    CampaignCheckpoint,
    CampaignResult,
    CampaignRunner,
    ProjectState,
    load_checkpoint,
    save_checkpoint,
)
from clearwing.sourcehunt.campaign_config import CampaignConfig, CampaignTargetConfig


def _make_config(**kwargs) -> CampaignConfig:
    defaults = {
        "name": "test-campaign",
        "budget": 1000.0,
        "max_concurrent_containers": 10,
        "depth": "standard",
        "targets": [CampaignTargetConfig(repo="https://github.com/test/repo")],
    }
    defaults.update(kwargs)
    return CampaignConfig(**defaults)


# --- Dataclass tests ----------------------------------------------------------


class TestProjectState:
    def test_defaults(self):
        ps = ProjectState(repo="https://repo")
        assert ps.status == "queued"
        assert ps.cost_usd == 0.0
        assert ps.findings_count == 0
        assert ps.start_time is None


class TestCampaignResult:
    def test_construction(self):
        r = CampaignResult(
            campaign_name="test",
            campaign_session_id="campaign-abc",
            status="completed",
            total_cost_usd=500.0,
            duration_seconds=3600.0,
            projects_completed=2,
            projects_total=3,
            total_findings=10,
            total_verified=5,
            per_project_results={},
            output_paths={},
            findings_pool_stats={"total_findings": 10},
            stopping_reason=None,
        )
        assert r.status == "completed"
        assert r.total_cost_usd == 500.0
        assert r.stopping_reason is None


# --- Checkpoint tests ---------------------------------------------------------


class TestCheckpoint:
    def test_save_and_load(self):
        with tempfile.TemporaryDirectory() as td:
            checkpoint_dir = Path(td) / "campaign-test"
            cp = CampaignCheckpoint(
                campaign_name="test",
                campaign_session_id="campaign-abc",
                timestamp=time.time(),
                completed_projects=["repo-a"],
                per_project_state={
                    "repo-a": ProjectState(
                        repo="repo-a", status="completed",
                        cost_usd=100.0, findings_count=5,
                    ),
                    "repo-b": ProjectState(repo="repo-b", status="queued"),
                },
                budget_spent=100.0,
                findings_pool_path="/tmp/pool.jsonl",
                recent_runs_count=50,
                recent_new_findings=3,
            )
            save_checkpoint(cp, checkpoint_dir)

            loaded = load_checkpoint(checkpoint_dir)
            assert loaded is not None
            assert loaded.campaign_name == "test"
            assert loaded.budget_spent == 100.0
            assert loaded.completed_projects == ["repo-a"]
            assert loaded.per_project_state["repo-a"].status == "completed"
            assert loaded.per_project_state["repo-a"].cost_usd == 100.0
            assert loaded.per_project_state["repo-b"].status == "queued"
            assert loaded.recent_runs_count == 50

    def test_load_missing(self):
        with tempfile.TemporaryDirectory() as td:
            result = load_checkpoint(Path(td))
            assert result is None

    def test_save_atomic(self):
        with tempfile.TemporaryDirectory() as td:
            checkpoint_dir = Path(td) / "campaign-test"
            cp = CampaignCheckpoint(
                campaign_name="test",
                campaign_session_id="x",
                timestamp=time.time(),
                completed_projects=[],
                per_project_state={},
                budget_spent=0.0,
                findings_pool_path="",
            )
            save_checkpoint(cp, checkpoint_dir)
            assert (checkpoint_dir / "checkpoint.json").exists()
            # No .tmp files left behind
            tmp_files = list(checkpoint_dir.glob("*.tmp"))
            assert len(tmp_files) == 0


# --- Stopping rules -----------------------------------------------------------


class TestStoppingRules:
    def test_budget_exhausted(self):
        config = _make_config(budget=100.0)
        runner = CampaignRunner(config)
        runner._budget_spent = 100.0
        assert runner._check_stopping_rules() == "budget_exhausted"

    def test_budget_not_exhausted(self):
        config = _make_config(budget=100.0)
        runner = CampaignRunner(config)
        runner._budget_spent = 50.0
        assert runner._check_stopping_rules() is None

    def test_diminishing_returns(self):
        config = _make_config(
            diminishing_returns_window=100,
            diminishing_returns_threshold=0.05,
        )
        runner = CampaignRunner(config)
        runner._recent_runs = 200
        runner._recent_new_findings = 2  # rate = 0.01 < 0.05
        result = runner._check_stopping_rules()
        assert result is not None
        assert "diminishing_returns" in result

    def test_diminishing_returns_below_window(self):
        config = _make_config(
            diminishing_returns_window=100,
            diminishing_returns_threshold=0.05,
        )
        runner = CampaignRunner(config)
        runner._recent_runs = 50  # below window
        runner._recent_new_findings = 0
        assert runner._check_stopping_rules() is None

    def test_triage_backlog(self):
        config = _make_config(triage_backlog_limit=10)
        runner = CampaignRunner(config)
        mock_pool = MagicMock()
        mock_pool.pool_stats.return_value = {"unique_findings": 15}
        runner._findings_pool = mock_pool
        assert runner._check_stopping_rules() == "triage_backlog"

    def test_no_stopping_conditions(self):
        config = _make_config(budget=10000.0)
        runner = CampaignRunner(config)
        runner._budget_spent = 100.0
        runner._recent_runs = 50
        runner._recent_new_findings = 10
        assert runner._check_stopping_rules() is None


# --- Pause/resume mechanics ---------------------------------------------------


class TestPauseResume:
    def test_pause_clears_event(self):
        config = _make_config()
        runner = CampaignRunner(config)
        assert runner._pause_event.is_set()
        runner.pause()
        assert not runner._pause_event.is_set()

    def test_resume_sets_event(self):
        config = _make_config()
        runner = CampaignRunner(config)
        runner.pause()
        runner.resume()
        assert runner._pause_event.is_set()


# --- Runner injection ---------------------------------------------------------


class TestRunnerInjection:
    def test_inject_campaign_pool(self):
        from clearwing.sourcehunt.runner import SourceHuntRunner

        runner = SourceHuntRunner(repo_url="test", depth="standard")
        mock_pool = MagicMock()
        mock_db = MagicMock()
        runner._inject_campaign_pool(mock_pool, mock_db)
        assert runner._injected_findings_pool is mock_pool
        assert runner._injected_historical_db is mock_db

    def test_inject_defaults_to_none(self):
        from clearwing.sourcehunt.runner import SourceHuntRunner

        runner = SourceHuntRunner(repo_url="test", depth="standard")
        assert runner._injected_findings_pool is None
        assert runner._injected_historical_db is None


# --- Campaign runner integration (mocked) ------------------------------------


class TestCampaignRunnerIntegration:
    @pytest.mark.asyncio
    async def test_single_target_mocked(self):
        config = _make_config(
            targets=[CampaignTargetConfig(repo="https://github.com/test/repo")],
        )
        runner = CampaignRunner(config)

        mock_result = MagicMock()
        mock_result.cost_usd = 50.0
        mock_result.files_hunted = 10
        mock_result.findings = [{"id": "f1"}, {"id": "f2"}]
        mock_result.verified_findings = [{"id": "f1"}]

        with patch(
            "clearwing.sourcehunt.campaign.CampaignRunner._run_project",
            new_callable=AsyncMock,
            return_value=mock_result,
        ):
            result = await runner.arun()

        assert result.campaign_name == "test-campaign"
        assert isinstance(result, CampaignResult)

    @pytest.mark.asyncio
    async def test_project_states_initialized(self):
        config = _make_config(
            targets=[
                CampaignTargetConfig(repo="repo-a"),
                CampaignTargetConfig(repo="repo-b"),
            ],
        )
        runner = CampaignRunner(config)
        assert "repo-a" in runner._project_states
        assert "repo-b" in runner._project_states
        assert runner._project_states["repo-a"].status == "queued"


# --- CLI registration ---------------------------------------------------------


class TestCLIRegistration:
    def test_campaign_in_all_commands(self):
        from clearwing.ui.commands import ALL_COMMANDS, campaign
        assert campaign in ALL_COMMANDS

    def test_run_subcommand(self):
        import argparse
        from clearwing.ui.commands import campaign

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        campaign.add_parser(subs)
        args = parser.parse_args(["campaign", "run", "campaign.yaml"])
        assert args.campaign_action == "run"
        assert args.config_file == "campaign.yaml"

    def test_status_subcommand(self):
        import argparse
        from clearwing.ui.commands import campaign

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        campaign.add_parser(subs)
        args = parser.parse_args(["campaign", "status", "campaign.yaml"])
        assert args.campaign_action == "status"

    def test_resume_subcommand(self):
        import argparse
        from clearwing.ui.commands import campaign

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        campaign.add_parser(subs)
        args = parser.parse_args(["campaign", "resume", "campaign.yaml"])
        assert args.campaign_action == "resume"

    def test_dry_run_flag(self):
        import argparse
        from clearwing.ui.commands import campaign

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        campaign.add_parser(subs)
        args = parser.parse_args(["campaign", "run", "campaign.yaml", "--dry-run"])
        assert args.dry_run is True
