# Architecture Decision Records

> How architectural decisions are documented, enforced, and validated in this project.

## Overview

Architecture decisions are managed using [archgate](https://github.com/archgate/cli), which transforms ADRs into executable governance rules. ADRs live in `.archgate/adrs/` as markdown files with YAML frontmatter.

## ADR Structure

Each ADR follows the naming convention `ARCH-###-kebab-case-title.md`:

```yaml
---
id: ARCH-001
title: Human-Readable Title
domain: backend | security | quality | tooling
rules: true | false
files: ["glob/patterns/**/*.ex"]
---
```

The markdown body contains:

1. **Context** — why this decision was needed
2. **Decision** — what was decided and how
3. **Consequences** — positive, negative, and risks

## Current ADRs

| ID | Title | Domain |
|---|---|---|
| ARCH-001 | Session Isolation via Erlang Ports | backend |
| ARCH-002 | Event-Driven Session Monitoring via SSE | backend |
| ARCH-003 | Weighted Code Review Scoring System | quality |
| ARCH-004 | Python Pipeline Runner with Zero-Install Principles | tooling |
| ARCH-005 | Secrets Never in Git | security |

## Working with ADRs

### Creating a New ADR

If archgate is installed:

```bash
archgate adr create
```

Otherwise, create the file manually following the template above.

### Listing ADRs

```bash
archgate adr list
# or
ls .archgate/adrs/
```

### Validating ADRs

The pipeline runner validates ADR structure automatically:

```bash
cd tools/pipeline_runner
poetry run pipeline run architecture --project ../..
```

This checks:
- ADR files exist in `.archgate/adrs/`
- Each ADR has valid YAML frontmatter with required fields (id, title, domain)
- If archgate is installed, runs `archgate check` for rule compliance

### Adding Enforcement Rules

For ADRs with `rules: true`, create a companion `.rules.ts` file:

```
.archgate/adrs/ARCH-001-session-isolation.rules.ts
```

Rules are TypeScript files using archgate's `defineRules()` API. They run during `archgate check` and in the pipeline's `archgate-check` step.

## Pipeline Enforcement

ADR compliance is enforced through the pipeline runner:

| Pipeline | ADR Steps |
|---|---|
| `architecture` | adr-existence, archgate-check |
| `pre-commit` | adr-existence |
| `ci` | adr-existence, archgate-check |
| `full` | adr-existence, archgate-check |

The `adr-existence` step always runs (no external dependency). The `archgate-check` step requires the archgate CLI and gracefully skips if not installed.

## When to Create an ADR

Create a new ADR when:

- Choosing a technology, framework, or library
- Defining a system boundary or integration pattern
- Establishing a security policy
- Making a decision that affects multiple modules
- Changing an existing architectural pattern

Do not create ADRs for:

- Implementation details within a single module
- Bug fixes
- Minor refactoring that does not change boundaries

## Relationship to Factory Reviews

Factory code reviews (via `POST /api/v1/reviews`) evaluate design compliance as one of five scoring categories (25% weight). The review session reads ADRs from `.archgate/adrs/` to understand the project's architectural intent before scoring.

> Pipeline step reference: [spec/PIPELINES.md](PIPELINES.md)
> Review scoring: [spec/ORCHESTRATION.md](ORCHESTRATION.md#reviews)
