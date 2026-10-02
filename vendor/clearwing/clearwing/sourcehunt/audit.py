"""Security audit trail for sensitive sourcehunt operations.

Append-only JSONL log tracking artifact access, disclosure actions, and
other security-sensitive operations. Complements the existing AuditLogger
(which tracks tool/LLM calls) with a compliance-oriented audit trail.
"""

from __future__ import annotations

import json
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path


def _default_log_path() -> Path:
    from clearwing.core.config import clearwing_home

    return clearwing_home() / "sourcehunt" / "security_audit.jsonl"


@dataclass
class SecurityAuditEntry:
    timestamp: str
    operator: str
    action: str
    target: str
    approved_by: str | None = None
    details: dict = field(default_factory=dict)


class SecurityAuditLog:
    """Append-only security audit log for sensitive operations."""

    def __init__(self, log_path: Path | None = None):
        self._path = Path(log_path) if log_path else _default_log_path()
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()

    def log(
        self,
        action: str,
        target: str,
        operator: str = "system",
        approved_by: str | None = None,
        **kwargs,
    ) -> SecurityAuditEntry:
        entry = SecurityAuditEntry(
            timestamp=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            operator=operator,
            action=action,
            target=target,
            approved_by=approved_by,
            details=kwargs,
        )
        record = {
            "timestamp": entry.timestamp,
            "operator": entry.operator,
            "action": entry.action,
            "target": entry.target,
            "approved_by": entry.approved_by,
            "details": entry.details,
        }
        with self._lock:
            with open(self._path, "a", encoding="utf-8") as f:
                f.write(json.dumps(record) + "\n")
        return entry

    def query(
        self,
        action: str | None = None,
        target: str | None = None,
        limit: int = 100,
    ) -> list[SecurityAuditEntry]:
        if not self._path.exists():
            return []
        results: list[SecurityAuditEntry] = []
        with open(self._path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                record = json.loads(line)
                if action and record.get("action") != action:
                    continue
                if target and record.get("target") != target:
                    continue
                results.append(SecurityAuditEntry(
                    timestamp=record["timestamp"],
                    operator=record["operator"],
                    action=record["action"],
                    target=record["target"],
                    approved_by=record.get("approved_by"),
                    details=record.get("details", {}),
                ))
                if len(results) >= limit:
                    break
        return results
