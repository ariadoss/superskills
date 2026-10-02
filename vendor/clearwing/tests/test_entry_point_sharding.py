"""Tests for entry-point sharding and seed corpus ingestion (spec 004)."""

from __future__ import annotations

import asyncio
from unittest.mock import MagicMock, patch

import pytest

from clearwing.sourcehunt.callgraph import CallGraph, CallGraphBuilder, FunctionInfo
from clearwing.sourcehunt.entry_points import (
    MAX_ENTRY_POINTS_PER_FILE,
    EntryPoint,
    _classify_function,
    extract_entry_points,
    extract_entry_points_batch,
)
from clearwing.sourcehunt.pool import (
    HunterPool,
    HuntPoolConfig,
    WorkItem,
    _file_rank,
    _redundancy_for_rank,
)
from clearwing.sourcehunt.seed_corpus import (
    MAX_ENTRIES_PER_FILE,
    SeedCorpusEntry,
    SeedCorpusResult,
    _extract_git_cve_history,
    format_seed_context,
    ingest_seed_corpus,
)
from clearwing.sourcehunt.state import FileTarget


# --- Helpers ------------------------------------------------------------------


def _make_file_target(
    path: str = "src/main.c",
    tier: str = "B",
    tags: list[str] | None = None,
    language: str = "c",
    priority: float = 2.5,
    loc: int = 100,
    surface: int = 3,
    influence: int = 2,
    reachability: int = 3,
) -> FileTarget:
    return {
        "path": path,
        "absolute_path": f"/repo/{path}",
        "language": language,
        "loc": loc,
        "tags": tags or [],
        "tier": tier,
        "surface": surface,
        "influence": influence,
        "reachability": reachability,
        "priority": priority,
    }


def _make_callgraph(
    file_path: str,
    functions: list[tuple[str, int, int]],
) -> CallGraph:
    """Build a CallGraph with the given functions as (name, start_line, end_line)."""
    cg = CallGraph()
    for name, start, end in functions:
        cg.functions[file_path].add(name)
        cg.defined_in[name].add(file_path)
        cg.function_info[file_path].append(FunctionInfo(
            name=name, start_line=start, end_line=end,
        ))
    return cg


# --- Entry-point classification tests ----------------------------------------


class TestClassifyFunction:
    def test_syscall_define(self):
        assert _classify_function("SYSCALL_DEFINE3", "kernel/sys.c", [], "c") == "syscall_handler"

    def test_ioctl_suffix(self):
        assert _classify_function("my_device_ioctl", "drivers/foo.c", [], "c") == "syscall_handler"

    def test_compat_ioctl(self):
        assert _classify_function("my_compat_ioctl", "drivers/foo.c", [], "c") == "syscall_handler"

    def test_syscall_entry_tag(self):
        assert _classify_function("some_func", "kernel/entry.c", ["syscall_entry"], "c") == "syscall_handler"

    def test_fuzz_target_llvm(self):
        assert _classify_function("LLVMFuzzerTestOneInput", "fuzz/target.c", [], "c") == "fuzz_target"

    def test_fuzz_target_pattern(self):
        assert _classify_function("my_fuzz_parser", "fuzz/test.c", [], "c") == "fuzz_target"

    def test_fuzz_target_with_tag(self):
        assert _classify_function("fuzz_header", "src/parser.c", ["fuzzable"], "c") == "fuzz_target"

    def test_protocol_parser(self):
        assert _classify_function("parse_header", "src/proto.c", ["parser"], "c") == "protocol_parser"

    def test_decode_parser(self):
        assert _classify_function("decode_frame", "src/proto.c", ["protocol_parser"], "c") == "protocol_parser"

    def test_network_callback(self):
        assert _classify_function("handle_request", "src/net.c", ["network_callback"], "c") == "network_callback"

    def test_callback_suffix(self):
        assert _classify_function("data_callback", "src/net.c", [], "c") == "network_callback"

    def test_on_prefix(self):
        assert _classify_function("on_data", "src/net.c", [], "c") == "network_callback"

    def test_rpc_method(self):
        assert _classify_function("rpc_get_status", "src/server.c", [], "c") == "rpc_method"

    def test_file_operation_c(self):
        assert _classify_function("device_read", "drivers/dev.c", [], "c") == "file_operation"

    def test_file_operation_not_python(self):
        assert _classify_function("device_read", "src/app.py", [], "python") is None

    def test_interrupt_handler(self):
        assert _classify_function("irq_timer", "kernel/irq.c", [], "c") == "interrupt_handler"

    def test_irq_handler_suffix(self):
        assert _classify_function("uart_irq_handler", "drivers/uart.c", [], "c") == "interrupt_handler"

    def test_unmatched_returns_none(self):
        assert _classify_function("my_helper_func", "src/utils.c", [], "c") is None

    def test_exported_api_fallback_in_extract(self):
        """When _classify_function returns None, extract_entry_points uses exported_api."""
        ft = _make_file_target(path="src/utils.c")
        cg = _make_callgraph("src/utils.c", [("helper_func", 10, 20)])
        eps = extract_entry_points(ft, cg, "/repo")
        assert len(eps) == 1
        assert eps[0].entry_type == "exported_api"


