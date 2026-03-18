"""Pipeline runner: orchestrates step execution and result aggregation."""

from __future__ import annotations

import time
from pathlib import Path

from .models import PipelineResult
from .steps import (
    AdrExistenceChecker,
    ArchgateChecker,
    ElixirTestRunner,
    EnvExampleValidator,
    GitignoreValidator,
    PipelineStep,
    PythonLintRunner,
    PythonTestRunner,
    SecretsScanner,
)

# ── Pipeline Definitions ──

PIPELINES: dict[str, list[type[PipelineStep]]] = {
    "security": [
        SecretsScanner,
        GitignoreValidator,
        EnvExampleValidator,
    ],
    "architecture": [
        AdrExistenceChecker,
        ArchgateChecker,
    ],
    "quality": [
        PythonLintRunner,
    ],
    "test": [
        PythonTestRunner,
        ElixirTestRunner,
    ],
    "full": [
        SecretsScanner,
        GitignoreValidator,
        EnvExampleValidator,
        AdrExistenceChecker,
        ArchgateChecker,
        PythonLintRunner,
        PythonTestRunner,
        ElixirTestRunner,
    ],
    "pre-commit": [
        SecretsScanner,
        GitignoreValidator,
        EnvExampleValidator,
        AdrExistenceChecker,
        PythonLintRunner,
    ],
    "ci": [
        SecretsScanner,
        GitignoreValidator,
        EnvExampleValidator,
        AdrExistenceChecker,
        ArchgateChecker,
        PythonLintRunner,
        PythonTestRunner,
        ElixirTestRunner,
    ],
}


def available_pipelines() -> list[str]:
    """Return names of all defined pipelines."""
    return list(PIPELINES.keys())


def run_pipeline(name: str, project_root: Path | str) -> PipelineResult:
    """Execute a named pipeline and return aggregated results.

    Args:
        name: Pipeline name (e.g., 'security', 'full', 'ci').
        project_root: Absolute path to the project root directory.

    Returns:
        PipelineResult with all step results aggregated.

    Raises:
        ValueError: If pipeline name is not recognized.
    """
    if name not in PIPELINES:
        raise ValueError(f"Unknown pipeline: {name}. Available: {', '.join(PIPELINES.keys())}")

    root = Path(project_root).resolve()
    step_classes = PIPELINES[name]

    result = PipelineResult(pipeline=name)
    start = time.monotonic()

    for step_cls in step_classes:
        step = step_cls()
        step_result = step.run(root)
        result.steps.append(step_result)

    result.duration_ms = (time.monotonic() - start) * 1000
    return result
