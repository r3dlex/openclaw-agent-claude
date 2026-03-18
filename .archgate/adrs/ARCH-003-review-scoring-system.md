---
id: ARCH-003
title: Weighted Code Review Scoring System
domain: quality
rules: false
files: ["factory/lib/factory/review/**/*.ex"]
---

# ARCH-003: Weighted Code Review Scoring System

## Context

The Factory supports automated code reviews and PR evaluations. Results must be actionable, consistent, and comparable across reviews.

## Decision

Implement a five-category weighted scoring system (0-100%):

| Category | Weight | Focus |
|---|---|---|
| Security | 25% | Vulnerabilities, secrets, auth, OWASP |
| Design | 25% | Architecture compliance, DDD, SOLID |
| Style | 15% | Naming, formatting, consistency |
| Practices | 20% | Testing, error handling, DRY |
| Documentation | 15% | Comments, API docs, README |

Composite score maps to verdicts: approve (90+), approve_with_comments (70+), request_changes (50+), reject (<50).

## Consequences

### Positive
- Consistent, comparable metrics across reviews.
- Weighted categories reflect project priorities (security and design weighted highest).
- Machine-readable output enables pipeline integration.

### Negative
- Scoring depends on Claude's judgment which may vary across runs.
- Fixed weights may not suit all project types.

### Risks
- Score inflation if prompts are too lenient. Mitigated by explicit criteria in review prompts.
