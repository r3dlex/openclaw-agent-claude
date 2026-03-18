---
id: ARCH-004
title: Python Pipeline Runner with Zero-Install Principles
domain: tooling
rules: false
files: ["tools/pipeline_runner/**/*.py"]
---

# ARCH-004: Python Pipeline Runner with Zero-Install Principles

## Context

The Factory needs automated validation pipelines for security scanning, architecture compliance (via archgate), code quality, and test execution. These pipelines must run locally, in CI, and within Docker containers.

## Decision

Implement the pipeline runner as a Python package in `tools/pipeline_runner/` using:

- **Poetry** for dependency management and packaging.
- **Click** for CLI interface.
- **Modular steps** following a Protocol pattern for extensibility.
- **Named pipelines** (security, architecture, quality, test, full, pre-commit, ci) composed from reusable steps.

Each step is self-contained, returns structured results, and gracefully degrades when tools are unavailable (e.g., archgate not installed = skip, not fail).

## Consequences

### Positive
- Consistent validation across local dev, CI, and Docker.
- Easy to add new steps without modifying existing ones.
- JSON output mode enables machine consumption.
- Graceful degradation: missing tools cause SKIP, not FAIL.

### Negative
- Additional Python dependency alongside Elixir.
- Poetry requires Python 3.11+.

### Risks
- Step timeouts on slow CI runners. Mitigated by per-step timeout defaults (30-120s).
