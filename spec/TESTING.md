# Testing Strategy

> How testing is structured, executed, and enforced across the Software Factory.

## Overview

Testing happens at three levels:

1. **Unit/Integration tests** within each component (Elixir, Python)
2. **Pipeline validation** via the pipeline runner (security, architecture, quality)
3. **Factory code reviews** via AI-powered evaluation sessions

## Test Suites

### Python Pipeline Runner

**Location:** `tools/pipeline_runner/tests/`
**Framework:** pytest with pytest-cov
**Coverage threshold:** 80% minimum

```bash
cd tools/pipeline_runner
poetry install
poetry run pytest
```

Test categories:
- `test_models.py` — Data model serialization, scoring, status tracking
- `test_steps.py` — Each pipeline step in isolation with fixture projects
- `test_runner.py` — Pipeline orchestration, composition, error handling

### Elixir Factory

**Location:** `factory/test/`
**Framework:** ExUnit
**Command:**

```bash
cd factory
mix deps.get
mix test --cover
```

Test categories:
- Session worker lifecycle (start, respond, kill, output buffering)
- Session manager limits and garbage collection
- Workspace task parser (markdown checkbox parsing, toggling)
- Review scoring engine (category weights, verdict mapping)
- API router endpoint responses

## Pipeline-Based Testing

The pipeline runner executes tests as pipeline steps:

| Pipeline | Test Steps |
|---|---|
| `test` | python-tests, elixir-tests |
| `full` | python-tests, elixir-tests (plus all other steps) |
| `ci` | python-tests, elixir-tests (plus all other steps) |

Run all tests via pipeline:

```bash
cd tools/pipeline_runner
poetry run pipeline run test --project ../..
```

## Testing Principles

### Shift-Left Quality

Tests must be written *before* or *during* implementation, never after. This applies to:
- Factory Elixir modules
- Pipeline runner Python code
- Sessions launched by the Builder (session prompts mandate TDD)

### Test Isolation

- Each test creates its own fixtures (tmp_path, tmp_project)
- No shared mutable state between tests
- External tools that may not be installed (archgate, mix, ruff) cause SKIP, not FAIL

### Graceful Degradation

Pipeline steps handle missing dependencies gracefully:

| Condition | Result |
|---|---|
| archgate not installed | Step: SKIPPED |
| mix not installed | Step: SKIPPED |
| ruff not installed | Step: SKIPPED |
| Timeout exceeded | Step: FAILED with finding |
| Tool crashes | Step: FAILED with error details |

### Structured Results

Every test step produces structured output compatible with the pipeline result format:

```json
{
  "name": "python-tests",
  "status": "passed",
  "error_count": 0,
  "findings": [],
  "duration_ms": 1234.5
}
```

## CI Testing

### GitHub Actions

```yaml
name: Tests
on: [push, pull_request]
jobs:
  pipeline:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.17"
          otp-version: "27"
      - name: Pipeline Runner Tests
        working-directory: tools/pipeline_runner
        run: |
          pip install poetry
          poetry install
          poetry run pytest
      - name: Factory Tests
        working-directory: factory
        run: |
          mix deps.get
          mix test
      - name: Full Pipeline
        working-directory: tools/pipeline_runner
        run: poetry run pipeline run ci --project ../.. --ci
```

### Local Pre-commit

```bash
#!/bin/sh
cd tools/pipeline_runner && poetry run pipeline run pre-commit --project ../.. --ci
```

## Adding Tests

### For a New Pipeline Step

1. Add the step class in `pipeline_runner/steps.py`
2. Create test fixtures that exercise pass/fail scenarios in `tests/test_steps.py`
3. Add the step to relevant pipelines in `pipeline_runner/runner.py`
4. Add a runner-level test in `tests/test_runner.py`

### For a New Factory Module

1. Create the test file in `factory/test/`
2. Test public API, error cases, and edge cases
3. Add the module to the `elixir-tests` pipeline step scope

### For a New ADR

1. Create the ADR in `.archgate/adrs/ARCH-###-title.md`
2. If adding rules, create the companion `.rules.ts` file
3. Verify with: `poetry run pipeline run architecture --project ../..`

## Coverage Goals

| Component | Target | Enforcement |
|---|---|---|
| Pipeline Runner (Python) | 60% | pytest-cov --cov-fail-under=60 (external tool steps excluded) |
| Factory (Elixir) | 70% | mix test --cover |
| Pipeline Steps | 100% of step classes have tests | Manual review |
| ADRs | All have valid frontmatter | adr-existence pipeline step |

> Pipeline reference: [spec/PIPELINES.md](PIPELINES.md)
> Architecture validation: [spec/ARCHITECTURE.md](ARCHITECTURE.md)
> Quality gate: [spec/WORKFLOW.md](WORKFLOW.md#phase-3-quality-gate)
