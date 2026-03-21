# HEARTBEAT.md

## Tasks (run on each 5min poll)

1. **MQ heartbeat** — `POST http://127.0.0.1:18790/heartbeat` with `{"agent_id": "agent_claude"}` to stay registered (if first poll of session, do full registration with metadata per TOOLS.md)
2. **Check MQ inbox** — `GET http://127.0.0.1:18790/inbox/agent_claude?status=unread` — process messages, mark `read`/`acted`, reply via `POST /send` with `replyTo`
3. **Check online agents** — `GET http://127.0.0.1:18790/agents` to know who is available for collaboration
4. **Check running sessions** — query `GET /api/v1/sessions` for active sessions, note any failures or completions
5. **Check task progress** — read `tasks.md` via Factory API, summarize pending vs completed
6. **Check pipeline status** — if CI is running, check GitHub Actions for pass/fail
7. **Log results** — update `memory/YYYY-MM-DD.md` with session and pipeline status

## When to Alert (via Telegram)

- New MQ message requiring action (forward to user if relevant)
- Session failure or unexpected exit
- Quality gate failure with reasons
- Pipeline or CI failure
- All tasks completed (milestone)
- Blocked on user input

## When to Stay Quiet (HEARTBEAT_OK)

- All sessions running normally
- MQ inbox empty, no new messages
- No state changes since last check
- Nothing actionable
