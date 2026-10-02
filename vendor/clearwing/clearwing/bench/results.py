"""Benchmark result storage and comparison (spec 017).

Provides dataclasses for benchmark results, JSON serialization,
and side-by-side comparison utilities for model evaluation.
"""

from __future__ import annotations

import json
import logging
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


@dataclass
class TargetResult:
    project_name: str = ""
    entry_point: str = ""
    tier: int = 0
    cost_usd: float = 0.0
    duration_seconds: float = 0.0
    run_count: int = 1
    per_run_tiers: list[int] = field(default_factory=list)
    crash_kind: str = ""
    crash_evidence_summary: str = ""
    error: str | None = None


@dataclass
class BenchmarkResult:
    model: str = ""
    mode: str = "standard"
    timestamp: str = ""
    total_cost_usd: float = 0.0
    total_duration_seconds: float = 0.0
    targets_attempted: int = 0
    targets_succeeded: int = 0
    targets_failed: int = 0
    tier_distribution: dict[str, int] = field(default_factory=dict)
    results: list[TargetResult] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass
class ComparisonResult:
    model_a: str = ""
    model_b: str = ""
    tier_dist_a: dict[str, int] = field(default_factory=dict)
    tier_dist_b: dict[str, int] = field(default_factory=dict)
    tier_deltas: dict[str, int] = field(default_factory=dict)
    mean_tier_a: float = 0.0
    mean_tier_b: float = 0.0
    per_target_diffs: list[dict] = field(default_factory=list)


def compute_tier_distribution(results: list[TargetResult]) -> dict[str, int]:
    """Compute tier counts from target results (excludes errors)."""
    dist: dict[str, int] = {str(i): 0 for i in range(6)}
    for r in results:
        if r.error is None:
            key = str(r.tier)
            dist[key] = dist.get(key, 0) + 1
    return dist


def compute_mean_tier(dist: dict[str, int]) -> float:
    """Compute weighted average tier from distribution."""
    total = sum(dist.values())
    if total == 0:
        return 0.0
    weighted = sum(int(tier) * count for tier, count in dist.items())
    return weighted / total


def save_result(result: BenchmarkResult, path: str) -> None:
    """Save benchmark result to JSON file."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    data = asdict(result)
    p.write_text(json.dumps(data, indent=2, default=str), encoding="utf-8")


def load_result(path: str) -> BenchmarkResult:
    """Load benchmark result from JSON file."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))

    target_results = []
    for tr in data.get("results", []):
        target_results.append(TargetResult(**{
            k: v for k, v in tr.items()
            if k in TargetResult.__dataclass_fields__
        }))

    return BenchmarkResult(
        model=data.get("model", ""),
        mode=data.get("mode", "standard"),
        timestamp=data.get("timestamp", ""),
        total_cost_usd=data.get("total_cost_usd", 0.0),
        total_duration_seconds=data.get("total_duration_seconds", 0.0),
        targets_attempted=data.get("targets_attempted", 0),
        targets_succeeded=data.get("targets_succeeded", 0),
        targets_failed=data.get("targets_failed", 0),
        tier_distribution=data.get("tier_distribution", {}),
        results=target_results,
        metadata=data.get("metadata", {}),
    )


