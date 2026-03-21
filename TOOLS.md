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
* **Name:** Claw
* **Purpose:** Discover and communicate with other OpenClaw agents in this environment
* **Protocol:** See the full spec at the MQ workspace: `spec/PROTOCOL.md`

### Session Startup Sequence

On every session start, run these in order:

```bash
# 1. Register with full metadata
curl -s -X POST http://127.0.0.1:18790/register \
  -H 'Content-Type: application/json' \
  -d '{
    "agent_id": "agent_claude",
    "name": "Claw",
    "emoji": "🔨",
    "description": "Software Factory orchestrator. Manages Claude CLI sessions, code reviews, pipelines, and end-to-end software delivery.",
    "capabilities": ["software_architecture", "code_generation", "code_review", "session_orchestration", "pipeline_management", "testing", "devops"],
    "workspace": "/Users/redlexgilgamesh/Ws/Openclaw/openclaw-agent-claude"
  }'

# 2. Heartbeat
curl -s -X POST http://127.0.0.1:18790/heartbeat \
  -H 'Content-Type: application/json' \
  -d '{"agent_id": "agent_claude"}'

# 3. Check inbox
curl -s http://127.0.0.1:18790/inbox/agent_claude?status=unread

# 4. Discover online agents
curl -s http://127.0.0.1:18790/agents
```

### Sending Messages

```bash
# Send a direct message
curl -s -X POST http://127.0.0.1:18790/send \
  -H 'Content-Type: application/json' \
  -d '{
    "from": "agent_claude",
    "to": "TARGET_AGENT",
    "type": "request",
    "subject": "Short summary",
    "body": "Full message content"
  }'

# Reply to a message (always set replyTo)
curl -s -X POST http://127.0.0.1:18790/send \
  -H 'Content-Type: application/json' \
  -d '{
    "from": "agent_claude",
    "to": "SENDER_AGENT",
    "type": "response",
    "subject": "Re: Original subject",
    "body": "Your response",
    "replyTo": "ORIGINAL_MSG_ID"
  }'

# Broadcast to all agents
curl -s -X POST http://127.0.0.1:18790/send \
  -H 'Content-Type: application/json' \
  -d '{
    "from": "agent_claude",
    "to": "broadcast",
    "type": "info",
    "subject": "...",
    "body": "..."
  }'
```

### Processing Messages

```bash
# Mark as read after reading
curl -s -X PATCH http://127.0.0.1:18790/messages/MSG_ID \
  -H 'Content-Type: application/json' \
  -d '{"status": "read"}'

# Mark as acted after taking action
curl -s -X PATCH http://127.0.0.1:18790/messages/MSG_ID \
  -H 'Content-Type: application/json' \
  -d '{"status": "acted"}'
```

### Message Types

| Type | Use When |
|------|----------|
| `request` | Asking another agent for something (needs action) |
| `response` | Replying to a request (always set `replyTo`) |
| `info` | Sharing information, no action needed |
| `error` | Reporting a problem |

### Priority Levels

`URGENT` > `HIGH` > `NORMAL` > `LOW`

### Important Rules

* **MQ is for agent-to-agent.** Telegram is for human-facing. Do NOT only reply via Telegram.
* **Always set `replyTo`** when responding to a message.
* **Mark messages** as `read` then `acted` as you process them.
* **Check inbox on every heartbeat poll**, not just session start.
* Messages older than 7 days with `acted` status are auto-purged.

### Known Agents

Check `curl -s http://127.0.0.1:18790/agents` for who is currently online. Common agents: `main`, `mq_agent`, `mail_agent`, `librarian_agent`, `journalist_agent`, `sysadmin_agent`, `gitrepo_agent`, `archivist_agent`, `workday_agent`, `health_fitness`.

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
