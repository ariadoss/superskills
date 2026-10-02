"""Tests for preprocessing evaluation framework (spec 018)."""

from __future__ import annotations

import json
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from unittest.mock import MagicMock

import pytest

from clearwing.eval.metrics import (
    ConfigResult,
    ConfigRunResult,
    EvalMetrics,
    EvalResult,
    aggregate_runs,
    compute_metrics,
    format_eval_comparison,
    load_eval_result,
    save_eval_result,
)
from clearwing.eval.preprocessing import (
    CONFIGURATIONS,
    EvalConfig,
    PreprocessingEval,
    resolve_config,
)


# --- Helper: mock SourceHuntResult -------------------------------------------


def _make_hunt_result(
    findings=None,
    verified=None,
    exploited=None,
    cost_usd=0.0,
    duration_seconds=0.0,
    files_ranked=0,
    files_hunted=0,
):
    """Build a mock SourceHuntResult-like object."""
    r = MagicMock()
    r.findings = findings or []
    r.verified_findings = verified or []
    r.exploited_findings = exploited or []
    r.cost_usd = cost_usd
    r.duration_seconds = duration_seconds
    r.files_ranked = files_ranked
    r.files_hunted = files_hunted
    return r


def _make_finding(**kwargs):
    """Build a dict-style finding."""
    defaults = {
        "cwe": "",
        "severity": "medium",
        "severity_verified": None,
        "evidence_level": "suspicion",
    }
    defaults.update(kwargs)
    return defaults


# --- Metrics computation tests -----------------------------------------------


class TestComputeMetrics:
    def test_compute_metrics_from_result(self):
        findings = [_make_finding() for _ in range(10)]
        verified = [_make_finding(cwe="CWE-787") for _ in range(7)]
        exploited = [_make_finding() for _ in range(2)]

        result = _make_hunt_result(
            findings=findings,
            verified=verified,
            exploited=exploited,
            cost_usd=50.0,
            duration_seconds=120.0,
            files_ranked=100,
            files_hunted=20,
        )
        metrics = compute_metrics(result)
        assert metrics.findings_total == 10
        assert metrics.findings_verified == 7
        assert metrics.findings_exploited == 2
        assert metrics.cost_usd == 50.0
        assert metrics.duration_seconds == 120.0
        assert metrics.files_ranked == 100
        assert metrics.files_hunted == 20

    def test_compute_metrics_empty_result(self):
        result = _make_hunt_result()
        metrics = compute_metrics(result)
        assert metrics.findings_total == 0
        assert metrics.findings_verified == 0
        assert metrics.false_positive_rate == 0.0
        assert metrics.cost_per_finding == 0.0
        assert metrics.cwe_diversity == 0

    def test_false_positive_rate_calculation(self):
        findings = [_make_finding() for _ in range(10)]
        verified = [_make_finding() for _ in range(7)]
        result = _make_hunt_result(findings=findings, verified=verified)
        metrics = compute_metrics(result)
        assert abs(metrics.false_positive_rate - 0.3) < 0.001

    def test_cwe_diversity(self):
        verified = [
            _make_finding(cwe="CWE-787"),
            _make_finding(cwe="CWE-416"),
            _make_finding(cwe="CWE-787"),
            _make_finding(cwe="CWE-119"),
            _make_finding(cwe=""),
        ]
        result = _make_hunt_result(
            findings=verified, verified=verified, cost_usd=10.0,
        )
        metrics = compute_metrics(result)
        assert metrics.cwe_diversity == 3
        assert "CWE-787" in metrics.cwe_list
        assert "CWE-416" in metrics.cwe_list
        assert "CWE-119" in metrics.cwe_list

    def test_severity_distribution(self):
        verified = [
            _make_finding(severity="critical"),
            _make_finding(severity="critical"),
            _make_finding(severity="high"),
            _make_finding(severity="medium"),
        ]
        result = _make_hunt_result(findings=verified, verified=verified)
        metrics = compute_metrics(result)
        assert metrics.severity_distribution["critical"] == 2
        assert metrics.severity_distribution["high"] == 1
        assert metrics.severity_distribution["medium"] == 1

    def test_evidence_distribution(self):
        findings = [
            _make_finding(evidence_level="suspicion"),
            _make_finding(evidence_level="suspicion"),
            _make_finding(evidence_level="crash_reproduced"),
        ]
        result = _make_hunt_result(findings=findings)
        metrics = compute_metrics(result)
        assert metrics.evidence_distribution["suspicion"] == 2
        assert metrics.evidence_distribution["crash_reproduced"] == 1


