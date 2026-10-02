r"""Regression tests for Windows path normalization at repo-relative sinks.

PR #18 normalized `os.path.relpath(...)` results to POSIX in
discovery/callgraph/preprocessor/variant_loop. This follow-up ensures
three previously missed sites — `runner._merge_static_findings`,
`taint._analyze_file`, and `semgrep_sidecar._parse_semgrep_json` —
also emit forward-slash paths so file-keyed dict lookups (e.g.
`semgrep_hints_by_file[rel_path]`) don't silently miss on Windows.

On Linux, `os.path.relpath(...)` already emits forward slashes *and*
`pathlib.Path` is `PosixPath` — so wrapping a literal backslash string
via `Path(...).as_posix()` does NOT convert `\` to `/` (the wrapper is
a no-op on Linux by design). To semantically exercise the Windows
branch cross-platform, we patch the module's `Path` alias with
`PureWindowsPath` and patch `os.path.relpath` to return a Windows-
flavored string — together those mimic what would happen on a Windows
runner, and assert the wrapper normalizes the result.
"""

from __future__ import annotations

import json
from pathlib import PureWindowsPath
from unittest.mock import MagicMock, patch

from clearwing.sourcehunt.semgrep_sidecar import SemgrepSidecar


class TestRunnerStaticFindingPathNormalization:
    """`SourceHuntRunner._merge_static_findings` must emit POSIX `Finding.file`."""

    def test_static_finding_file_uses_forward_slashes_on_windows_paths(self):
        # Importing inside the test keeps module-level import failures
        # in one site from blocking the other two tests.
        from clearwing.analysis.source_analyzer import AnalyzerFinding
        from clearwing.findings.types import Finding
        from clearwing.sourcehunt.preprocessor import PreprocessResult
        from clearwing.sourcehunt.runner import SourceHuntRunner

        sf = AnalyzerFinding(
            file_path=r"C:\repo\src\auth\login.py",
            line_number=42,
            finding_type="sqli",
            cwe="CWE-89",
            severity="high",
            confidence="medium",
            description="concat in query",
            code_snippet="db.execute('... ' + user)",
        )
        pp = MagicMock(spec=PreprocessResult)
        pp.repo_path = r"C:\repo"
        pp.static_findings = [sf]

        # Simulate a Windows runtime: `os.path.relpath` returns a
        # backslash string, and `Path(...)` resolves to `PureWindowsPath`
        # so `.as_posix()` actually performs the conversion.
        with (
            patch(
                "clearwing.sourcehunt.runner.os.path.relpath",
                return_value=r"src\auth\login.py",
            ),
            patch("clearwing.sourcehunt.runner.Path", PureWindowsPath),
        ):
            runner = SourceHuntRunner.__new__(SourceHuntRunner)
            out = SourceHuntRunner._merge_static_findings(runner, [], pp)

        assert len(out) == 1
        assert isinstance(out[0], Finding)
        assert out[0].file == "src/auth/login.py", (
            "Finding.file must be POSIX so it matches other file-keyed dicts on Windows"
        )
        assert "\\" not in (out[0].file or "")

    def test_guard_fix_is_applied_at_source(self):
        """Static assertion: the fix site uses `.as_posix()` wrapping."""
        import inspect

        from clearwing.sourcehunt.runner import SourceHuntRunner

        src = inspect.getsource(SourceHuntRunner._merge_static_findings)
        assert ".as_posix()" in src, (
            "runner._merge_static_findings must normalize file= via as_posix()"
        )
        assert "os.path.relpath" in src


class TestTaintRelPathNormalization:
    """`TaintAnalyzer._analyze_file` must emit POSIX `TaintPath.rel_path`."""

    def test_rel_path_uses_forward_slashes_on_windows_paths(self):
        from clearwing.sourcehunt.taint import TaintAnalyzer

        analyzer = TaintAnalyzer.__new__(TaintAnalyzer)

        captured: dict[str, str] = {}

        def fake_walk(*, root, source_text, lang, rel_path):
            captured["rel_path"] = rel_path
            return []

        # Stub the parser + downstream walker so the test doesn't need
        # tree-sitter grammars installed on CI.
        fake_parser = MagicMock()
        fake_parser.parse.return_value = MagicMock(root_node=MagicMock())

        fake_file = MagicMock()
        fake_file.__enter__ = lambda self: MagicMock(read=lambda: b"x = 1\n")
        fake_file.__exit__ = lambda self, *a: False

        with (
            patch.object(TaintAnalyzer, "_get_parser", return_value=fake_parser),
            patch.object(TaintAnalyzer, "_walk_ast_for_taint", side_effect=fake_walk),
            patch("clearwing.sourcehunt.taint.open", return_value=fake_file, create=True),
            patch(
                "clearwing.sourcehunt.taint.os.path.relpath",
                return_value=r"src\api\view.py",
            ),
            patch("clearwing.sourcehunt.taint.Path", PureWindowsPath),
        ):
            analyzer._analyze_file(r"C:\repo\src\api\view.py", "python", r"C:\repo")

        assert captured["rel_path"] == "src/api/view.py", (
            "TaintPath.rel_path must be POSIX so file-keyed lookups align on Windows"
        )
        assert "\\" not in captured["rel_path"]

    def test_guard_fix_is_applied_at_source(self):
        import inspect

        from clearwing.sourcehunt.taint import TaintAnalyzer

        src = inspect.getsource(TaintAnalyzer._analyze_file)
        assert ".as_posix()" in src
        assert "os.path.relpath" in src


class TestSemgrepFindingPathNormalization:
    """`_parse_semgrep_json` must emit POSIX `SemgrepFinding.file`."""

    def test_finding_file_uses_forward_slashes_on_windows_paths(self):
        sidecar = SemgrepSidecar()
        stdout = json.dumps(
            {
                "results": [
                    {
                        "check_id": "python.lang.security.audit.sqli",
                        "path": r"C:\repo\src\db\queries.py",
                        "start": {"line": 17},
                        "extra": {
                            "severity": "ERROR",
                            "message": "sqli",
                            "lines": "...",
                            "metadata": {"cwe": "CWE-89"},
                        },
                    }
                ]
            }
        )

        with (
            patch(
                "clearwing.sourcehunt.semgrep_sidecar.os.path.relpath",
                return_value=r"src\db\queries.py",
            ),
            patch("clearwing.sourcehunt.semgrep_sidecar.Path", PureWindowsPath),
        ):
            findings = sidecar._parse_semgrep_json(stdout, r"C:\repo")

        assert len(findings) == 1
        assert findings[0].file == "src/db/queries.py", (
            "SemgrepFinding.file must be POSIX so `semgrep_hints_by_file[rel_path]` "
            "lookups keyed on paths from the fixed sites hit on Windows"
        )
        assert "\\" not in findings[0].file

    def test_guard_fix_is_applied_at_source(self):
        import inspect

        from clearwing.sourcehunt.semgrep_sidecar import SemgrepSidecar

        src = inspect.getsource(SemgrepSidecar._parse_semgrep_json)
        assert ".as_posix()" in src
        assert "os.path.relpath" in src
