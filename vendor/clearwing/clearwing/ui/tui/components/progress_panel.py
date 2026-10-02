"""Progress panel widget showing active long-running operations."""

from __future__ import annotations

from dataclasses import asdict
from typing import Any

from rich.text import Text
from textual.reactive import reactive
from textual.widgets import Static


class ProgressPanel(Static):
    """Compact progress display for campaigns, hunts, benchmarks, and evals."""

    DEFAULT_CSS = """
    ProgressPanel {
        height: auto;
        max-height: 8;
        background: $boost;
        padding: 0 1;
        display: none;
    }
    ProgressPanel.has-content {
        display: block;
    }
    """

    _campaign: reactive[dict | None] = reactive(None)
    _sourcehunt: reactive[dict | None] = reactive(None)
    _hunt: reactive[dict | None] = reactive(None)
    _benchmark: reactive[dict | None] = reactive(None)
    _eval: reactive[dict | None] = reactive(None)

    def _payload_to_dict(self, payload: Any) -> dict:
        if isinstance(payload, dict):
            return payload
        try:
            return asdict(payload)
        except Exception:
            return {}

    def update_campaign(self, payload: Any) -> None:
        self._campaign = self._payload_to_dict(payload)
        self._refresh_visibility()

    def update_sourcehunt(self, payload: Any) -> None:
        self._sourcehunt = self._payload_to_dict(payload)
        self._refresh_visibility()

    def update_hunt(self, payload: Any) -> None:
        self._hunt = self._payload_to_dict(payload)
        self._refresh_visibility()

    def update_benchmark(self, payload: Any) -> None:
        self._benchmark = self._payload_to_dict(payload)
        self._refresh_visibility()

    def update_eval(self, payload: Any) -> None:
        self._eval = self._payload_to_dict(payload)
        self._refresh_visibility()

    def _refresh_visibility(self) -> None:
        has = any([self._campaign, self._sourcehunt, self._hunt, self._benchmark, self._eval])
        if has:
            self.add_class("has-content")
        else:
            self.remove_class("has-content")
        self.refresh()

    def render(self) -> Text:
        lines: list[str] = []

        if self._campaign:
            c = self._campaign
            lines.append(
                f"Campaign \"{c.get('campaign_name', '?')}\" "
                f"── {c.get('projects_completed', 0)}/{c.get('projects_total', 0)} projects "
                f"── ${c.get('cost_usd', 0):.2f} "
                f"── {c.get('findings_total', 0)} findings ({c.get('verified_total', 0)} verified) "
                f"[{c.get('status', '?')}]"
            )

        if self._sourcehunt:
            s = self._sourcehunt
            stage = s.get("stage", "?")
            status = s.get("status", "?")
            detail = s.get("detail", "")
            prefix = "  \u2514\u2500 " if self._campaign else ""
            lines.append(
                f"{prefix}sourcehunt [{stage}:{status}] "
                f"── {s.get('findings_so_far', 0)} findings "
                f"── ${s.get('cost_usd', 0):.2f}"
                + (f" ── {detail}" if detail else "")
            )

        if self._hunt:
            h = self._hunt
            prefix = "     \u2514\u2500 " if (self._campaign or self._sourcehunt) else ""
            lines.append(
                f"{prefix}hunt tier-{h.get('tier', '?')} band-{h.get('band', '?')} "
                f"── {h.get('files_completed', 0)}/{h.get('files_total', 0)} files "
                f"── {h.get('findings_this_tier', 0)} findings "
                f"── ${h.get('budget_remaining', 0):.2f} remaining"
            )

        if self._benchmark:
            b = self._benchmark
            dist = b.get("tier_distribution", {})
            dist_str = " ".join(f"T{k}:{v}" for k, v in sorted(dist.items()) if v)
            lines.append(
                f"Benchmark \"{b.get('mode', '?')}\" "
                f"── {b.get('targets_completed', 0)}/{b.get('targets_total', 0)} targets "
                f"── ${b.get('cost_usd', 0):.2f}"
                + (f" ── {dist_str}" if dist_str else "")
            )

        if self._eval:
            e = self._eval
            lines.append(
                f"Eval \"{e.get('config_name', '?')}\" "
                f"── run {e.get('run_index', 0) + 1}/{e.get('runs_total', 0)} "
                f"── config {e.get('configs_completed', 0) + 1}/{e.get('configs_total', 0)} "
                f"── [{e.get('status', '?')}] "
                f"── ${e.get('cost_usd', 0):.2f}"
            )

        if not lines:
            return Text("")
        return Text("\n".join(lines), style="dim cyan")
