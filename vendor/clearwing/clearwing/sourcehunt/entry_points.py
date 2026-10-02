"""Entry-point extraction for function-level sharding (spec 004).

Extracts function-level entry points from high-ranked files using the
CallGraph's function_info metadata and naming-convention heuristics.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from typing import Any

from .callgraph import CallGraph, FunctionInfo
from .pool import _file_rank
from .state import FileTarget

logger = logging.getLogger(__name__)

ENTRY_POINT_TYPES = {
    "syscall_handler",
    "rpc_method",
    "protocol_parser",
    "exported_api",
    "fuzz_target",
    "interrupt_handler",
    "file_operation",
    "network_callback",
}

_TYPE_PRIORITY = {
    "syscall_handler": 0,
    "interrupt_handler": 1,
    "fuzz_target": 2,
    "protocol_parser": 3,
    "network_callback": 4,
    "rpc_method": 5,
    "file_operation": 6,
    "exported_api": 7,
}

MAX_ENTRY_POINTS_PER_FILE = 20


@dataclass
class EntryPoint:
    """A single function-level entry point within a file."""

    file_path: str
    function_name: str
    start_line: int
    end_line: int
    entry_type: str
    description: str


def extract_entry_points(
    file_target: FileTarget,
    callgraph: CallGraph,
    repo_path: str,
    *,
    max_per_file: int = MAX_ENTRY_POINTS_PER_FILE,
) -> list[EntryPoint]:
    """Extract entry points from a single file using callgraph + naming heuristics."""
    file_path = file_target.get("path", "")
    func_infos = callgraph.function_info.get(file_path, [])
    if not func_infos:
        return []

    tags = file_target.get("tags", [])
    language = file_target.get("language", "")

    entry_points: list[EntryPoint] = []
    for fi in func_infos:
        entry_type = _classify_function(fi.name, file_path, tags, language)
        if entry_type is None:
            entry_type = "exported_api"
        desc = _describe_entry_point(fi.name, entry_type)
        entry_points.append(EntryPoint(
            file_path=file_path,
            function_name=fi.name,
            start_line=fi.start_line,
            end_line=fi.end_line,
            entry_type=entry_type,
            description=desc,
        ))

    if len(entry_points) > max_per_file:
        entry_points.sort(key=lambda ep: (
            _TYPE_PRIORITY.get(ep.entry_type, 99),
            -(ep.end_line - ep.start_line),
        ))
        entry_points = entry_points[:max_per_file]

    return entry_points


def extract_entry_points_batch(
    file_targets: list[FileTarget],
    callgraph: CallGraph,
    repo_path: str,
    min_rank: int = 4,
    min_project_loc: int = 50_000,
) -> dict[str, list[EntryPoint]]:
    """Extract entry points for all eligible files.

    Checks total project LOC >= min_project_loc, then extracts from
    files with _file_rank() >= min_rank.
    """
    total_loc = sum(ft.get("loc", 0) for ft in file_targets)
    if total_loc < min_project_loc:
        logger.info(
            "Entry-point extraction skipped: total_loc=%d < %d",
            total_loc, min_project_loc,
        )
        return {}

    result: dict[str, list[EntryPoint]] = {}
    for ft in file_targets:
        rank = _file_rank(ft)
        if rank < min_rank:
            continue
        eps = extract_entry_points(ft, callgraph, repo_path)
        if eps:
            result[ft.get("path", "")] = eps

    total_eps = sum(len(v) for v in result.values())
    logger.info(
        "Entry-point extraction: %d entry points from %d files",
        total_eps, len(result),
    )
    return result


def _classify_function(
    func_name: str,
    file_path: str,
    tags: list[str],
    language: str,
) -> str | None:
    """Return an entry_point_type string or None for fallback."""
    name_lower = func_name.lower()

    if func_name.startswith("SYSCALL_DEFINE") or name_lower.endswith("_ioctl"):
        return "syscall_handler"
    if name_lower.endswith("_compat_ioctl"):
        return "syscall_handler"
    if "syscall_entry" in tags:
        return "syscall_handler"

    if func_name == "LLVMFuzzerTestOneInput" or "_fuzz_" in name_lower:
        return "fuzz_target"
    if "fuzzable" in tags and re.match(r"^(fuzz|harness)_", name_lower):
        return "fuzz_target"

    if "parser" in tags or "protocol_parser" in tags:
        if re.match(r"^(parse|decode|read|recv|deserialize|unmarshal)_", name_lower):
            return "protocol_parser"

    if re.match(r"^(handle|on)_", name_lower) or name_lower.endswith("_handler"):
        if any(t in tags for t in ("network_callback", "attacker_reachable")):
            return "network_callback"

    if name_lower.endswith("_callback") or re.match(r"^on_", name_lower):
        return "network_callback"

    if re.match(r"^(rpc|grpc|thrift)_", name_lower) or name_lower.endswith("_rpc"):
        return "rpc_method"

    if name_lower.endswith("_read") or name_lower.endswith("_write"):
        if language in ("c", "cpp"):
            return "file_operation"

    if re.match(r"^irq_|^isr_", name_lower) or name_lower.endswith("_irq_handler"):
        return "interrupt_handler"

    return None


def _describe_entry_point(func_name: str, entry_type: str) -> str:
    """Generate a short human-readable description."""
    type_labels = {
        "syscall_handler": "handles a syscall or ioctl request",
        "rpc_method": "implements an RPC method",
        "protocol_parser": "parses protocol messages or data",
        "exported_api": "is a public API function",
        "fuzz_target": "is a fuzz target entry point",
        "interrupt_handler": "handles hardware interrupts",
        "file_operation": "implements a file operation",
        "network_callback": "handles network events or callbacks",
    }
    return type_labels.get(entry_type, "is a function in this file")