# --- Aggregation tests -------------------------------------------------------


class TestAggregateRuns:
    def test_aggregate_runs_mean(self):
        runs = [
            EvalMetrics(findings_verified=5, cost_usd=10.0),
            EvalMetrics(findings_verified=7, cost_usd=20.0),
            EvalMetrics(findings_verified=9, cost_usd=30.0),
        ]
        mean, stddev = aggregate_runs(runs)
        assert mean.findings_verified == 7
        assert abs(mean.cost_usd - 20.0) < 0.001

    def test_aggregate_runs_stddev(self):
        runs = [
            EvalMetrics(findings_verified=2, cost_usd=10.0),
            EvalMetrics(findings_verified=8, cost_usd=20.0),
            EvalMetrics(findings_verified=5, cost_usd=15.0),
        ]
        _, stddev = aggregate_runs(runs)
        assert stddev["findings_verified"] > 0
        assert stddev["cost_usd"] > 0

    def test_aggregate_empty(self):
        mean, stddev = aggregate_runs([])
        assert mean.findings_verified == 0
        assert stddev == {}


# --- Save/load round-trip tests ----------------------------------------------


class TestSaveLoadRoundTrip:
    def test_save_load_round_trip(self):
        result = EvalResult(
            project="test-project",
            commit="abc123",
            model="test-model",
            budget_per_config=100.0,
            num_runs=2,
            timestamp="2024-01-01T00:00:00Z",
            configs=[
                ConfigResult(
                    config_name="glasswing_minimal",
                    runs=[
                        ConfigRunResult(
                            run_index=0,
                            metrics=EvalMetrics(
                                findings_verified=5,
                                cost_usd=10.0,
                                cwe_diversity=2,
                            ),
                        ),
                    ],
                    mean_metrics=EvalMetrics(findings_verified=5),
                    stddev={"findings_verified": 0.0},
                ),
            ],
            ground_truth_cves=["CVE-2024-1234"],
        )

        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            save_eval_result(result, f.name)
            loaded = load_eval_result(f.name)

        assert loaded.project == "test-project"
        assert loaded.commit == "abc123"
        assert loaded.model == "test-model"
        assert loaded.budget_per_config == 100.0
        assert loaded.num_runs == 2
        assert len(loaded.configs) == 1
        assert loaded.configs[0].config_name == "glasswing_minimal"
        assert loaded.configs[0].runs[0].metrics.findings_verified == 5
        assert loaded.ground_truth_cves == ["CVE-2024-1234"]


# --- Format tests ------------------------------------------------------------


class TestFormatEvalComparison:
    def _make_result(self):
        return EvalResult(
            project="ffmpeg",
            model="opus",
            budget_per_config=500.0,
            num_runs=1,
            configs=[
                ConfigResult(
                    config_name="glasswing_minimal",
                    mean_metrics=EvalMetrics(
                        findings_verified=10,
                        false_positive_rate=0.2,
                        cost_per_finding=50.0,
                        cwe_diversity=5,
                    ),
                ),
                ConfigResult(
                    config_name="sourcehunt_full",
                    mean_metrics=EvalMetrics(
                        findings_verified=8,
                        false_positive_rate=0.1,
                        cost_per_finding=62.5,
                        cwe_diversity=4,
                    ),
                ),
            ],
        )

    def test_format_table(self):
        result = self._make_result()
        output = format_eval_comparison(result, fmt="table")
        assert "glasswing_minimal" in output
        assert "sourcehunt_full" in output
        assert "ffmpeg" in output

    def test_format_json(self):
        result = self._make_result()
        output = format_eval_comparison(result, fmt="json")
        data = json.loads(output)
        assert data["project"] == "ffmpeg"
        assert len(data["configs"]) == 2

    def test_format_markdown(self):
        result = self._make_result()
        output = format_eval_comparison(result, fmt="markdown")
        assert "| Metric |" in output
        assert "glasswing_minimal" in output


# --- Config resolution tests -------------------------------------------------


