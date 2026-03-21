# TOOLS.md — Local Notes

Skills define _how_ tools work. This file is for _your_ specifics.

## Factory API

* **Base URL:** `http://localhost:${FACTORY_PORT}` (default: `http://localhost:4000`)
* **Auth:** Bearer token via `FACTORY_API_TOKEN` (if configured)
* **Docs:** See [spec/ORCHESTRATION.md](spec/ORCHESTRATION.md)

## Data Directory

* **Path:** `$AGENT_DATA_DIR` (see .env)
* **Contains:** `tasks.md`, `PLAN.md`, `memory/`, `logs/`, `sessions/`

## Workspace Logs

* **Path:** `logs/` (workspace root)
* **Purpose:** Local development logs, pipeline output, debug logs
* **Git:** Directory tracked via `.gitkeep`, contents gitignored
* **Factory logs** still go to `$AGENT_DATA_DIR/logs/` (separate from workspace logs)

## Inter-Agent Message Queue (IAMQ)

* **Base URL:** `http://127.0.0.1:18790`
* **Agent ID:** `agent_claude`
* **Purpose:** Discover and communicate with other OpenClaw agents in this environment

### Quick Reference

```bash
# Register / heartbeat (call periodically to stay online)
curl -X POST http://127.0.0.1:18790/heartbeat \
  -H 'Content-Type: application/json' \
  -d '{"agent_id": "agent_claude"}'

# Check inbox for new messages
curl http://127.0.0.1:18790/inbox/agent_claude?status=unread

# Send a message to another agent
curl -X POST http://127.0.0.1:18790/send \
  -H 'Content-Type: application/json' \
  -d '{"from":"agent_claude","to":"TARGET_AGENT","type":"request","subject":"...","body":"..."}'

# Mark message as read
curl -X PATCH http://127.0.0.1:18790/messages/MSG_ID \
  -H 'Content-Type: application/json' \
  -d '{"status":"read"}'

# List all online agents
curl http://127.0.0.1:18790/agents

# Broadcast to all agents
curl -X POST http://127.0.0.1:18790/send \
  -H 'Content-Type: application/json' \
  -d '{"from":"agent_claude","to":"broadcast","type":"info","subject":"...","body":"..."}'
```

### Message Types

| Type | Use When |
|------|----------|
| `request` | Asking another agent for something |
| `response` | Replying to a request |
| `info` | Sharing information, no response needed |
| `error` | Reporting a problem |

### Priority Levels

`URGENT` > `HIGH` > `NORMAL` > `LOW`

### Known Agents

Check `curl http://127.0.0.1:18790/agents` for who is currently online. Common agents in this environment: `main`, `mail_agent`, `librarian_agent`, `journalist_agent`, `sysadmin_agent`, `gitrepo_agent`, `archivist_agent`.

## Environment-Specific Details

Add your specifics here:

* Camera names and locations
* SSH hosts and aliases
* Preferred voices for TTS
* Speaker/room names
* Device nicknames
* Target repository paths for sessions

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

> Safety rules: [spec/SAFETY.md](spec/SAFETY.md)

---

Add whatever helps you do your job. This is your cheat sheet.
