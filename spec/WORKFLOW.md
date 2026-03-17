# Workflow & Execution Modes

> Detailed specification of the four-phase execution loop and how each mode operates.

## Overview

The workflow is a loop through four phases. You cycle through them until all tasks are complete. Each phase activates a different mode with different responsibilities.

```
ARCHITECTURE → EXECUTION → QUALITY GATE → DELIVERY
     ^              |             |
     |              v             |
     +-------- (if tasks remain) -+
```

## Phase 1: Architecture

**Mode:** ARCHITECT
**Trigger:** New project, "Plan" request, or requirements that need decomposition.

### What the Architect Does

1. **Requirements Analysis**
   * Extract functional and non-functional requirements
   * Identify ambiguities; clarify with user if critical, decide if minor
   * Define acceptance criteria for each deliverable

2. **Domain Modeling (DDD)**
   * Identify Bounded Contexts and their boundaries
   * Define Aggregates, Entities, Value Objects within each context
   * Map Domain Events and integration points between contexts
   * Identify shared kernel vs anticorruption layers

3. **Security Threat Model**
   * Identify attack surfaces (auth, input, APIs, data at rest)
   * Define security requirements per component
   * Specify secrets management strategy
   * Plan for input validation, output encoding, CSP headers

4. **Architecture Decisions**
   * Select tech stack (language, framework, database, messaging)
   * Containerization strategy (Dockerfile, compose, K8s if needed)
   * CI/CD pipeline design
   * Performance budgets (response times, throughput targets)
   * Write decisions as ADRs in PLAN.md

5. **Task Decomposition**
   * Break into small, independent vertical slices
   * Each task must be completable by a single Claude CLI session
   * Each task must have clear inputs, outputs, and acceptance criteria
   * Define dependency graph: which tasks can run in parallel
   * Estimate session budget per task

6. **Output:** Write `PLAN.md` and `tasks.md` via Factory API

### PLAN.md Structure

```markdown
# Architecture Plan

## Overview
[One paragraph describing what we're building]

## Bounded Contexts
[List contexts with responsibilities]

## Tech Stack
[Language, framework, database, infrastructure]

## Security Requirements
[Auth strategy, secrets management, threat mitigations]

## Performance Budgets
[Response times, throughput, resource limits]

## Architecture Decision Records
[Key decisions with rationale]

## Task Dependency Graph
[Which tasks depend on which, what can run in parallel]
```

### tasks.md Structure

```markdown
# Tasks

## Batch 1 (parallel)
- [ ] implement-user-entity: User aggregate + DB schema + migrations
- [ ] implement-auth-service: JWT auth + middleware + tests

## Batch 2 (depends on Batch 1)
- [ ] implement-user-api: REST endpoints + validation + integration tests

## Batch 3 (depends on Batch 2)
- [ ] implement-e2e-tests: Full API e2e test suite
- [ ] implement-docker: Dockerfile + compose + CI pipeline
```

## Phase 2: Execution

**Mode:** BUILDER
**Trigger:** `tasks.md` has unchecked tasks.

### What the Builder Does

1. **Read State**
   * `GET /api/v1/workspace/tasks` — find highest-priority unchecked tasks
   * `GET /api/v1/workspace/plan` — get architecture context

2. **Launch Sessions**
   * `POST /api/v1/sessions` for each independent task
   * Craft precise prompts per task (see prompt template below)
   * Set budgets based on task complexity
   * Always use `multi_turn: true`

3. **Monitor & Respond**
   * Subscribe to `GET /api/v1/events` (SSE)
   * Auto-respond to routine questions (permissions, confirmations)
   * Escalate architecture decisions, destructive ops, credentials to user

4. **Collect Results**
   * When `session_ended` event fires: `GET /api/v1/sessions/:name/output?full=true`
   * Transition to Quality Gate for that task

### Session Prompt Template

```
You are a BUILDER working on a specific task in a larger project.

PROJECT: [name]
WORKING DIRECTORY: [workdir]

ARCHITECTURE CONTEXT:
[Relevant excerpt from PLAN.md]

YOUR TASK:
[Task description from tasks.md]

ACCEPTANCE CRITERIA:
[Specific criteria for this task]

CONSTRAINTS:
- Write tests FIRST. Implement SECOND. Refactor THIRD.
- Run tests. Fix until all pass. Do not stop on red.
- No hardcoded secrets, tokens, or credentials.
- Follow existing code conventions in the project.
- Use proper error handling. No silent failures.
- Add inline documentation for public APIs.

DO NOT:
- Modify files outside your task scope.
- Make architecture decisions without explicit instruction.
- Skip tests for any reason.
```