class TestConfigResolution:
    def test_config_glasswing_minimal(self):
        cfg = resolve_config("glasswing_minimal")
        assert cfg.name == "glasswing_minimal"
        assert cfg.preprocessing is False
        assert cfg.prompt_mode == "unconstrained"
        assert cfg.seed_harness_crashes is False

    def test_config_sourcehunt_full(self):
        cfg = resolve_config("sourcehunt_full")
        assert cfg.name == "sourcehunt_full"
        assert cfg.preprocessing is True
        assert cfg.prompt_mode == "specialist"
        assert cfg.seed_harness_crashes is False

    def test_config_glasswing_plus_crashes(self):
        cfg = resolve_config("glasswing_plus_crashes")
        assert cfg.name == "glasswing_plus_crashes"
        assert cfg.preprocessing is False
        assert cfg.prompt_mode == "unconstrained"
        assert cfg.seed_harness_crashes is True

    def test_config_unknown_raises(self):
        with pytest.raises(ValueError, match="Unknown eval config"):
            resolve_config("nonexistent")

    def test_to_runner_kwargs(self):
        cfg = EvalConfig(
            name="test",
            prompt_mode="specialist",
            preprocessing=True,
            seed_harness_crashes=False,
        )
        kwargs = cfg.to_runner_kwargs()
        assert kwargs == {
            "prompt_mode": "specialist",
            "preprocessing": True,
            "seed_harness_crashes": False,
        }

    def test_configurations_registry_complete(self):
        assert "glasswing_minimal" in CONFIGURATIONS
        assert "sourcehunt_full" in CONFIGURATIONS
        assert "glasswing_plus_crashes" in CONFIGURATIONS


# --- Runner modification tests -----------------------------------------------


class TestRunnerFlags:
    def test_preprocessing_true_is_default(self):
        from clearwing.sourcehunt.runner import SourceHuntRunner
        runner = SourceHuntRunner(repo_url="https://example.com/repo")
        assert runner._preprocessing is True

    def test_preprocessing_false_stored(self):
        from clearwing.sourcehunt.runner import SourceHuntRunner
        runner = SourceHuntRunner(
            repo_url="https://example.com/repo",
            preprocessing=False,
        )
        assert runner._preprocessing is False

    def test_seed_harness_crashes_stored(self):
        from clearwing.sourcehunt.runner import SourceHuntRunner
        runner = SourceHuntRunner(
            repo_url="https://example.com/repo",
            seed_harness_crashes=True,
        )
        assert runner._seed_harness_crashes is True

    def test_seed_harness_crashes_default_false(self):
        from clearwing.sourcehunt.runner import SourceHuntRunner
        runner = SourceHuntRunner(repo_url="https://example.com/repo")
        assert runner._seed_harness_crashes is False


# --- CLI tests ---------------------------------------------------------------


class TestEvalCLI:
    def test_eval_preprocessing_flag(self):
        import argparse
        from clearwing.ui.commands import eval

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        eval.add_parser(subs)
        args = parser.parse_args([
            "eval", "preprocessing", "--project", "foo",
        ])
        assert args.eval_action == "preprocessing"
        assert args.project == "foo"

    def test_eval_configs_parsing(self):
        import argparse
        from clearwing.ui.commands import eval

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        eval.add_parser(subs)
        args = parser.parse_args([
            "eval", "preprocessing", "--project", "foo",
            "--configs", "glasswing_minimal,sourcehunt_full",
        ])
        configs = [c.strip() for c in args.configs.split(",")]
        assert configs == ["glasswing_minimal", "sourcehunt_full"]

    def test_eval_budget_flag(self):
        import argparse
        from clearwing.ui.commands import eval

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        eval.add_parser(subs)
        args = parser.parse_args([
            "eval", "preprocessing", "--project", "foo",
            "--budget-per-config", "100",
        ])
        assert args.budget_per_config == 100.0

    def test_eval_runs_flag(self):
        import argparse
        from clearwing.ui.commands import eval

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        eval.add_parser(subs)
        args = parser.parse_args([
            "eval", "preprocessing", "--project", "foo",
            "--runs", "3",
        ])
        assert args.runs == 3

    def test_eval_ground_truth_flag(self):
        import argparse
        from clearwing.ui.commands import eval

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        eval.add_parser(subs)
        args = parser.parse_args([
            "eval", "preprocessing", "--project", "foo",
            "--ground-truth", "CVE-2024-1234", "CVE-2024-5678",
        ])
        assert args.ground_truth == ["CVE-2024-1234", "CVE-2024-5678"]

    def test_eval_compare_flag(self):
        import argparse
        from clearwing.ui.commands import eval

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        eval.add_parser(subs)
        args = parser.parse_args([
            "eval", "compare", "a.json", "b.json",
        ])
        assert args.eval_action == "compare"
        assert args.results == ["a.json", "b.json"]

    def test_eval_compare_format(self):
        import argparse
        from clearwing.ui.commands import eval

        parser = argparse.ArgumentParser()
        subs = parser.add_subparsers()
        eval.add_parser(subs)
        args = parser.parse_args([
            "eval", "compare", "a.json", "b.json", "--format", "json",
        ])
        assert args.output_format == "json"
