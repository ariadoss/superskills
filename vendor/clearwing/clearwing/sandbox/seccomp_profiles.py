"""Seccomp profiles for sourcehunt sandbox containers.

Two profiles: HUNTER (default for all hunt containers) and EXPLOIT (permissive
for exploit-development containers that need broader syscall access). Both
block dangerous host-escape syscalls like mount, pivot_root, reboot, kexec_load.
"""

from __future__ import annotations

import json
from pathlib import Path

_BLOCKED_SYSCALLS = [
    "mount",
    "umount2",
    "pivot_root",
    "reboot",
    "sethostname",
    "setdomainname",
    "kexec_load",
    "kexec_file_load",
    "init_module",
    "finit_module",
    "delete_module",
]

_EXTRA_HUNTER_BLOCKED = [
    "unshare",
    "setns",
]

HUNTER_SECCOMP: dict = {
    "defaultAction": "SCMP_ACT_ALLOW",
    "syscalls": [
        {
            "names": _BLOCKED_SYSCALLS + _EXTRA_HUNTER_BLOCKED,
            "action": "SCMP_ACT_ERRNO",
            "errnoRet": 1,
        },
    ],
}

EXPLOIT_SECCOMP: dict = {
    "defaultAction": "SCMP_ACT_ALLOW",
    "syscalls": [
        {
            "names": _BLOCKED_SYSCALLS,
            "action": "SCMP_ACT_ERRNO",
            "errnoRet": 1,
        },
    ],
}


def get_seccomp_profile(mode: str = "hunter") -> dict:
    if mode == "exploit":
        return EXPLOIT_SECCOMP
    return HUNTER_SECCOMP


def write_seccomp_profile(mode: str, path: Path) -> str:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    profile = get_seccomp_profile(mode)
    path.write_text(json.dumps(profile, indent=2), encoding="utf-8")
    return str(path)