## Phase 3: Quality Gate

**Mode:** ARCHITECT
**Trigger:** A Builder session reports completion.

### Quality Review Checklist

For each completed session:

1. **Test Coverage**
   * Unit tests exist for all new functions/methods
   * Integration tests for API endpoints or service interactions
   * Edge cases covered (empty input, nulls, boundaries, errors)
   * All tests pass (check session output for test results)

2. **Security**
   * No hardcoded secrets, tokens, API keys, or paths
   * Input validation on all external inputs
   * SQL injection / XSS / CSRF protection where applicable
   * Auth/authz checks on protected endpoints
   * Error messages don't leak internal state

3. **Architecture Compliance**
   * Implementation matches PLAN.md specifications
   * Correct bounded context boundaries respected
   * Proper abstraction layers (no domain logic in controllers)
   * Dependencies flow in the right direction

4. **Code Quality**
   * Clean Code: meaningful names, small functions, single responsibility
   * DRY: no duplicated logic
   * SOLID principles applied
   * No dead code, no commented-out blocks
   * Proper logging (structured, appropriate levels)

5. **Performance**
   * No N+1 queries
   * Proper database indexing
   * Connection pooling configured
   * Async processing where appropriate
   * Resource cleanup (file handles, connections)

6. **Documentation**
   * README updated if public API changed
   * API documentation for new endpoints
   * Inline comments for complex logic
   * Migration instructions if schema changed

### Decisions

* **Pass** — `PATCH /api/v1/workspace/tasks/:index` with `{"checked": true}`
* **Fail** — Update `tasks.md` with a sub-task containing specific fix instructions. Launch a fix session.

## Phase 4: Delivery

**Mode:** ARCHITECT
**Trigger:** All tasks in `tasks.md` are checked.

### Delivery Checklist

1. **Full Test Suite** — Launch a dedicated session to run all tests
2. **Documentation** — Launch a session to generate/update:
   * README with setup, build, run, test instructions
   * API documentation
   * Architecture decision records
   * Deployment instructions
3. **Summary** — Report to user:
   * What was built (features, components)
   * Files created/modified
   * How to run it
   * Known limitations or TODOs
   * Total session spend
4. **Archive** — Note completion in daily memory file

## Phase 5: Code Review / PR Evaluation

**Mode:** ARCHITECT
**Trigger:** User requests a codebase evaluation or PR review.

### What the Architect Does

1. **Determine Review Type**
   * Codebase: full repository quality assessment
   * PR: targeted review of changes in a branch/diff

2. **Launch Review**
   * `POST /api/v1/reviews` with type, target, and workdir
   * The Factory spawns a dedicated Claude session with a structured review prompt

3. **Collect Results**
   * `GET /api/v1/reviews/:id` returns scores across five categories
   * Each category scored 0-100 with specific findings

4. **Scoring Categories**
   * **Security (25%)** — Vulnerabilities, secrets, auth, OWASP compliance
   * **Design (25%)** — Architecture compliance, DDD, SOLID, abstractions
   * **Style (15%)** — Naming, formatting, consistency, idioms
   * **Practices (20%)** — Testing, error handling, DRY, performance
   * **Documentation (15%)** — Comments, API docs, README, migration notes

5. **Verdicts**
   * 90-100%: Approve
   * 70-89%: Approve with comments
   * 50-69%: Request changes
   * 0-49%: Reject

6. **Output:** Report scores, findings, and verdict to user with actionable recommendations.

## Constraints

* **Shift-left quality:** Tests before or during implementation. Never after.
* **State is in files:** `tasks.md` and `PLAN.md` are the source of truth.
* **Budget awareness:** Track spend via `GET /api/v1/stats`. Alert user if approaching limits.
* **Session isolation:** Each session gets only the context it needs. Don't dump entire codebases.
* **Fail fast:** If a session is stuck or looping, kill it and try a different approach.
