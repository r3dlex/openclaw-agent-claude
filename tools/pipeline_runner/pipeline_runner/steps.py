"""Pipeline step definitions: reusable checks for security, quality, architecture, and testing."""

from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path
from typing import Protocol

from .models import Finding, Severity, StepResult, StepStatus


class PipelineStep(Protocol):
    """Protocol for pipeline steps."""

    name: str

    def run(self, project_root: Path) -> StepResult: ...


# ── Security Steps ──


class SecretsScanner:
    """Scan for hardcoded secrets, tokens, and credentials."""

    name = "secrets-scan"

    SECRET_PATTERNS: list[tuple[str, str]] = [
        (r"(?i)(api[_-]?key|apikey)\s*[:=]\s*['\"][a-zA-Z0-9]{16,}['\"]", "Hardcoded API key"),
        (r"(?i)(secret|password|passwd|pwd)\s*[:=]\s*['\"][^'\"]{8,}['\"]", "Hardcoded secret/password"),
        (r"sk-[a-zA-Z0-9]{20,}", "Potential API secret key"),
        (r"(?i)bearer\s+[a-zA-Z0-9\-_.]{20,}", "Hardcoded bearer token"),
        (r"-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----", "Private key in source"),
        (r"(?i)(aws_access_key_id|aws_secret_access_key)\s*=\s*[A-Z0-9]{16,}", "AWS credential"),
    ]

    SKIP_EXTENSIONS = {".lock", ".sum", ".beam", ".pyc", ".exe", ".bin", ".png", ".jpg", ".gif", ".ico"}
    SKIP_DIRS = {".git", "__pycache__", "node_modules", "_build", "deps", ".archgate", ".ruff_cache", ".mypy_cache", ".pytest_cache"}
    SKIP_PATHS = {"tests/", "test/", "test_", "_test.py", "spec/"}

    def run(self, project_root: Path) -> StepResult:
        findings: list[Finding] = []
        start = time.monotonic()

        for path in self._walk_files(project_root):
            try:
                content = path.read_text(errors="ignore")
            except (OSError, UnicodeDecodeError):
                continue

            rel = str(path.relative_to(project_root))
            for pattern, desc in self.SECRET_PATTERNS:
                for match in re.finditer(pattern, content):
                    line_num = content[: match.start()].count("\n") + 1
                    findings.append(
                        Finding(
                            message=desc,
                            severity=Severity.ERROR,
                            file=rel,
                            line=line_num,
                            rule="secrets-scan",
                            category="security",
                        )
                    )

        elapsed = (time.monotonic() - start) * 1000
        status = StepStatus.FAILED if any(f.severity == Severity.ERROR for f in findings) else StepStatus.PASSED
        return StepResult(name=self.name, status=status, findings=findings, duration_ms=elapsed)

    def _walk_files(self, root: Path):  # noqa: ANN202
        for item in root.rglob("*"):
            if any(part in self.SKIP_DIRS for part in item.parts):
                continue
            if item.is_file() and item.suffix not in self.SKIP_EXTENSIONS:
                rel = str(item.relative_to(root))
                # Skip test files (they contain intentional fake secrets for testing)
                if any(skip in rel for skip in self.SKIP_PATHS):
                    continue
                yield item


class GitignoreValidator:
    """Verify .gitignore protects sensitive files."""

    name = "gitignore-check"

    REQUIRED_PATTERNS = [".env", "*.pem", "*.key", "memory/", "MEMORY.md", "data/"]

    def run(self, project_root: Path) -> StepResult:
        findings: list[Finding] = []
        start = time.monotonic()

        gitignore = project_root / ".gitignore"
        if not gitignore.exists():
            findings.append(Finding(message="No .gitignore found", severity=Severity.ERROR, rule="gitignore-check"))
            elapsed = (time.monotonic() - start) * 1000
            return StepResult(
                name=self.name, status=StepStatus.FAILED, findings=findings, duration_ms=elapsed
            )

        content = gitignore.read_text()
        for pattern in self.REQUIRED_PATTERNS:
            if pattern not in content:
                findings.append(
                    Finding(
                        message=f"Missing required .gitignore pattern: {pattern}",
                        severity=Severity.ERROR,
                        file=".gitignore",
                        rule="gitignore-check",
                        category="security",
                    )
                )

        elapsed = (time.monotonic() - start) * 1000
        status = StepStatus.FAILED if any(f.severity == Severity.ERROR for f in findings) else StepStatus.PASSED
        return StepResult(name=self.name, status=status, findings=findings, duration_ms=elapsed)