# --- Entry-point extraction tests -------------------------------------------


class TestExtractEntryPoints:
    def test_basic_extraction(self):
        ft = _make_file_target(path="src/main.c")
        cg = _make_callgraph("src/main.c", [
            ("parse_header", 10, 50),
            ("helper", 55, 70),
        ])
        ft["tags"] = ["parser"]
        eps = extract_entry_points(ft, cg, "/repo")
        assert len(eps) == 2
        assert eps[0].function_name == "parse_header"
        assert eps[0].entry_type == "protocol_parser"
        assert eps[0].start_line == 10
        assert eps[0].end_line == 50

    def test_empty_function_info(self):
        ft = _make_file_target(path="src/main.c")
        cg = CallGraph()
        eps = extract_entry_points(ft, cg, "/repo")
        assert eps == []

    def test_cap_at_max(self):
        ft = _make_file_target(path="src/big.c")
        funcs = [(f"func_{i}", i * 10, i * 10 + 5) for i in range(30)]
        cg = _make_callgraph("src/big.c", funcs)
        eps = extract_entry_points(ft, cg, "/repo")
        assert len(eps) == MAX_ENTRY_POINTS_PER_FILE

    def test_priority_sorting_when_capped(self):
        """Classified types should be kept over exported_api when capping."""
        ft = _make_file_target(path="src/big.c", tags=["parser"])
        funcs = [(f"helper_{i}", i * 10, i * 10 + 5) for i in range(25)]
        funcs.append(("parse_critical", 300, 400))
        cg = _make_callgraph("src/big.c", funcs)
        eps = extract_entry_points(ft, cg, "/repo")
        assert len(eps) == MAX_ENTRY_POINTS_PER_FILE
        names = [ep.function_name for ep in eps]
        assert "parse_critical" in names


class TestExtractEntryPointsBatch:
    def test_skips_small_projects(self):
        ft = _make_file_target(path="src/main.c", loc=100, priority=5.0)
        cg = _make_callgraph("src/main.c", [("func", 1, 10)])
        result = extract_entry_points_batch([ft], cg, "/repo", min_project_loc=50_000)
        assert result == {}

    def test_skips_low_rank_files(self):
        ft = _make_file_target(
            path="src/utils.c", priority=1.0,
            surface=1, influence=1, reachability=1,
        )
        cg = _make_callgraph("src/utils.c", [("func", 1, 10)])
        fts = [_make_file_target(loc=60_000)]  # pad LOC
        fts.append(ft)
        result = extract_entry_points_batch(fts, cg, "/repo", min_rank=4)
        assert "src/utils.c" not in result

    def test_extracts_from_high_rank_files(self):
        ft = _make_file_target(
            path="src/critical.c", priority=5.0,
            surface=5, influence=5, reachability=5, loc=60_000,
            tags=["attacker_reachable"],
        )
        cg = _make_callgraph("src/critical.c", [("parse_input", 1, 50)])
        result = extract_entry_points_batch(
            [ft], cg, "/repo", min_rank=4, min_project_loc=50_000,
        )
        assert "src/critical.c" in result
        assert len(result["src/critical.c"]) == 1


# --- Seed corpus tests -------------------------------------------------------


