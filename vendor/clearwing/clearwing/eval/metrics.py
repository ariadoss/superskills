"""Evaluation metrics computation and result storage (spec 018).

Provides dataclasses for eval results, metric extraction from
SourceHuntResult, aggregation across runs, and comparison formatting.
"""

from __future__ import annotations

import json
import math
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class EvalMetrics:
    """Metrics computed from a single SourceHuntResult."""

    findings_total: int = 0
    findings_verified: int = 0
    findings_exploited: int = 0
    false_positive_rate: float = 0.0
    cost_usd: float = 0.0
    cost_per_finding: float = 0.0
    cwe_diversity: int = 0
    cwe_list: list[str] = field(default_factory=list)
    severity_distribution: dict[str, int] = field(default_factory=dict)
    evidence_distribution: dict[str, int] = field(default_factory=dict)
    duration_seconds: float = 0.0
    files_ranked: int = 0
    files_hunted: int = 0


@dataclass
class ConfigRunResult:
    """Result of a single run under a specific config."""

    run_index: int = 0
    metrics: EvalMetrics = field(default_factory=EvalMetrics)
    error: str | None = None


@dataclass
class ConfigResult:
    """Aggregate result for one config across N runs."""

    config_name: str = ""
    runs: list[ConfigRunResult] = field(default_factory=list)
    mean_metrics: EvalMetrics = field(default_factory=EvalMetrics)
    stddev: dict[str, float] = field(default_factory=dict)


@dataclass
class EvalResult:
    """Top-level result of a preprocessing evaluation."""

    project: str = ""
    commit: str = ""
    model: str = ""
    budget_per_config: float = 0.0
    num_runs: int = 1
    timestamp: str = ""
    configs: list[ConfigResult] = field(default_factory=list)
    ground_truth_cves: list[str] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)


def compute_metrics(result: Any) -> EvalMetrics:
    """Extract EvalMetrics from a SourceHuntResult."""
    findings = getattr(result, "findings", []) or []
    verified = getattr(result, "verified_findings", []) or []
    exploited = getattr(result, "exploited_findings", []) or []

    total = len(findings)
    verified_count = len(verified)
    exploited_count = len(exploited)

    fpr = (total - verified_count) / max(total, 1)
    cpf = getattr(result, "cost_usd", 0.0) / max(verified_count, 1)

    cwes: list[str] = []
    for f in verified:
        cwe = f.get("cwe", "") if hasattr(f, "get") else getattr(f, "cwe", "")
        if cwe:
            cwes.append(cwe)
    unique_cwes = sorted(set(cwes))

    sev_dist: dict[str, int] = {}
    for f in verified:
        sev = (
            f.get("severity_verified") or f.get("severity", "info")
            if hasattr(f, "get")
            else getattr(f, "severity_verified", None) or getattr(f, "severity", "info")
        )
        sev_dist[sev] = sev_dist.get(sev, 0) + 1

    ev_dist: dict[str, int] = {}
    for f in findings:
        ev = (
            f.get("evidence_level", "suspicion")
            if hasattr(f, "get")
            else getattr(f, "evidence_level", "suspicion")
        )
        ev_dist[ev] = ev_dist.get(ev, 0) + 1

    return EvalMetrics(
        findings_total=total,
        findings_verified=verified_count,
        findings_exploited=exploited_count,
        false_positive_rate=fpr,
        cost_usd=getattr(result, "cost_usd", 0.0),
        cost_per_finding=cpf,
        cwe_diversity=len(unique_cwes),
        cwe_list=unique_cwes,
        severity_distribution=sev_dist,
        evidence_distribution=ev_dist,
        duration_seconds=getattr(result, "duration_seconds", 0.0),
        files_ranked=getattr(result, "files_ranked", 0),
        files_hunted=getattr(result, "files_hunted", 0),
    )


_NUMERIC_FIELDS = [
    "findings_total",
    "findings_verified",
    "findings_exploited",
    "false_positive_rate",
    "cost_usd",
    "cost_per_finding",
    "cwe_diversity",
    "duration_seconds",
    "files_ranked",
    "files_hunted",
]


def aggregate_runs(
    runs: list[EvalMetrics],
) -> tuple[EvalMetrics, dict[str, float]]:
    """Compute mean and stddev across runs for numeric fields."""
    if not runs:
        return EvalMetrics(), {}

    n = len(runs)
    means: dict[str, float] = {}
    for fname in _NUMERIC_FIELDS:
        values = [getattr(r, fname) for r in runs]
        means[fname] = sum(values) / n

    stddevs: dict[str, float] = {}
    for fname in _NUMERIC_FIELDS:
        values = [getattr(r, fname) for r in runs]
        mean = means[fname]
        variance = sum((v - mean) ** 2 for v in values) / max(n, 1)
        stddevs[fname] = math.sqrt(variance)

    all_cwes: list[str] = []
    for r in runs:
        all_cwes.extend(r.cwe_list)
    unique_cwes = sorted(set(all_cwes))

    mean_metrics = EvalMetrics(
        findings_total=int(round(means["findings_total"])),
        findings_verified=int(round(means["findings_verified"])),
        findings_exploited=int(round(means["findings_exploited"])),
        false_positive_rate=means["false_positive_rate"],
        cost_usd=means["cost_usd"],
        cost_per_finding=means["cost_per_finding"],
        cwe_diversity=len(unique_cwes),
        cwe_list=unique_cwes,
        duration_seconds=means["duration_seconds"],
        files_ranked=int(round(means["files_ranked"])),
        files_hunted=int(round(means["files_hunted"])),
    )

    return mean_metrics, stddevs