# ── Architecture Steps ──


class ArchgateChecker:
    """Run archgate ADR compliance checks."""

    name = "archgate-check"

    def run(self, project_root: Path) -> StepResult:
        start = time.monotonic()

        archgate_dir = project_root / ".archgate"
        if not archgate_dir.exists():
            return StepResult(
                name=self.name,
                status=StepStatus.SKIPPED,
                output="No .archgate directory found, skipping ADR compliance checks",
                duration_ms=(time.monotonic() - start) * 1000,
            )

        try:
            result = subprocess.run(
                ["archgate", "check", "--json"],
                cwd=str(project_root),
                capture_output=True,
                text=True,
                timeout=60,
            )

            findings = self._parse_output(result.stdout)
            elapsed = (time.monotonic() - start) * 1000
            status = StepStatus.PASSED if result.returncode == 0 else StepStatus.FAILED
            return StepResult(
                name=self.name, status=status, findings=findings,
                output=result.stdout, duration_ms=elapsed,
            )

        except FileNotFoundError:
            return StepResult(
                name=self.name,
                status=StepStatus.SKIPPED,
                output="archgate CLI not installed, skipping. Install: npm install -g archgate",
                duration_ms=(time.monotonic() - start) * 1000,
            )
        except subprocess.TimeoutExpired:
            return StepResult(
                name=self.name,
                status=StepStatus.FAILED,
                findings=[Finding(message="archgate check timed out after 60s", severity=Severity.ERROR)],
                duration_ms=(time.monotonic() - start) * 1000,
            )

    def _parse_output(self, output: str) -> list[Finding]:
        findings: list[Finding] = []
        try:
            import json

            data = json.loads(output)
            for violation in data.get("violations", []):
                findings.append(
                    Finding(
                        message=violation.get("message", "Unknown violation"),
                        severity=Severity.ERROR if violation.get("severity") == "error" else Severity.WARNING,
                        file=violation.get("file"),
                        line=violation.get("line"),
                        rule=violation.get("rule"),
                        category="architecture",
                    )
                )
        except (ValueError, KeyError):
            pass
        return findings


class AdrExistenceChecker:
    """Verify that ADR documents exist and have valid frontmatter."""

    name = "adr-existence"

    def run(self, project_root: Path) -> StepResult:
        findings: list[Finding] = []
        start = time.monotonic()

        adr_dir = project_root / ".archgate" / "adrs"
        if not adr_dir.exists():
            findings.append(
                Finding(
                    message="No .archgate/adrs directory found. Run: archgate init",
                    severity=Severity.WARNING,
                    rule="adr-existence",
                    category="architecture",
                )
            )
            return StepResult(
                name=self.name,
                status=StepStatus.PASSED,
                findings=findings,
                duration_ms=(time.monotonic() - start) * 1000,
            )

        adr_files = list(adr_dir.glob("*.md"))
        if not adr_files:
            findings.append(
                Finding(
                    message="No ADR files found in .archgate/adrs/",
                    severity=Severity.WARNING,
                    rule="adr-existence",
                    category="architecture",
                )
            )
        else:
            for adr in adr_files:
                self._validate_adr(adr, project_root, findings)

        elapsed = (time.monotonic() - start) * 1000
        status = StepStatus.FAILED if any(f.severity == Severity.ERROR for f in findings) else StepStatus.PASSED
        return StepResult(name=self.name, status=status, findings=findings, duration_ms=elapsed)

    def _validate_adr(self, adr_path: Path, project_root: Path, findings: list[Finding]) -> None:
        content = adr_path.read_text()
        rel = str(adr_path.relative_to(project_root))

        if not content.startswith("---"):
            findings.append(
                Finding(
                    message=f"ADR missing YAML frontmatter: {adr_path.name}",
                    severity=Severity.ERROR,
                    file=rel,
                    rule="adr-existence",
                    category="architecture",
                )
            )
            return

        parts = content.split("---", 2)
        if len(parts) < 3:
            findings.append(
                Finding(
                    message=f"ADR has malformed frontmatter: {adr_path.name}",
                    severity=Severity.ERROR,
                    file=rel,
                    rule="adr-existence",
                    category="architecture",
                )
            )
            return

        try:
            import yaml

            meta = yaml.safe_load(parts[1])
            if not meta:
                raise ValueError("Empty frontmatter")
            for required in ("id", "title", "domain"):
                if required not in meta:
                    findings.append(
                        Finding(
                            message=f"ADR {adr_path.name} missing required field: {required}",
                            severity=Severity.ERROR,
                            file=rel,
                            rule="adr-existence",
                            category="architecture",
                        )
                    )
        except Exception as e:
            findings.append(
                Finding(
                    message=f"ADR {adr_path.name} frontmatter parse error: {e}",
                    severity=Severity.ERROR,
                    file=rel,
                    rule="adr-existence",
                    category="architecture",
                )
            )