class TestSeedCorpus:
    def test_git_cve_extraction_parses_output(self):
        git_output = (
            "abc1234567890123456789012345678901234567 Fix CVE-2023-12345 buffer overflow\n"
            "src/parser.c\n"
            "\n"
            "def4567890123456789012345678901234567890 Fix CVE-2024-99999 null deref\n"
            "src/parser.c\n"
            "src/util.c\n"
        )
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout=git_output,
            )
            entries = _extract_git_cve_history("/repo", ["src/parser.c", "src/util.c"])

        assert len(entries) >= 2
        cve_ids = [e.cve_id for e in entries]
        assert "CVE-2023-12345" in cve_ids
        assert "CVE-2024-99999" in cve_ids
        assert all(e.source == "git_cve" for e in entries)

    def test_git_cve_cap_per_file(self):
        lines = []
        for i in range(15):
            sha = f"{i:040d}"
            lines.append(f"{sha} Fix CVE-2023-{10000+i} issue {i}")
            lines.append("src/target.c")
            lines.append("")
        git_output = "\n".join(lines)

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout=git_output,
            )
            entries = _extract_git_cve_history("/repo", ["src/target.c"])

        file_entries = [e for e in entries if e.file_path == "src/target.c"]
        assert len(file_entries) <= MAX_ENTRIES_PER_FILE

    def test_format_seed_context_basic(self):
        entries = [
            SeedCorpusEntry(
                file_path="src/parser.c",
                function_name=None,
                source="git_cve",
                cve_id="CVE-2023-12345",
                commit_sha="abc123def456",
                summary="Fix buffer overflow in parse_header",
            ),
        ]
        text = format_seed_context(entries)
        assert "CVE-2023-12345" in text
        assert "abc123def456" in text
        assert "git_cve" in text

    def test_format_seed_context_empty(self):
        assert format_seed_context([]) == ""

    def test_format_seed_context_truncation(self):
        entries = [
            SeedCorpusEntry(
                file_path="src/parser.c",
                function_name=None,
                source="git_cve",
                cve_id=f"CVE-2023-{10000+i}",
                commit_sha="a" * 12,
                summary="x" * 500,
            )
            for i in range(10)
        ]
        text = format_seed_context(entries)
        assert len(text) <= 2100  # 2000 + truncation message

    def test_ingest_seed_corpus_unknown_source(self):
        result = ingest_seed_corpus("/repo", [], sources=["nonexistent"])
        assert "unknown source: nonexistent" in result.errors

    def test_ingest_seed_corpus_oss_fuzz_stub(self):
        result = ingest_seed_corpus("/repo", [], sources=["oss_fuzz"])
        assert any("not yet implemented" in e for e in result.errors)


# --- WorkItem expansion tests ------------------------------------------------


class TestWorkItemExpansion:
    def test_file_level_sharding_unchanged(self):
        """shard_entry_points=False produces standard file-level WorkItems."""
        ft = _make_file_target(path="src/main.c", priority=5.0, surface=5, influence=5, reachability=5)
        config = HuntPoolConfig(
            files=[ft],
            repo_path="/repo",
            llm=MagicMock(),
            shard_entry_points=False,
        )
        pool = HunterPool(config)
        items = pool._expand_to_work_items([ft], "fast")
        assert all(wi.entry_point is None for wi in items)
        assert len(items) >= 1

    def test_entry_point_sharding_creates_per_function_items(self):
        ft = _make_file_target(
            path="src/critical.c", priority=5.0,
            surface=5, influence=5, reachability=5,
        )
        ep1 = EntryPoint("src/critical.c", "parse_header", 10, 50, "protocol_parser", "parses")
        ep2 = EntryPoint("src/critical.c", "handle_request", 55, 100, "network_callback", "handles")
        config = HuntPoolConfig(
            files=[ft],
            repo_path="/repo",
            llm=MagicMock(),
            shard_entry_points=True,
            entry_points_by_file={"src/critical.c": [ep1, ep2]},
        )
        pool = HunterPool(config)
        items = pool._expand_to_work_items([ft], "fast")
        ep_items = [wi for wi in items if wi.entry_point is not None]
        assert len(ep_items) >= 2
        entry_funcs = {wi.entry_point.function_name for wi in ep_items}
        assert "parse_header" in entry_funcs
        assert "handle_request" in entry_funcs

    def test_entry_point_sharding_skips_low_rank(self):
        ft = _make_file_target(
            path="src/utils.c", priority=1.0,
            surface=1, influence=1, reachability=1,
        )
        ep = EntryPoint("src/utils.c", "helper", 1, 10, "exported_api", "helper")
        config = HuntPoolConfig(
            files=[ft],
            repo_path="/repo",
            llm=MagicMock(),
            shard_entry_points=True,
            entry_points_by_file={"src/utils.c": [ep]},
        )
        pool = HunterPool(config)
        items = pool._expand_to_work_items([ft], "fast")
        assert all(wi.entry_point is None for wi in items)

    def test_redundancy_applies_per_entry_point(self):
        ft = _make_file_target(
            path="src/critical.c", priority=5.0,
            surface=5, influence=5, reachability=5,
        )
        ep1 = EntryPoint("src/critical.c", "parse_a", 10, 50, "protocol_parser", "parses")
        ep2 = EntryPoint("src/critical.c", "parse_b", 55, 100, "protocol_parser", "parses")
        ep3 = EntryPoint("src/critical.c", "parse_c", 105, 150, "protocol_parser", "parses")
        config = HuntPoolConfig(
            files=[ft],
            repo_path="/repo",
            llm=MagicMock(),
            shard_entry_points=True,
            entry_points_by_file={"src/critical.c": [ep1, ep2, ep3]},
        )
        pool = HunterPool(config)
        items = pool._expand_to_work_items([ft], "fast")
        rank = _file_rank(ft)
        n = _redundancy_for_rank(rank)
        assert len(items) == 3 * n

    def test_seed_context_set_on_work_item(self):
        ft = _make_file_target(path="src/parser.c", priority=5.0, surface=5, influence=5, reachability=5)
        seed_entries = [
            SeedCorpusEntry(
                file_path="src/parser.c",
                function_name=None,
                source="git_cve",
                cve_id="CVE-2023-12345",
                commit_sha="abc123",
                summary="overflow",
            ),
        ]
        config = HuntPoolConfig(
            files=[ft],
            repo_path="/repo",
            llm=MagicMock(),
            seed_corpus_by_file={"src/parser.c": seed_entries},
        )
        pool = HunterPool(config)
        items = pool._expand_to_work_items([ft], "fast")
        assert any(wi.seed_context and "CVE-2023-12345" in wi.seed_context for wi in items)


