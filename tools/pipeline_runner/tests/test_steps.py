"""Tests for pipeline steps."""

from pathlib import Path

import pytest

from pipeline_runner.models import StepStatus
from pipeline_runner.steps import (
    AdrExistenceChecker,
    EnvExampleValidator,
    GitignoreValidator,
    SecretsScanner,
)


@pytest.fixture
def tmp_project(tmp_path: Path) -> Path:
    """Create a minimal project structure for testing."""
    (tmp_path / ".gitignore").write_text(
        ".env\n*.pem\n*.key\nmemory/\nMEMORY.md\ndata/\n"
    )
    (tmp_path / ".env.example").write_text(
        "# Config\nAGENT_DATA_DIR=./data\nFACTORY_PORT=4000\n"
    )
    return tmp_path


class TestSecretsScanner:
    def test_clean_project(self, tmp_project: Path):
        (tmp_project / "app.py").write_text("x = 42\nprint('hello')\n")
        result = SecretsScanner().run(tmp_project)
        assert result.status == StepStatus.PASSED
        assert result.error_count == 0

    def test_detects_api_key(self, tmp_project: Path):
        (tmp_project / "config.py").write_text('API_KEY = "sk-abcdefghijklmnopqrstuvwxyz1234567890"\n')
        result = SecretsScanner().run(tmp_project)
        assert result.status == StepStatus.FAILED
        assert result.error_count > 0
        assert any("secret key" in f.message.lower() or "api key" in f.message.lower() for f in result.findings)

    def test_detects_private_key(self, tmp_project: Path):
        (tmp_project / "key.txt").write_text("-----BEGIN PRIVATE KEY-----\ndata\n-----END PRIVATE KEY-----\n")
        result = SecretsScanner().run(tmp_project)
        assert result.status == StepStatus.FAILED
        assert any("private key" in f.message.lower() for f in result.findings)

    def test_detects_hardcoded_password(self, tmp_project: Path):
        (tmp_project / "config.yaml").write_text('password: "SuperSecretPass123!"\n')
        result = SecretsScanner().run(tmp_project)
        assert result.status == StepStatus.FAILED

    def test_skips_binary_extensions(self, tmp_project: Path):
        (tmp_project / "image.png").write_bytes(b'\x89PNG' + b'secret = "abc12345678901234567"')
        result = SecretsScanner().run(tmp_project)
        assert result.status == StepStatus.PASSED

    def test_skips_git_directory(self, tmp_project: Path):
        git_dir = tmp_project / ".git" / "config"
        git_dir.parent.mkdir(parents=True)
        git_dir.write_text('api_key = "real_secret_key_here_12345678"\n')
        result = SecretsScanner().run(tmp_project)
        assert result.status == StepStatus.PASSED

    def test_reports_file_and_line(self, tmp_project: Path):
        (tmp_project / "bad.py").write_text('line1\nline2\napi_key = "abcdefghijklmnopqrstuvwxyz"\nline4\n')
        result = SecretsScanner().run(tmp_project)
        assert result.status == StepStatus.FAILED
        error = result.findings[0]
        assert error.file == "bad.py"
        assert error.line == 3


class TestGitignoreValidator:
    def test_valid_gitignore(self, tmp_project: Path):
        result = GitignoreValidator().run(tmp_project)
        assert result.status == StepStatus.PASSED

    def test_missing_gitignore(self, tmp_path: Path):
        result = GitignoreValidator().run(tmp_path)
        assert result.status == StepStatus.FAILED
        assert any("No .gitignore" in f.message for f in result.findings)

    def test_missing_patterns(self, tmp_path: Path):
        (tmp_path / ".gitignore").write_text("*.log\n")
        result = GitignoreValidator().run(tmp_path)
        assert result.status == StepStatus.FAILED
        assert result.error_count > 0


class TestEnvExampleValidator:
    def test_safe_env_example(self, tmp_project: Path):
        result = EnvExampleValidator().run(tmp_project)
        assert result.status == StepStatus.PASSED

    def test_missing_env_example(self, tmp_path: Path):
        result = EnvExampleValidator().run(tmp_path)
        assert result.status == StepStatus.PASSED  # warning only
        assert any("No .env.example" in f.message for f in result.findings)

    def test_detects_real_secret_in_example(self, tmp_path: Path):
        (tmp_path / ".env.example").write_text(
            "API_KEY=abcdefghijklmnopqrstuvwxyz1234567890\n"
        )
        result = EnvExampleValidator().run(tmp_path)
        assert result.status == StepStatus.FAILED


class TestAdrExistenceChecker:
    def test_no_archgate_dir(self, tmp_path: Path):
        result = AdrExistenceChecker().run(tmp_path)
        assert result.status == StepStatus.PASSED  # warning only

    def test_empty_adrs_dir(self, tmp_path: Path):
        (tmp_path / ".archgate" / "adrs").mkdir(parents=True)
        result = AdrExistenceChecker().run(tmp_path)
        assert result.status == StepStatus.PASSED

    def test_valid_adr(self, tmp_path: Path):
        adr_dir = tmp_path / ".archgate" / "adrs"
        adr_dir.mkdir(parents=True)
        (adr_dir / "ARCH-001-test.md").write_text(
            "---\nid: ARCH-001\ntitle: Test\ndomain: test\n---\n\n# Test ADR\n"
        )
        result = AdrExistenceChecker().run(tmp_path)
        assert result.status == StepStatus.PASSED

    def test_missing_frontmatter(self, tmp_path: Path):
        adr_dir = tmp_path / ".archgate" / "adrs"
        adr_dir.mkdir(parents=True)
        (adr_dir / "ARCH-001-bad.md").write_text("# No frontmatter\n")
        result = AdrExistenceChecker().run(tmp_path)
        assert result.status == StepStatus.FAILED

    def test_missing_required_fields(self, tmp_path: Path):
        adr_dir = tmp_path / ".archgate" / "adrs"
        adr_dir.mkdir(parents=True)
        (adr_dir / "ARCH-001-partial.md").write_text("---\nid: ARCH-001\n---\n\n# Missing title and domain\n")
        result = AdrExistenceChecker().run(tmp_path)
        assert result.status == StepStatus.FAILED
        assert result.error_count >= 2  # missing title and domain
