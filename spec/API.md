# Factory REST API

> Complete reference for the Elixir Factory HTTP API. Default port: **4000**.

Base URL: `http://localhost:${FACTORY_PORT}` (default `http://localhost:4000`)

All request and response bodies are JSON unless noted otherwise.

---

## Health

### GET /health

Returns server status.

**Response:**

```json
{
  "status": "ok",
  "sessions": 3,
  "uptime_seconds": 14523
}
```

---

## Sessions

### POST /api/v1/sessions

Launch a new Claude CLI session.

**Request:**

```json
{
  "name": "fix-auth-bug",
  "prompt": "You are a BUILDER. Task: fix the JWT validation bug in auth.ex ...",
  "workdir": "/repos/my-project",
  "model": "claude-opus-4-20250514",
  "max_budget_usd": 5.0,
  "multi_turn": true
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Unique kebab-case session identifier |
| `prompt` | string | yes | Full task prompt with all context |
| `workdir` | string | yes | Absolute path to the target repository |
| `model` | string | no | Model override (defaults to opus) |
| `max_budget_usd` | number | no | Spending cap for the session |
| `multi_turn` | boolean | no | Enable follow-up interaction (default `true`) |

**Response (201):**

```json
{
  "name": "fix-auth-bug",
  "status": "running",
  "started_at": "2026-03-23T10:15:00Z"
}
```

**Errors:**

| Status | Cause |
|---|---|
| 400 | Missing required field or invalid name |
| 409 | Session with that name already exists |
| 429 | Max concurrent sessions reached |

---

### GET /api/v1/sessions

List all sessions. Optionally filter by status.

**Query params:**

| Param | Type | Description |
|---|---|---|
| `status` | string | Filter: `running`, `completed`, `killed`, `timeout` |

**Response (200):**

```json
[
  {
    "name": "fix-auth-bug",
    "status": "running",
    "started_at": "2026-03-23T10:15:00Z"
  },
  {
    "name": "add-user-api",
    "status": "completed",
    "started_at": "2026-03-23T09:00:00Z",
    "ended_at": "2026-03-23T09:45:00Z"
  }
]
```

---

### GET /api/v1/sessions/:name

Get details for a specific session.

**Response (200):**

```json
{
  "name": "fix-auth-bug",
  "status": "running",
  "model": "claude-opus-4-20250514",
  "workdir": "/repos/my-project",
  "started_at": "2026-03-23T10:15:00Z",
  "budget_usd": 5.0,
  "multi_turn": true
}
```

**Errors:** `404` if session not found.

---

### GET /api/v1/sessions/:name/output

Retrieve session output (stdout from the CLI process).

**Query params:**

| Param | Type | Description |
|---|---|---|
| `lines` | integer | Return last N lines (default: 50) |
| `full` | boolean | Return all output (`true` overrides `lines`) |

**Response (200):**

```json
{
  "name": "fix-auth-bug",
  "lines": [
    "Creating auth_test.exs...",
    "Running mix test...",
    "12 tests, 0 failures"
  ]
}
```

---

### POST /api/v1/sessions/:name/respond

Send a follow-up message to a waiting session.

**Request:**

```json
{
  "message": "Yes, proceed with the migration.",
  "interrupt": false
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `message` | string | yes | Text to send to the session's stdin |
| `interrupt` | boolean | no | If `true`, interrupt the current operation before sending |

**Response (200):**

```json
{
  "name": "fix-auth-bug",
  "status": "running"
}
```

**Errors:** `404` if session not found. `400` if session is not in a waiting state.

---

### POST /api/v1/sessions/:name/kill

Terminate a running session.

**Response (200):**

```json
{
  "name": "fix-auth-bug",
  "status": "killed"
}
```

**Errors:** `404` if session not found. `400` if session already ended.

---

## Workspace

### GET /api/v1/workspace/tasks

Read the current `tasks.md` content.

**Response (200):**

```json
{
  "content": "# Tasks\n\n## Batch 1\n- [x] implement-user-entity\n- [ ] implement-auth-service\n",
  "tasks": [
    {"index": 0, "text": "implement-user-entity", "checked": true},
    {"index": 1, "text": "implement-auth-service", "checked": false}
  ]
}
```

---

### PUT /api/v1/workspace/tasks

Overwrite `tasks.md` with new content.

**Request:**

```json
{
  "content": "# Tasks\n\n## Batch 1\n- [ ] implement-user-entity\n- [ ] implement-auth-service\n"
}
```

**Response (200):**

```json
{"status": "ok"}
```

---

### PATCH /api/v1/workspace/tasks/:index

Toggle a task's checked state.

**Request:**

```json
{
  "checked": true
}
```

**Response (200):**

```json
{
  "index": 0,
  "text": "implement-user-entity",
  "checked": true
}
```

**Errors:** `404` if index out of range.

---

### GET /api/v1/workspace/plan

Read the current `PLAN.md` content.

**Response (200):**

```json
{
  "content": "# Architecture Plan\n\n## Overview\n..."
}
```

---

### PUT /api/v1/workspace/plan

Overwrite `PLAN.md` with new content.

**Request:**

```json
{
  "content": "# Architecture Plan\n\n## Overview\nBuilding a REST API for..."
}
```

**Response (200):**

```json
{"status": "ok"}
```

---

## Reviews

### POST /api/v1/reviews

Launch a code review session.

**Request:**

```json
{
  "type": "codebase",
  "target": "Full repository evaluation",
  "workdir": "/repos/my-project",
  "model": "claude-opus-4-20250514"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | yes | `codebase` (full repo) or `pr` (pull request diff) |
| `target` | string | yes | For PR: branch range (e.g., `main..feature`). For codebase: description or path focus |
| `workdir` | string | yes | Absolute path to the repository |
| `model` | string | no | Model override (defaults to opus) |

**Response (201):**

```json
{
  "id": "review-a1b2c3",
  "type": "codebase",
  "status": "running",
  "started_at": "2026-03-23T11:00:00Z"
}
```

---

### GET /api/v1/reviews

List all reviews.

**Response (200):**

```json
[
  {
    "id": "review-a1b2c3",
    "type": "codebase",
    "status": "completed",
    "verdict": "approve_with_comments",
    "score": 82
  }
]
```

---

### GET /api/v1/reviews/:id

Get review results with detailed scores.

**Response (200):**

```json
{
  "id": "review-a1b2c3",
  "type": "codebase",
  "status": "completed",
  "started_at": "2026-03-23T11:00:00Z",
  "ended_at": "2026-03-23T11:12:00Z",
  "scores": {
    "security":      {"score": 85, "weight": 0.25, "findings": ["No input validation on /api/upload"]},
    "design":        {"score": 90, "weight": 0.25, "findings": []},
    "style":         {"score": 75, "weight": 0.15, "findings": ["Inconsistent naming in user_controller.ex"]},
    "practices":     {"score": 80, "weight": 0.20, "findings": ["Missing error handling in fetch_user/1"]},
    "documentation": {"score": 70, "weight": 0.15, "findings": ["No README setup instructions"]}
  },
  "composite_score": 82,
  "verdict": "approve_with_comments"
}
```

**Verdict mapping:**

| Score | Verdict |
|---|---|
| 90-100 | `approve` |
| 70-89 | `approve_with_comments` |
| 50-69 | `request_changes` |
| 0-49 | `reject` |

**Errors:** `404` if review not found.

---

## Events (SSE)

### GET /api/v1/events

Server-Sent Events stream for all Factory events. Keep the connection open; events arrive as they occur.

**Event format:**

```
event: session_started
data: {"name":"fix-auth-bug","status":"running"}

event: session_waiting
data: {"name":"fix-auth-bug","question":"Should I run the migration?"}

event: session_ended
data: {"name":"fix-auth-bug","status":"completed","exit_code":0}

event: tasks_updated
data: {"source":"api"}

event: review_completed
data: {"id":"review-a1b2c3","verdict":"approve_with_comments","score":82}
```

**Event types:**

| Event | Description |
|---|---|
| `session_started` | New session launched |
| `session_output` | New output line from a session |
| `session_waiting` | Session is asking a question |
| `session_responded` | Follow-up sent to a session |
| `session_ended` | Session completed or crashed |
| `session_killed` | Session was terminated |
| `session_timeout` | Session killed due to idle timeout |
| `tasks_updated` | `tasks.md` was modified |
| `plan_updated` | `PLAN.md` was modified |
| `review_started` | Review session launched |
| `review_completed` | Review finished with scores |

---

### GET /api/v1/sessions/:name/events

SSE stream scoped to a single session. Same event format, filtered to events for `:name` only.

---

## Stats

### GET /api/v1/stats

Aggregate session and review statistics.

**Response (200):**

```json
{
  "sessions": {
    "total": 15,
    "running": 2,
    "completed": 11,
    "killed": 1,
    "timeout": 1
  },
  "reviews": {
    "total": 3,
    "completed": 2,
    "running": 1
  },
  "uptime_seconds": 14523
}
```

---

> Session orchestration: [spec/ORCHESTRATION.md](ORCHESTRATION.md)
> Workflow phases: [spec/WORKFLOW.md](WORKFLOW.md)
> Troubleshooting: [spec/TROUBLESHOOTING.md](TROUBLESHOOTING.md)