def compare_results(a: BenchmarkResult, b: BenchmarkResult) -> ComparisonResult:
    """Compare two benchmark results side by side."""
    dist_a = a.tier_distribution or compute_tier_distribution(a.results)
    dist_b = b.tier_distribution or compute_tier_distribution(b.results)

    all_tiers = sorted(set(list(dist_a.keys()) + list(dist_b.keys())))
    deltas = {}
    for tier in all_tiers:
        count_a = dist_a.get(tier, 0)
        count_b = dist_b.get(tier, 0)
        deltas[tier] = count_a - count_b

    # Per-target diffs (match by project_name + entry_point)
    b_by_key = {
        (r.project_name, r.entry_point): r for r in b.results
    }
    per_target_diffs = []
    for ra in a.results:
        key = (ra.project_name, ra.entry_point)
        rb = b_by_key.get(key)
        if rb is not None and ra.tier != rb.tier:
            per_target_diffs.append({
                "project": ra.project_name,
                "entry_point": ra.entry_point,
                "tier_a": ra.tier,
                "tier_b": rb.tier,
                "delta": ra.tier - rb.tier,
            })

    return ComparisonResult(
        model_a=a.model,
        model_b=b.model,
        tier_dist_a=dist_a,
        tier_dist_b=dist_b,
        tier_deltas=deltas,
        mean_tier_a=compute_mean_tier(dist_a),
        mean_tier_b=compute_mean_tier(dist_b),
        per_target_diffs=per_target_diffs,
    )


def format_comparison(comparison: ComparisonResult, fmt: str = "table") -> str:
    """Format comparison result for display."""
    if fmt == "json":
        return json.dumps(asdict(comparison), indent=2, default=str)

    if fmt == "markdown":
        return _format_markdown(comparison)

    return _format_table(comparison)


def _format_table(comparison: ComparisonResult) -> str:
    """Plain text table comparison."""
    lines = [
        f"Benchmark Comparison: {comparison.model_a} vs {comparison.model_b}",
        "",
        f"{'Tier':<8} {'Model A':<12} {'Model B':<12} {'Delta':<8}",
        "-" * 40,
    ]
    all_tiers = sorted(
        set(list(comparison.tier_dist_a.keys()) + list(comparison.tier_dist_b.keys())),
    )
    for tier in all_tiers:
        ca = comparison.tier_dist_a.get(tier, 0)
        cb = comparison.tier_dist_b.get(tier, 0)
        delta = comparison.tier_deltas.get(tier, 0)
        sign = "+" if delta > 0 else ""
        lines.append(f"  {tier:<6} {ca:<12} {cb:<12} {sign}{delta}")

    lines.append("-" * 40)
    lines.append(
        f"  Mean   {comparison.mean_tier_a:<12.2f} {comparison.mean_tier_b:<12.2f} "
        f"{'+' if comparison.mean_tier_a > comparison.mean_tier_b else ''}"
        f"{comparison.mean_tier_a - comparison.mean_tier_b:.2f}"
    )

    if comparison.per_target_diffs:
        lines.append("")
        lines.append(f"Targets with different tiers: {len(comparison.per_target_diffs)}")
        for diff in comparison.per_target_diffs[:10]:
            lines.append(
                f"  {diff['project']}: tier {diff['tier_a']} vs {diff['tier_b']} "
                f"(delta {diff['delta']:+d})"
            )
        if len(comparison.per_target_diffs) > 10:
            lines.append(f"  ... and {len(comparison.per_target_diffs) - 10} more")

    return "\n".join(lines)


def _format_markdown(comparison: ComparisonResult) -> str:
    """Markdown table comparison."""
    lines = [
        f"## Benchmark Comparison: {comparison.model_a} vs {comparison.model_b}",
        "",
        "| Tier | Model A | Model B | Delta |",
        "|------|---------|---------|-------|",
    ]
    all_tiers = sorted(
        set(list(comparison.tier_dist_a.keys()) + list(comparison.tier_dist_b.keys())),
    )
    for tier in all_tiers:
        ca = comparison.tier_dist_a.get(tier, 0)
        cb = comparison.tier_dist_b.get(tier, 0)
        delta = comparison.tier_deltas.get(tier, 0)
        sign = "+" if delta > 0 else ""
        lines.append(f"| {tier} | {ca} | {cb} | {sign}{delta} |")

    lines.append("")
    lines.append(
        f"**Mean tier:** {comparison.mean_tier_a:.2f} vs {comparison.mean_tier_b:.2f}"
    )
    return "\n".join(lines)
