"""Tests for pipeline data models."""

from pipeline_runner.models import (
    Finding,
    PipelineResult,
    Severity,
    StepResult,
    StepStatus,
)


class TestFinding:
    def test_create_minimal(self):
        f = Finding(message="test error")
        assert f.message == "test error"
        assert f.severity == Severity.ERROR
        assert f.file is None

    def test_create_full(self):
        f = Finding(message="bad", severity=Severity.WARNING, file="foo.py", line=10, rule="R001", category="security")
        assert f.severity == Severity.WARNING
        assert f.file == "foo.py"
        assert f.line == 10

    def test_to_dict_excludes_none(self):
        f = Finding(message="test")
        d = f.to_dict()
        assert "file" not in d
        assert d["severity"] == "error"
        assert d["message"] == "test"

    def test_to_dict_includes_all(self):
        f = Finding(message="x", severity=Severity.INFO, file="a.py", line=1, rule="R", category="c")
        d = f.to_dict()
        assert d["file"] == "a.py"
        assert d["line"] == 1
        assert d["severity"] == "info"


class TestStepResult:
    def test_passed(self):
        r = StepResult(name="test", status=StepStatus.PASSED)
        assert r.passed is True
        assert r.error_count == 0

    def test_failed_with_findings(self):
        r = StepResult(
            name="test",
            status=StepStatus.FAILED,
            findings=[
                Finding(message="a", severity=Severity.ERROR),
                Finding(message="b", severity=Severity.WARNING),
                Finding(message="c", severity=Severity.ERROR),
            ],
        )
        assert r.passed is False
        assert r.error_count == 2

    def test_to_dict(self):
        r = StepResult(name="x", status=StepStatus.PASSED, duration_ms=42.5)
        d = r.to_dict()
        assert d["name"] == "x"
        assert d["status"] == "passed"
        assert d["passed"] is True
        assert d["duration_ms"] == 42.5


class TestPipelineResult:
    def test_empty_passes(self):
        r = PipelineResult(pipeline="test")
        assert r.passed is True
        assert r.total_errors == 0

    def test_all_pass(self):
        r = PipelineResult(
            pipeline="test",
            steps=[
                StepResult(name="a", status=StepStatus.PASSED),
                StepResult(name="b", status=StepStatus.SKIPPED),
            ],
        )
        assert r.passed is True

    def test_one_failure(self):
        r = PipelineResult(
            pipeline="test",
            steps=[
                StepResult(name="a", status=StepStatus.PASSED),
                StepResult(
                    name="b",
                    status=StepStatus.FAILED,
                    findings=[Finding(message="err", severity=Severity.ERROR)],
                ),
            ],
        )
        assert r.passed is False
        assert r.total_errors == 1

    def test_summary(self):
        r = PipelineResult(
            pipeline="test",
            steps=[
                StepResult(name="a", status=StepStatus.PASSED),
                StepResult(name="b", status=StepStatus.PASSED),
                StepResult(name="c", status=StepStatus.FAILED),
                StepResult(name="d", status=StepStatus.SKIPPED),
            ],
        )
        s = r.summary
        assert s["passed"] == 2
        assert s["failed"] == 1
        assert s["skipped"] == 1

    def test_to_dict(self):
        r = PipelineResult(pipeline="test", duration_ms=100.0)
        d = r.to_dict()
        assert d["pipeline"] == "test"
        assert d["passed"] is True
        assert isinstance(d["steps"], list)
