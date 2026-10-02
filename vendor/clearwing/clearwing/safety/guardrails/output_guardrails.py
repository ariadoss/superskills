"""Output guardrails for checking commands before execution."""

import re
from collections.abc import Callable
from dataclasses import dataclass, field

from .patterns import (
    DANGEROUS_COMMAND_PATTERNS,
    GuardrailResult,
    normalize_unicode,
)


@dataclass
class DangerousPattern:
    """Wraps a regex with metadata for context-aware severity classification."""

    regex: re.Pattern
    label: str
    default_severity: str  # "critical", "high", "warning"
    context_fn: Callable[[re.Match], str] | None = field(default=None)

    def classify(self, match: re.Match) -> str:
        """Return severity for *match*, using context_fn if available."""
        if self.context_fn is not None:
            return self.context_fn(match)
        return self.default_severity


# ---------------------------------------------------------------------------
# Context functions for nuanced severity classification
# ---------------------------------------------------------------------------

_SYSTEM_DIR_RE = re.compile(r"\s+(/\s*$|/etc|/home|/root|/usr|/var|/boot|/bin|/sbin|/lib|~)")
_TEMP_DIR_RE = re.compile(r"\s+(/tmp|/var/tmp)")


def _rm_context(match: re.Match) -> str:
    """Classify rm commands: system dirs -> critical, temp dirs -> warning."""
    text = match.string[match.start():]
    if _TEMP_DIR_RE.search(text):
        return "warning"
    if _SYSTEM_DIR_RE.search(text):
        return "critical"
    # Default to critical for unrecognised paths with rm -rf
    return "critical"


_PIPE_BASH_RE = re.compile(r"\|\s*(?:sudo\s+)?(?:bash|sh)")
_OUTPUT_FILE_RE = re.compile(r"-o\s+\S+")


def _curl_wget_context(match: re.Match) -> str:
    """Classify curl/wget: piped to bash -> critical, -o file -> warning."""
    text = match.string[match.start():]
    if _PIPE_BASH_RE.search(text):
        return "critical"
    if _OUTPUT_FILE_RE.search(text):
        return "warning"
    return "warning"


# ---------------------------------------------------------------------------
# Build the list of DangerousPattern objects from DANGEROUS_COMMAND_PATTERNS
# ---------------------------------------------------------------------------

def _build_dangerous_patterns() -> list[DangerousPattern]:
    """Map each regex from patterns.py to a DangerousPattern with metadata."""
    result: list[DangerousPattern] = []

    for pattern in DANGEROUS_COMMAND_PATTERNS:
        pat = pattern.pattern

        # --- rm commands: context-aware ---
        if pat.startswith("rm\\s+"):
            result.append(DangerousPattern(
                regex=pattern,
                label="rm destructive command",
                default_severity="critical",
                context_fn=_rm_context,
            ))
        # --- curl/wget piped to shell ---
        elif "(curl|wget)" in pat and ("bash|sh" in pat or "sudo" in pat):
            result.append(DangerousPattern(
                regex=pattern,
                label="curl/wget piped to shell",
                default_severity="warning",
                context_fn=_curl_wget_context,
            ))
        # --- base64 decode piped to shell ---
        elif "base64" in pat:
            result.append(DangerousPattern(
                regex=pattern,
                label="base64 decode piped to shell",
                default_severity="warning",
            ))
        # --- Exfiltration ---
        elif any(kw in pat for kw in ("shadow", "passwd", "upload-file", "/dev/tcp",
                                       "nc\\s+", "mkfifo", "socket.*connect",
                                       "curl|wget|nc", "env\\s*\\|", "printenv")):
            result.append(DangerousPattern(
                regex=pattern,
                label="exfiltration / reverse shell",
                default_severity="critical",
            ))
        # --- Cloud CLI exfiltration ---
        elif any(kw in pat for kw in ("aws\\s+s3", "gsutil", "az\\s+storage")):
            result.append(DangerousPattern(
                regex=pattern,
                label="cloud CLI exfiltration",
                default_severity="critical",
            ))
        # --- Kernel module loading ---
        elif any(kw in pat for kw in ("insmod", "modprobe", "rmmod")):
            result.append(DangerousPattern(
                regex=pattern,
                label="kernel module loading",
                default_severity="critical",
            ))
        # --- Path traversal ---
        elif ".." in pat or "%2e" in pat.lower():
            result.append(DangerousPattern(
                regex=pattern,
                label="path traversal",
                default_severity="high",
            ))
        # --- Everything else: critical by default ---
        else:
            result.append(DangerousPattern(
                regex=pattern,
                label="dangerous command",
                default_severity="critical",
            ))

    return result


_DANGEROUS_PATTERNS = _build_dangerous_patterns()


class OutputGuardrail:
    """Check generated commands for safety before execution."""

    def check_command(self, command: str) -> GuardrailResult:
        """Check if a command is safe to execute.

        1. Normalize unicode homographs.
        2. Check against dangerous command patterns with context-aware severity.
        3. Return pass/fail with reason and severity.
           - Critical for destructive / exfiltration commands.
           - Warning for suspicious chains or lower-risk targets.
        """
        normalized = normalize_unicode(command)

        for dp in _DANGEROUS_PATTERNS:
            match = dp.regex.search(normalized)
            if match:
                severity = dp.classify(match)
                return GuardrailResult(
                    passed=False,
                    reason=f"Dangerous command detected: matched pattern '{dp.regex.pattern}' at '{match.group()}'",
                    severity=severity,
                )

        return GuardrailResult(passed=True, reason="", severity="info")

    # ------------------------------------------------------------------
    # Internal helpers (kept for backward compatibility)
    # ------------------------------------------------------------------

    @staticmethod
    def _classify_severity(pattern) -> str:
        """Return 'warning' for suspicious-chain patterns, 'critical' otherwise.

        .. deprecated::
            Kept for backward compatibility.  The ``DangerousPattern`` dataclass
            now provides context-aware classification via ``classify()``.
        """
        pat = pattern.pattern
        suspicious_indicators = [
            r"base64",
            r"(curl|wget)\s+.*\|\s*(bash|sh)",
            r"(curl|wget)\s+.*\|\s*sudo",
        ]
        for indicator in suspicious_indicators:
            if indicator in pat:
                return "warning"
        return "critical"
