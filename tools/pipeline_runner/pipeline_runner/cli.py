"""CLI entrypoint for the pipeline runner."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import click
from rich.console import Console
from rich.table import Table

from .models import StepStatus
from .runner import available_pipelines, run_pipeline

console = Console()


@click.group()
@click.version_option()
def main() -> None:
    """Software Factory Pipeline Runner.

    Zero-install pipeline framework for validating architecture decisions,
    code quality, security, and testing across the factory.
    """


@main.command()
@click.argument("pipeline", type=click.Choice(available_pipelines()))
@click.option("--project", "-p", default=".", help="Project root directory")
@click.option("--json-output", "-j", is_flag=True, help="Output results as JSON")
@click.option("--ci", is_flag=True, help="CI mode: exit code reflects pass/fail")
def run(pipeline: str, project: str, json_output: bool, ci: bool) -> None:
    """Run a pipeline against a project."""
    project_root = Path(project).resolve()

    if not project_root.exists():
        console.print(f"[red]Project root not found: {project_root}[/red]")
        sys.exit(2)

    result = run_pipeline(pipeline, project_root)

    if json_output:
        click.echo(json.dumps(result.to_dict(), indent=2))
    else:
        _render_table(result)

    if ci and not result.passed:
        sys.exit(1)


@main.command(name="list")
def list_pipelines() -> None:
    """List available pipelines."""
    table = Table(title="Available Pipelines")
    table.add_column("Name", style="cyan")
    table.add_column("Steps", style="green")

    from .runner import PIPELINES

    for name, steps in PIPELINES.items():
        step_names = ", ".join(s.name for s in [cls() for cls in steps])
        table.add_row(name, step_names)

    console.print(table)


def _render_table(result) -> None:  # noqa: ANN001
    """Render pipeline results as a rich table."""
    status_icon = "[green]PASS[/green]" if result.passed else "[red]FAIL[/red]"
    console.print(f"\n Pipeline: [bold]{result.pipeline}[/bold]  {status_icon}  ({result.duration_ms:.0f}ms)\n")

    table = Table(show_header=True)
    table.add_column("Step", style="cyan", min_width=20)
    table.add_column("Status", justify="center", min_width=8)
    table.add_column("Errors", justify="right", min_width=6)
    table.add_column("Time", justify="right", min_width=8)

    for step in result.steps:
        status_map = {
            StepStatus.PASSED: "[green]PASS[/green]",
            StepStatus.FAILED: "[red]FAIL[/red]",
            StepStatus.SKIPPED: "[yellow]SKIP[/yellow]",
            StepStatus.PENDING: "[dim]PEND[/dim]",
            StepStatus.RUNNING: "[blue]RUN[/blue]",
        }
        table.add_row(
            step.name,
            status_map.get(step.status, str(step.status.value)),
            str(step.error_count) if step.error_count > 0 else "[dim]0[/dim]",
            f"{step.duration_ms:.0f}ms",
        )

    console.print(table)

    # Print findings
    for step in result.steps:
        for finding in step.findings:
            icon = {"error": "[red]E[/red]", "warning": "[yellow]W[/yellow]", "info": "[blue]I[/blue]"}
            sev = icon.get(finding.severity.value, "?")
            location = ""
            if finding.file:
                location = f" {finding.file}"
                if finding.line:
                    location += f":{finding.line}"
            console.print(f"  {sev} {finding.message}{location}")

    console.print(f"\n  Total errors: {result.total_errors}  Duration: {result.duration_ms:.0f}ms\n")
