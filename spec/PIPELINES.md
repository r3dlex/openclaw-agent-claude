# Pipelines

> Automated validation pipelines for security, architecture compliance, code quality, and testing.

## Overview

The pipeline runner (`tools/pipeline_runner/`) provides a unified framework for running validation checks locally, in CI, and within Docker. It is written in Python with Poetry for zero-install reproducibility.

## Available Pipelines

| Pipeline | Steps | When to Use |
|---|---|---|
| `security` | secrets-scan, gitignore-check, env-example-check | Before every commit |
| `architecture` | adr-existence, archgate-check | After architecture changes |
| `quality` | python-lint | During development |
| `test` | python-tests, elixir-tests | Before merging |
| `full` | All steps | Comprehensive local validation |
| `pre-commit` | security + architecture + lint | Git pre-commit hook |
| `ci` | All steps | GitHub Actions / CI pipeline |

## Running Pipelines

### Local (Poetry)

```bash
cd tools/pipeline_runner
poetry install
poetry run pipeline run security --project ../..
poetry run pipeline run full --project ../.. --ci
```

### Docker (zero-install)

```bash
docker run --rm -v $(pwd):/workspace pipeline-runner run ci --project /workspace
```

### JSON Output

```bash
poetry run pipeline run security --project ../.. --json-output
```

### List Available Pipelines

```bash
poetry run pipeline list
```

## Pipeline Steps

### Security

| Step | What It Checks |
|---|---|
| `secrets-scan` | Hardcoded API keys, passwords, private keys, AWS credentials |
| `gitignore-check` | Required patterns in .gitignore (.env, *.pem, memory/, etc.) |
| `env-example-check` | No real secrets in .env.example |

### Architecture

| Step | What It Checks |
|---|---|
| `adr-existence` | ADR files exist in .archgate/adrs/ with valid YAML frontmatter |
| `archgate-check` | Runs `archgate check` for rule compliance (skips if not installed) |

### Code Quality

| Step | What It Checks |
|---|---|
| `python-lint` | Ruff linting on Python code |

### Testing

| Step | What It Checks |
|---|---|
| `python-tests` | pytest suite for the pipeline runner |
| `elixir-tests` | mix test for the Factory |

## Step Behavior

Steps follow these principles:

* **Self-contained**: Each step runs independently with no shared state.
* **Graceful degradation**: If a tool is not installed (e.g., archgate, mix, ruff), the step returns `SKIPPED` rather than `FAILED`.
* **Structured output**: Every step returns findings with severity (error/warning/info), file, line, and rule.
* **Timeouts**: Each step has a timeout (30-120s) to prevent hanging in CI.

## Adding New Steps

1. Create a class implementing the `PipelineStep` protocol in `pipeline_runner/steps.py`:
   ```python
   class MyChecker:
       name = "my-check"
       def run(self, project_root: Path) -> StepResult:
           ...
   ```
2. Add it to the relevant pipeline(s) in `pipeline_runner/runner.py`.
3. Write tests in `tests/test_steps.py`.

## CI Integration

### GitHub Actions

The repository includes two workflow files in `.github/workflows/`:

**`.github/workflows/ci.yml`** — Runs on push to main and all PRs:

| Job | Pipeline | What It Does |
|---|---|---|
| `security` | `security` | Secrets scan, .gitignore, .env.example |
| `architecture` | `architecture` | ADR existence and archgate compliance |
| `quality` | `quality` | Ruff linting |
| `test-python` | pytest | Pipeline runner test suite with coverage |
| `test-elixir` | mix test | Factory test suite with coverage |
| `ci-pass` | gate | Requires all jobs to pass |

**`.github/workflows/pr-review.yml`** — Runs on PRs only:

| Job | What It Does |
|---|---|
| `pre-commit-checks` | Runs the `pre-commit` pipeline |
| `sensitive-data-scan` | Scans PR diff for secrets, local paths, credentials |

Each pipeline runs as a separate job for clear, parallel feedback in the GitHub UI.

### Pre-commit Hook

```bash
#!/bin/sh
cd tools/pipeline_runner && poetry run pipeline run pre-commit --project ../.. --ci
```

## Result Format

Pipeline results are structured as:

```json
{
  "pipeline": "security",
  "passed": true,
  "total_errors": 0,
  "summary": {"passed": 3, "skipped": 0},
  "duration_ms": 42.5,
  "steps": [
    {
      "name": "secrets-scan",
      "status": "passed",
      "passed": true,
      "error_count": 0,
      "findings": [],
      "duration_ms": 30.1
    }
  ]
}
```

## Relationship to Factory Reviews

Pipeline validation is complementary to Factory code reviews:

* **Pipelines**: Automated, deterministic checks (secrets, patterns, lint, tests). Fast, run locally.
* **Factory Reviews**: AI-powered evaluation (architecture quality, design patterns, overall scoring). Deeper, run as sessions.

Use pipelines as a gate before Factory reviews. A PR that fails pipeline security checks should not proceed to AI review.