# --- Prompt tests ------------------------------------------------------------


class TestPromptBlocks:
    def test_entry_point_focus_in_prompt(self):
        from clearwing.sourcehunt.hunter import _build_unconstrained_prompt

        ft = _make_file_target(path="src/parser.c")
        ep = EntryPoint("src/parser.c", "parse_header", 10, 50, "protocol_parser", "parses")
        prompt = _build_unconstrained_prompt(
            ft, "testproject", None, None,
            entry_point=ep,
        )
        assert "parse_header" in prompt
        assert "lines 10-50" in prompt
        assert "protocol_parser" in prompt

    def test_no_entry_point_no_focus_block(self):
        from clearwing.sourcehunt.hunter import _build_unconstrained_prompt

        ft = _make_file_target(path="src/parser.c")
        prompt = _build_unconstrained_prompt(ft, "testproject", None, None)
        assert "Your starting point is the function" not in prompt

    def test_seed_corpus_block_in_prompt(self):
        from clearwing.sourcehunt.hunter import _build_unconstrained_prompt

        ft = _make_file_target(path="src/parser.c")
        prompt = _build_unconstrained_prompt(
            ft, "testproject", None, None,
            seed_context="- [git_cve] CVE-2023-12345: overflow in parse_header",
        )
        assert "CVE-2023-12345" in prompt
        assert "Prior crash/CVE history" in prompt

    def test_no_seed_context_no_block(self):
        from clearwing.sourcehunt.hunter import _build_unconstrained_prompt

        ft = _make_file_target(path="src/parser.c")
        prompt = _build_unconstrained_prompt(ft, "testproject", None, None)
        assert "Prior crash/CVE history" not in prompt

    def test_deep_agent_prompt_with_entry_point(self):
        from clearwing.sourcehunt.hunter import _build_deep_agent_prompt

        ft = _make_file_target(path="src/parser.c", tags=["parser"])
        ep = EntryPoint("src/parser.c", "decode_frame", 20, 80, "protocol_parser", "parses")
        prompt = _build_deep_agent_prompt(
            ft, "testproject", None, None,
            entry_point=ep,
            seed_context="- [git_cve] CVE-2024-99999: null deref",
        )
        assert "decode_frame" in prompt
        assert "lines 20-80" in prompt
        assert "CVE-2024-99999" in prompt

    def test_build_hunter_agent_with_entry_point(self):
        from clearwing.sourcehunt.hunter import build_hunter_agent

        ft = _make_file_target(path="src/parser.c")
        ep = EntryPoint("src/parser.c", "parse_header", 10, 50, "protocol_parser", "parses")
        llm = MagicMock()
        llm.send = MagicMock()

        hunter, ctx = build_hunter_agent(
            file_target=ft,
            repo_path="/repo",
            sandbox=None,
            llm=llm,
            session_id="test-001",
            entry_point=ep,
            seed_context="- [git_cve] CVE-2023-12345: overflow",
        )
        assert "parse_header" in hunter.prompt
        assert "CVE-2023-12345" in hunter.prompt
