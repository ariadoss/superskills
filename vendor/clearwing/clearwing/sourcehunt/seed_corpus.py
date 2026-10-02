"""Seed corpus ingestion for entry-point sharding (spec 004).

Ingests CVE/crash history to provide prior context to agents. Starts
with git-log CVE extraction (always available). OSS-Fuzz and NVD
sources are stubs for future implementation.
"""

from __future__ import annotations

import logging
import re
import subprocess
from dataclasses import dataclass, field

from .state import FileTarget

logger = logging.getLogger(__name__)

MAX_ENTRIES_PER_FILE = 10
MAX_SEED_CONTEXT_CHARS = 2000

_CVE_PATTERN = re.compile(r"CVE-\d{4}-\d{4,}")


@dataclass
class SeedCorpusEntry:
    """One piece of prior crash/CVE context for a file or entry point."""

    file_path: str
    function_name: str | None  # None = file-level
    source: str  # "git_cve" | "oss_fuzz" | "nvd"
    cve_id: str | None
    commit_sha: str | None
    summary: str
    patch_diff: str | None = None


@dataclass
class SeedCorpusResult:
    entries: list[SeedCorpusEntry] = field(default_factory=list)
    sources_queried: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def ingest_seed_corpus(
    repo_path: str,
    file_targets: list[FileTarget],
    sources: list[str] | None = None,
    *,
    max_entries_per_file: int = MAX_ENTRIES_PER_FILE,
    max_context_chars: int = MAX_SEED_CONTEXT_CHARS,
) -> SeedCorpusResult:
    """Ingest seed corpus from available sources. Never blocks pipeline."""
    sources = sources or ["git_cve"]
    result = SeedCorpusResult()

    for source in sources:
        try:
            if source == "git_cve":
                file_paths = [ft.get("path", "") for ft in file_targets if ft.get("path")]
                entries = _extract_git_cve_history(
                    repo_path, file_paths,
                    max_entries_per_file=max_entries_per_file,
                    max_context_chars=max_context_chars,
                )
                result.entries.extend(entries)
                result.sources_queried.append("git_cve")
            elif source == "oss_fuzz":
                result.errors.append("oss_fuzz source not yet implemented")
            elif source == "nvd":
                result.errors.append("nvd source not yet implemented")
            else:
                result.errors.append(f"unknown source: {source}")
        except Exception as exc:
            logger.warning("Seed corpus source %s failed: %s", source, exc)
            result.errors.append(f"{source}: {exc}")

    return result


def _extract_git_cve_history(
    repo_path: str,
    file_paths: list[str],
    *,
    max_entries_per_file: int = MAX_ENTRIES_PER_FILE,
    max_context_chars: int = MAX_SEED_CONTEXT_CHARS,
) -> list[SeedCorpusEntry]:
    """Extract CVE mentions from git log for the given files.

    Runs git log --all --oneline --grep='CVE-' for batches of files,
    parses CVE-YYYY-NNNNN from commit messages, and caps at
    MAX_ENTRIES_PER_FILE per file.
    """
    if not file_paths:
        return []

    try:
        proc = subprocess.run(
            [
                "git", "log", "--all", "--oneline", "--grep=CVE-",
                "--diff-filter=M", "--name-only", "--format=%H %s",
                "--", *file_paths[:200],
            ],
            cwd=repo_path,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as exc:
        logger.warning("git log CVE extraction failed: %s", exc)
        return []

    if proc.returncode != 0:
        return []

    entries: list[SeedCorpusEntry] = []
    counts_per_file: dict[str, int] = {}

    lines = proc.stdout.strip().splitlines()
    current_sha: str | None = None
    current_message: str = ""
    current_cves: list[str] = []

    for line in lines:
        if not line.strip():
            continue

        parts = line.split(" ", 1)
        if len(parts) == 2 and len(parts[0]) == 40 and all(c in "0123456789abcdef" for c in parts[0]):
            current_sha = parts[0]
            current_message = parts[1]
            current_cves = _CVE_PATTERN.findall(current_message)
        elif current_sha and line.strip():
            file_path = line.strip()
            if file_path in set(file_paths):
                count = counts_per_file.get(file_path, 0)
                if count >= max_entries_per_file:
                    continue
                for cve_id in current_cves or [None]:
                    entries.append(SeedCorpusEntry(
                        file_path=file_path,
                        function_name=None,
                        source="git_cve",
                        cve_id=cve_id,
                        commit_sha=current_sha[:12],
                        summary=current_message[:200],
                    ))
                    counts_per_file[file_path] = count + 1
                    if counts_per_file[file_path] >= max_entries_per_file:
                        break

    logger.info("Git CVE extraction: %d entries from %d files", len(entries), len(counts_per_file))
    return entries


def format_seed_context(
    entries: list[SeedCorpusEntry],
    *,
    max_context_chars: int = MAX_SEED_CONTEXT_CHARS,
) -> str:
    """Format seed corpus entries into a prompt block."""
    if not entries:
        return ""

    parts: list[str] = []
    for entry in entries[:5]:
        line = f"- [{entry.source}]"
        if entry.cve_id:
            line += f" {entry.cve_id}"
        if entry.commit_sha:
            line += f" ({entry.commit_sha})"
        line += f": {entry.summary}"
        parts.append(line)

    text = "\n".join(parts)
    if len(text) > max_context_chars:
        text = text[:max_context_chars] + "\n... (truncated)"
    return text