def save_eval_result(result: EvalResult, path: str) -> None:
    """Save eval result to JSON file."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    data = asdict(result)
    p.write_text(json.dumps(data, indent=2, default=str), encoding="utf-8")


def load_eval_result(path: str) -> EvalResult:
    """Load eval result from JSON file."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))

    configs = []
    for cr in data.get("configs", []):
        runs = []
        for rr in cr.get("runs", []):
            metrics_data = rr.get("metrics", {})
            metrics = EvalMetrics(**{
                k: v for k, v in metrics_data.items()
                if k in EvalMetrics.__dataclass_fields__
            })
            runs.append(ConfigRunResult(
                run_index=rr.get("run_index", 0),
                metrics=metrics,
                error=rr.get("error"),
            ))

        mean_data = cr.get("mean_metrics", {})
        mean_metrics = EvalMetrics(**{
            k: v for k, v in mean_data.items()
            if k in EvalMetrics.__dataclass_fields__
        })

        configs.append(ConfigResult(
            config_name=cr.get("config_name", ""),
            runs=runs,
            mean_metrics=mean_metrics,
            stddev=cr.get("stddev", {}),
        ))

    return EvalResult(
        project=data.get("project", ""),
        commit=data.get("commit", ""),
        model=data.get("model", ""),
        budget_per_config=data.get("budget_per_config", 0.0),
        num_runs=data.get("num_runs", 1),
        timestamp=data.get("timestamp", ""),
        configs=configs,
        ground_truth_cves=data.get("ground_truth_cves", []),
        metadata=data.get("metadata", {}),
    )


def format_eval_comparison(result: EvalResult, fmt: str = "table") -> str:
    """Format eval result for display."""
    if fmt == "json":
        return json.dumps(asdict(result), indent=2, default=str)

    if fmt == "markdown":
        return _format_markdown(result)

    return _format_table(result)


def _format_table(result: EvalResult) -> str:
    """Plain text table comparison of configs."""
    lines = [
        f"Preprocessing Evaluation: {result.project}",
        f"Model: {result.model}  Budget: ${result.budget_per_config:.0f}/config  "
        f"Runs: {result.num_runs}",
        "",
    ]

    header = f"{'Metric':<24}"
    for cr in result.configs:
        header += f" {cr.config_name:<22}"
    lines.append(header)
    lines.append("-" * len(header))

    metrics_rows = [
        ("Findings (total)", "findings_total"),
        ("Findings (verified)", "findings_verified"),
        ("Findings (exploited)", "findings_exploited"),
        ("False positive rate", "false_positive_rate"),
        ("Cost (USD)", "cost_usd"),
        ("Cost per finding", "cost_per_finding"),
        ("CWE diversity", "cwe_diversity"),
        ("Duration (s)", "duration_seconds"),
        ("Files ranked", "files_ranked"),
        ("Files hunted", "files_hunted"),
    ]

    for label, fname in metrics_rows:
        row = f"{label:<24}"
        for cr in result.configs:
            val = getattr(cr.mean_metrics, fname, 0)
            sd = cr.stddev.get(fname, 0.0)
            if isinstance(val, float):
                cell = f"{val:.2f}"
                if sd > 0:
                    cell += f" ±{sd:.2f}"
            else:
                cell = str(val)
                if sd > 0:
                    cell += f" ±{sd:.1f}"
            row += f" {cell:<22}"
        lines.append(row)

    return "\n".join(lines)


def _format_markdown(result: EvalResult) -> str:
    """Markdown table comparison of configs."""
    config_names = [cr.config_name for cr in result.configs]
    lines = [
        f"## Preprocessing Evaluation: {result.project}",
        "",
        f"**Model:** {result.model} | **Budget:** ${result.budget_per_config:.0f}/config "
        f"| **Runs:** {result.num_runs}",
        "",
        "| Metric | " + " | ".join(config_names) + " |",
        "| ------ | " + " | ".join(["------"] * len(config_names)) + " |",
    ]

    metrics_rows = [
        ("Findings (verified)", "findings_verified"),
        ("False positive rate", "false_positive_rate"),
        ("Cost per finding", "cost_per_finding"),
        ("CWE diversity", "cwe_diversity"),
        ("Duration (s)", "duration_seconds"),
    ]

    for label, fname in metrics_rows:
        cells = []
        for cr in result.configs:
            val = getattr(cr.mean_metrics, fname, 0)
            if isinstance(val, float):
                cells.append(f"{val:.2f}")
            else:
                cells.append(str(val))
        lines.append(f"| {label} | " + " | ".join(cells) + " |")

    return "\n".join(lines)
