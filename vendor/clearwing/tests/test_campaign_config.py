"""Tests for campaign YAML config parsing (spec 012)."""

from __future__ import annotations

import tempfile
from pathlib import Path

import pytest

from clearwing.sourcehunt.campaign_config import (
    CampaignConfig,
    CampaignTargetConfig,
    OSSFuzzCorpusConfig,
    load_campaign_config,
    validate_campaign_config,
)


def _write_yaml(content: str) -> str:
    f = tempfile.NamedTemporaryFile(
        mode="w", suffix=".yaml", delete=False,
    )
    f.write(content)
    f.close()
    return f.name


class TestLoadConfig:
    def test_load_minimal_config(self):
        path = _write_yaml("""
name: test-campaign
budget: 1000
targets:
  - repo: https://github.com/test/repo
""")
        config = load_campaign_config(path)
        assert config.name == "test-campaign"
        assert config.budget == 1000
        assert len(config.targets) == 1
        assert config.targets[0].repo == "https://github.com/test/repo"

    def test_load_full_config(self):
        path = _write_yaml("""
name: q2-audit
budget: 50000
max_concurrent_containers: 200
depth: deep
prompt_mode: unconstrained
campaign_hint: focus on memory safety
diminishing_returns_window: 300
diminishing_returns_threshold: 0.01
triage_backlog_limit: 200
checkpoint_interval_seconds: 600
output_dir: /tmp/campaign-out
targets:
  - repo: https://github.com/FFmpeg/FFmpeg
    budget: 10000
    focus: ["libavcodec/", "libavformat/"]
    branch: release/6.0
    max_parallel: 16
    redundancy: 3
  - repo: https://github.com/test/repo2
    depth: standard
""")
        config = load_campaign_config(path)
        assert config.name == "q2-audit"
        assert config.budget == 50000
        assert config.max_concurrent_containers == 200
        assert config.depth == "deep"
        assert config.campaign_hint == "focus on memory safety"
        assert config.diminishing_returns_window == 300
        assert config.checkpoint_interval_seconds == 600
        assert len(config.targets) == 2

        t0 = config.targets[0]
        assert t0.repo == "https://github.com/FFmpeg/FFmpeg"
        assert t0.budget == 10000
        assert t0.focus == ["libavcodec/", "libavformat/"]
        assert t0.branch == "release/6.0"
        assert t0.max_parallel == 16
        assert t0.redundancy == 3

        t1 = config.targets[1]
        assert t1.depth == "standard"

    def test_target_defaults(self):
        path = _write_yaml("""
name: test
budget: 100
targets:
  - repo: https://github.com/test/repo
""")
        config = load_campaign_config(path)
        t = config.targets[0]
        assert t.budget == 0.0
        assert t.depth == ""
        assert t.branch == "main"
        assert t.max_parallel == 0
        assert t.redundancy is None
        assert t.focus == []

    def test_oss_fuzz_expansion(self):
        path = _write_yaml("""
name: test
budget: 5000
targets:
  - repo: https://github.com/test/repo
  - oss_fuzz_corpus:
      categories: ["networking", "crypto"]
      max_projects: 50
      budget_per_project: 100
""")
        config = load_campaign_config(path)
        assert config.oss_fuzz_corpus is not None
        assert config.oss_fuzz_corpus.categories == ["networking", "crypto"]
        assert len(config.targets) == 3  # 1 real + 2 from oss_fuzz
        assert config.targets[1].repo == "oss-fuzz:networking"
        assert config.targets[2].repo == "oss-fuzz:crypto"
        assert config.targets[1].budget == 100


class TestValidation:
    def test_no_targets(self):
        config = CampaignConfig(name="test", budget=100, targets=[])
        with pytest.raises(ValueError, match="at least one target"):
            validate_campaign_config(config)

    def test_no_budget(self):
        config = CampaignConfig(
            name="test", budget=0,
            targets=[CampaignTargetConfig(repo="x")],
        )
        with pytest.raises(ValueError, match="budget must be > 0"):
            validate_campaign_config(config)

    def test_bad_depth(self):
        config = CampaignConfig(
            name="test", budget=100, depth="ultra",
            targets=[CampaignTargetConfig(repo="x")],
        )
        with pytest.raises(ValueError, match="Invalid campaign depth"):
            validate_campaign_config(config)

    def test_bad_target_depth(self):
        config = CampaignConfig(
            name="test", budget=100,
            targets=[CampaignTargetConfig(repo="x", depth="ultra")],
        )
        with pytest.raises(ValueError, match="Invalid target depth"):
            validate_campaign_config(config)

    def test_valid_config_passes(self):
        config = CampaignConfig(
            name="test", budget=100,
            targets=[CampaignTargetConfig(repo="x")],
        )
        validate_campaign_config(config)  # should not raise