# ── Code Quality Steps ──


class EnvExampleValidator:
    """Verify .env.example exists and has no real secrets."""

    name = "env-example-check"

    def run(self, project_root: Path) -> StepResult:
        findings: list[Finding] = []
        start = time.monotonic()

        env_example = project_root / ".env.example"
        if not env_example.exists():
            findings.append(
                Finding(message="No .env.example found", severity=Severity.WARNING, rule="env-example-check")
            )
        else:
            content = env_example.read_text()
            for i, line in enumerate(content.splitlines(), 1):
                line = line.strip()
                if line.startswith("#") or not line or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip().strip("'\"")
                # Skip well-known non-secret keys (models, modes, paths)
                safe_keys = {"DEFAULT_MODEL", "DEFAULT_PERMISSION_MODE", "AGENT_DATA_DIR"}
                if key in safe_keys:
                    continue
                if len(value) > 20 and re.match(r"^[a-zA-Z0-9+/=_\-]{20,}$", value):
                    findings.append(
                        Finding(
                            message="Possible real secret in .env.example",
                            severity=Severity.ERROR,
                            file=".env.example",
                            line=i,
                            rule="env-example-check",
                            category="security",
                        )
                    )

        elapsed = (time.monotonic() - start) * 1000
        status = StepStatus.FAILED if any(f.severity == Severity.ERROR for f in findings) else StepStatus.PASSED
        return StepResult(name=self.name, status=status, findings=findings, duration_ms=elapsed)


# ── Testing Steps ──


class ElixirTestRunner:
    """Run Elixir test suite via mix test."""

    name = "elixir-tests"

    def run(self, project_root: Path) -> StepResult:
        start = time.monotonic()
        factory_dir = project_root / "factory"

        if not factory_dir.exists() or not (factory_dir / "mix.exs").exists():
            return StepResult(
                name=self.name,
                status=StepStatus.SKIPPED,
                output="No factory/mix.exs found",
                duration_ms=(time.monotonic() - start) * 1000,
            )

        try:
            result = subprocess.run(
                ["mix", "test", "--cover"],
                cwd=str(factory_dir),
                capture_output=True,
                text=True,
                timeout=120,
                env={"MIX_ENV": "test", "PATH": subprocess.os.environ.get("PATH", "")},
            )
            elapsed = (time.monotonic() - start) * 1000
            status = StepStatus.PASSED if result.returncode == 0 else StepStatus.FAILED
            findings = []
            if result.returncode != 0:
                findings.append(
                    Finding(
                        message=f"Elixir tests failed (exit code {result.returncode})",
                        severity=Severity.ERROR,
                        rule="elixir-tests",
                        category="testing",
                    )
                )
            return StepResult(
                name=self.name, status=status, findings=findings,
                output=result.stdout + result.stderr, duration_ms=elapsed
            )
        except FileNotFoundError:
            return StepResult(
                name=self.name,
                status=StepStatus.SKIPPED,
                output="mix not found. Install Elixir to run factory tests.",
                duration_ms=(time.monotonic() - start) * 1000,
            )
        except subprocess.TimeoutExpired:
            return StepResult(
                name=self.name,
                status=StepStatus.FAILED,
                findings=[Finding(message="Elixir tests timed out", severity=Severity.ERROR)],
                duration_ms=(time.monotonic() - start) * 1000,
            )


