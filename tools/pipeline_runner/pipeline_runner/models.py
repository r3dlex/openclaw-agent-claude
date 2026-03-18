"""Pipeline data models."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any


class StepStatus(Enum):
    """Status of a pipeline step execution."""

    PENDING = "pending"
    RUNNING = "running"
    PASSED = "passed"
    FAILED = "failed"
    SKIPPED = "skipped"


class Severity(Enum):
    """Finding severity levels."""

    ERROR = "error"
    WARNING = "warning"
    INFO = "info"


@dataclass
class Finding:
    """A single finding from a pipeline step."""

    message: str
    severity: Severity = Severity.ERROR
    file: str | None = None
    line: int | None = None
    rule: str | None = None
    category: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {k: v.value if isinstance(v, Enum) else v for k, v in self.__dict__.items() if v is not None}


@dataclass
class StepResult:
    """Result of executing a single pipeline step."""

    name: str
    status: StepStatus
    findings: list[Finding] = field(default_factory=list)
    duration_ms: float = 0.0
    output: str = ""

    @property
    def passed(self) -> bool:
        return self.status == StepStatus.PASSED

    @property
    def error_count(self) -> int:
        return sum(1 for f in self.findings if f.severity == Severity.ERROR)

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "status": self.status.value,
            "passed": self.passed,
            "error_count": self.error_count,
            "duration_ms": self.duration_ms,
            "findings": [f.to_dict() for f in self.findings],
            "output": self.output,
        }


@dataclass
class PipelineResult:
    """Aggregate result of a full pipeline run."""

    pipeline: str
    steps: list[StepResult] = field(default_factory=list)
    duration_ms: float = 0.0

    @property
    def passed(self) -> bool:
        return all(s.passed or s.status == StepStatus.SKIPPED for s in self.steps)

    @property
    def total_errors(self) -> int:
        return sum(s.error_count for s in self.steps)

    @property
    def summary(self) -> dict[str, int]:
        counts: dict[str, int] = {}
        for s in self.steps:
            counts[s.status.value] = counts.get(s.status.value, 0) + 1
        return counts

    def to_dict(self) -> dict[str, Any]:
        return {
            "pipeline": self.pipeline,
            "passed": self.passed,
            "total_errors": self.total_errors,
            "summary": self.summary,
            "duration_ms": self.duration_ms,
            "steps": [s.to_dict() for s in self.steps],
        }
