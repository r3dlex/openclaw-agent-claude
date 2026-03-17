# Session Orchestration via the Factory

> How you launch, monitor, and manage Claude Code CLI sessions through the Elixir Factory backend.

## Architecture

The Factory is an Elixir/OTP application that manages Claude Code CLI processes. Each session is a supervised GenServer wrapping an Erlang Port running `claude --dangerously-skip-permissions`. The Factory exposes an HTTP API for you to interact with sessions.

```
You (OpenClaw Agent)
  |
  v  HTTP / SSE
Factory (Elixir/OTP)
  |
  v  Erlang Port (stdin/stdout)
Claude CLI Sessions (background, parallel)
  |
  v
Target repositories (code changes, tests, commits)
```

**Factory URL:** `http://localhost:${FACTORY_PORT}` (default: 4000)

## API Reference

### Sessions

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/sessions` | Launch a new session |
| `GET` | `/api/v1/sessions` | List all sessions (filter: `?status=running`) |
| `GET` | `/api/v1/sessions/:name` | Get session details |
| `GET` | `/api/v1/sessions/:name/output` | Get output (`?full=true`, `?lines=N`) |
| `POST` | `/api/v1/sessions/:name/respond` | Send input to a waiting session |
| `POST` | `/api/v1/sessions/:name/kill` | Terminate a session |

### Workspace

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/workspace/tasks` | Read tasks.md |
| `PUT` | `/api/v1/workspace/tasks` | Overwrite tasks.md |
| `PATCH` | `/api/v1/workspace/tasks/:index` | Toggle a task (check/uncheck) |
| `GET` | `/api/v1/workspace/plan` | Read PLAN.md |
| `PUT` | `/api/v1/workspace/plan` | Overwrite PLAN.md |

### Events & Stats

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/events` | SSE stream of all factory events |
| `GET` | `/api/v1/sessions/:name/events` | SSE stream for one session |
| `GET` | `/api/v1/stats` | Aggregate session statistics |
| `GET` | `/health` | Health check |

## Launching Sessions

**POST /api/v1/sessions:**

```json
{
  "name": "fix-auth-bug",
  "prompt": "You are working on: [task]. Context: [PLAN.md excerpt]. Write tests first.",
  "workdir": "/repos/my-project",
  "multi_turn": true,
  "max_budget_usd": 5.0,
  "model": "claude-opus-4-20250514"
}
```

Rules:
* **`name`** — kebab-case, descriptive, unique (e.g., `add-user-api`, `audit-deps`)
* **`prompt`** — complete task description with all context the session needs
* **`workdir`** — absolute path to the target repository
* **`multi_turn: true`** — unless the task is definitively one-shot

Budget calibration:
* Small fix: 1-2 USD
* Feature: 5 USD
* Major refactor: 10+ USD

## Multi-turn Interaction

When a session asks a question (SSE `session.waiting` event):

1. Read the question: `GET /api/v1/sessions/:name/output?full=true`
2. Decide: auto-respond or escalate

**Auto-respond immediately:**
* Permission requests for file/bash operations
* Routine confirmations ("Should I continue?", "Ready to proceed?")
* Approach questions with obvious answers from the task context
* Known codebase clarifications you can answer from memory

**Escalate to user:**
* Architecture decisions (technology choices, major patterns)
* Destructive operations (database migrations, force pushes, deleting data)
* Ambiguous requirements that need human judgment
* Scope or budget changes
* Credentials or production environment concerns
* When you are uncertain

## SSE Event Types

| Event | Description |
|---|---|
| `session_started` | New session launched |
| `session_output` | New output line from a session |
| `session_waiting` | Session is asking a question |
| `session_responded` | Follow-up sent to a session |
| `session_ended` | Session completed or crashed |
| `session_killed` | Session was terminated |
| `session_timeout` | Session killed due to idle timeout |
| `tasks_updated` | tasks.md was modified |
| `plan_updated` | PLAN.md was modified |

## Session Lifecycle

* Sessions idle for `IDLE_TIMEOUT_MINUTES` (default 30) are killed automatically.
* Completed sessions are garbage-collected after `SESSION_GC_MINUTES` (default 60).
* Max concurrent sessions: `MAX_SESSIONS` (default 5).
* All output is logged to `$AGENT_DATA_DIR/logs/<session-name>.log`.

## Parallel Execution

* Launch independent tasks as separate sessions.
* Respect the `MAX_SESSIONS` limit.
* Each session must have a unique name.
* Sequence tasks with dependencies; parallelize independent ones.
* Monitor via SSE events, not polling.

## Reviews

The Factory supports launching code reviews and PR evaluations that produce structured scoring.

### Review API

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/reviews` | Launch a code review |
| `GET` | `/api/v1/reviews` | List all reviews |
| `GET` | `/api/v1/reviews/:id` | Get review results with scores |

### Launching a Review

**POST /api/v1/reviews:**

```json
{
  "type": "codebase",
  "target": "Full repository evaluation",
  "workdir": "/repos/my-project",
  "model": "claude-opus-4-20250514"
}
```

For PR reviews:

```json
{
  "type": "pr",
  "target": "main..feature-branch",
  "workdir": "/repos/my-project"
}
```

Fields:
* **`type`** — `codebase` (full repo) or `pr` (pull request diff)
* **`target`** — for PR: branch range or ref. For codebase: description or path focus
* **`workdir`** — absolute path to the repository
* **`model`** — optional model override (defaults to opus)

### Scoring Categories

Each review produces scores across five weighted categories:

| Category | Weight | What It Covers |
|---|---|---|
| Security | 25% | Vulnerabilities, secrets, auth, input validation, OWASP compliance |
| Design | 25% | Architecture compliance, DDD boundaries, SOLID, abstractions |
| Style | 15% | Naming, formatting, consistency, language idioms, Clean Code |
| Practices | 20% | Testing, error handling, logging, DRY, performance, edge cases |
| Documentation | 15% | Inline comments, API docs, README, migration notes |

### Verdicts

The composite score (weighted average) maps to a verdict:

| Score | Verdict |
|---|---|
| 90-100% | `approve` |
| 70-89% | `approve_with_comments` |
| 50-69% | `request_changes` |
| 0-49% | `reject` |

### Review Events

| Event | Description |
|---|---|
| `review_started` | Review session launched |
| `review_completed` | Review finished with scores |

## Anti-patterns

| Problem | Fix |
|---|---|
| Not using `multi_turn: true` | Always enable unless one-shot |
| Not reading output after completion | Always read and summarize to user |
| Auto-responding to architecture decisions | Escalate to user |
| Wrong workdir | Verify target project path before launching |
| Unnamed or vaguely named sessions | Always name in kebab-case matching the task |
| Ignoring SSE `session_waiting` events | Handle prompts immediately |
| Launching too many parallel sessions | Sequence when at limit |
| Not checking logs after crashes | Always read `$AGENT_DATA_DIR/logs/<name>.log` |
