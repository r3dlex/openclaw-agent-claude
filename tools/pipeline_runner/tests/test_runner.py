"""Tests for the pipeline runner orchestration."""

from pathlib import Path

import pytest

from pipeline_runner.runner import available_pipelines, run_pipeline


@pytest.fixture
def tmp_project(tmp_path: Path) -> Path:
    """Minimal project with .gitignore and .env.example."""
    (tmp_path / ".gitignore").write_text(".env\n*.pem\n*.key\nmemory/\nMEMORY.md\ndata/\n")
    (tmp_path / ".env.example").write_text("AGENT_DATA_DIR=./data\nFACTORY_PORT=4000\n")
    return tmp_path


class TestAvailablePipelines:
    def test_returns_list(self):
        pipelines = available_pipelines()
        assert isinstance(pipelines, list)
        assert len(pipelines) > 0

    def test_includes_core_pipelines(self):
        pipelines = available_pipelines()
        for name in ("security", "architecture", "quality", "test", "full", "pre-commit", "ci"):
            assert name in pipelines


class TestRunPipeline:
    def test_unknown_pipeline_raises(self, tmp_project: Path):
        with pytest.raises(ValueError, match="Unknown pipeline"):
            run_pipeline("nonexistent", tmp_project)

    def test_security_pipeline_clean(self, tmp_project: Path):
        result = run_pipeline("security", tmp_project)
        assert result.pipeline == "security"
        assert len(result.steps) == 3
        assert result.passed is True
        assert result.duration_ms > 0

    def test_security_pipeline_detects_secrets(self, tmp_project: Path):
        (tmp_project / "leak.py").write_text('api_key = "sk-abcdefghijklmnopqrstuvwxyz1234567890"\n')
        result = run_pipeline("security", tmp_project)
        assert result.passed is False
        assert result.total_errors > 0

    def test_architecture_pipeline(self, tmp_project: Path):
        result = run_pipeline("architecture", tmp_project)
        assert result.pipeline == "architecture"
        assert len(result.steps) == 2

    def test_full_pipeline_runs_all_steps(self, tmp_project: Path):
        result = run_pipeline("full", tmp_project)
        assert result.pipeline == "full"
        assert len(result.steps) >= 5

    def test_result_to_dict(self, tmp_project: Path):
        result = run_pipeline("security", tmp_project)
        d = result.to_dict()
        assert d["pipeline"] == "security"
        assert isinstance(d["steps"], list)
        assert isinstance(d["passed"], bool)
        assert isinstance(d["total_errors"], int)

    def test_pre_commit_pipeline(self, tmp_project: Path):
        result = run_pipeline("pre-commit", tmp_project)
        assert result.pipeline == "pre-commit"
        step_names = [s.name for s in result.steps]
        assert "secrets-scan" in step_names
        assert "gitignore-check" in step_names
