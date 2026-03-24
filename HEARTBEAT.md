# HEARTBEAT.md

## Tasks (run on each 5min poll)

1. **Message queue heartbeat** — `POST http://127.0.0.1:18790/heartbeat` with `{"agent_id": "agent_claude"}` to stay registered with the Inter-Agent Message Queue (if first poll of session, do full registration with metadata per TOOLS.md)
2. **Check message queue inbox** — `GET http://127.0.0.1:18790/inbox/agent_claude?status=unread` — process messages from other agents, mark `read`/`acted`, reply via `POST http://127.0.0.1:18790/send` with `replyTo`
3. **Check online agents** — `GET http://127.0.0.1:18790/agents` to know which sibling agents are available
4. **Check running sessions** — query `GET /api/v1/sessions` for active sessions, note any failures or completions
5. **Check task progress** — read `tasks.md` via Factory API, summarize pending vs completed
6. **Check pipeline status** — if CI is running, check GitHub Actions for pass/fail
7. **Log results** — update `memory/YYYY-MM-DD.md` with session and pipeline status

## Report to User

Send a Telegram summary ONLY when there's something worth reporting:
- Sessions started/completed/failed: "Session complete: built [feature]. Quality gate passed."
- Errors, quality gate failures, blocked tasks: report IMMEDIATELY.
- Do NOT send a message if nothing happened. Silent heartbeats are fine.

## When to Alert (via Telegram)

- New message queue message requiring action (forward to user if relevant)
- Session failure or unexpected exit
- Quality gate failure with reasons
- Pipeline or CI failure
- All tasks completed (milestone)
- Blocked on user input

## When to Stay Quiet (HEARTBEAT_OK)

- All sessions running normally
- Message queue inbox empty, no new messages
- No state changes since last check
- Nothing actionable
