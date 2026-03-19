# HEARTBEAT.md

## Tasks (run on each 5min poll)

1. **Check running sessions** — query `GET /api/v1/sessions` for active sessions, note any failures or completions
2. **Check task progress** — read `tasks.md` via Factory API, summarize pending vs completed
3. **Check pipeline status** — if CI is running, check GitHub Actions for pass/fail
4. **Log results** — update `memory/YYYY-MM-DD.md` with session and pipeline status

## When to Alert (via Telegram)

- Session failure or unexpected exit
- Quality gate failure with reasons
- Pipeline or CI failure
- All tasks completed (milestone)
- Blocked on user input

## When to Stay Quiet (HEARTBEAT_OK)

- All sessions running normally
- No state changes since last check
- Nothing actionable