class PythonTestRunner:
    """Run Python test suite via pytest."""

    name = "python-tests"

    def run(self, project_root: Path) -> StepResult:
        start = time.monotonic()
        pipeline_dir = project_root / "tools" / "pipeline_runner"

        if not pipeline_dir.exists() or not (pipeline_dir / "pyproject.toml").exists():
            return StepResult(
                name=self.name,
                status=StepStatus.SKIPPED,
                output="No tools/pipeline_runner/pyproject.toml found",
                duration_ms=(time.monotonic() - start) * 1000,
            )

        try:
            result = subprocess.run(
                ["python", "-m", "pytest", "--tb=short", "-q"],
                cwd=str(pipeline_dir),
                capture_output=True,
                text=True,
                timeout=120,
            )
            elapsed = (time.monotonic() - start) * 1000
            status = StepStatus.PASSED if result.returncode == 0 else StepStatus.FAILED
            findings = []
            if result.returncode != 0:
                findings.append(
                    Finding(
                        message=f"Python tests failed (exit code {result.returncode})",
                        severity=Severity.ERROR,
                        rule="python-tests",
                        category="testing",
                    )
                )
            return StepResult(
                name=self.name, status=status, findings=findings,
                output=result.stdout + result.stderr, duration_ms=elapsed
            )
        except FileNotFoundError:
            return StepResult(
                name=self.name,
                status=StepStatus.SKIPPED,
                output="python/pytest not found",
                duration_ms=(time.monotonic() - start) * 1000,
            )
        except subprocess.TimeoutExpired:
            return StepResult(
                name=self.name,
                status=StepStatus.FAILED,
                findings=[Finding(message="Python tests timed out", severity=Severity.ERROR)],
                duration_ms=(time.monotonic() - start) * 1000,
            )


class PythonLintRunner:
    """Run ruff linter on Python code."""

    name = "python-lint"

    def run(self, project_root: Path) -> StepResult:
        start = time.monotonic()
        pipeline_dir = project_root / "tools" / "pipeline_runner"

        if not pipeline_dir.exists():
            return StepResult(
                name=self.name,
                status=StepStatus.SKIPPED,
                output="No tools/pipeline_runner found",
                duration_ms=(time.monotonic() - start) * 1000,
            )

        try:
            result = subprocess.run(
                ["ruff", "check", "--output-format=json", "."],
                cwd=str(pipeline_dir),
                capture_output=True,
                text=True,
                timeout=30,
            )
            findings = self._parse_ruff(result.stdout, pipeline_dir, project_root)
            elapsed = (time.monotonic() - start) * 1000
            status = StepStatus.PASSED if result.returncode == 0 else StepStatus.FAILED
            return StepResult(name=self.name, status=status, findings=findings, duration_ms=elapsed)
        except FileNotFoundError:
            return StepResult(
                name=self.name,
                status=StepStatus.SKIPPED,
                output="ruff not found. Install: pip install ruff",
                duration_ms=(time.monotonic() - start) * 1000,
            )
        except subprocess.TimeoutExpired:
            return StepResult(
                name=self.name,
                status=StepStatus.FAILED,
                findings=[Finding(message="Ruff timed out", severity=Severity.ERROR)],
                duration_ms=(time.monotonic() - start) * 1000,
            )

    def _parse_ruff(self, output: str, base: Path, root: Path) -> list[Finding]:
        findings: list[Finding] = []
        try:
            import json

            for item in json.loads(output):
                findings.append(
                    Finding(
                        message=f"{item['code']}: {item['message']}",
                        severity=Severity.ERROR,
                        file=str(Path(item["filename"]).relative_to(root)) if root else item["filename"],
                        line=item.get("location", {}).get("row"),
                        rule=item.get("code"),
                        category="style",
                    )
                )
        except (ValueError, KeyError):
            pass
        return findings
