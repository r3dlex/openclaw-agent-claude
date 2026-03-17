# CLAUDE.md — Developer & Contributor Guide

> This file is for **you** (Claude Code, human developers, contributors) working on improving this OpenClaw agent. It is **not** read by the OpenClaw agent itself.

## What Is This Repo?

An [OpenClaw](https://docs.openclaw.ai/) agent workspace — the set of markdown files that define an autonomous AI agent's personality, workflow, memory system, and behavioral rules.

OpenClaw is a self-hosted gateway bridging messaging platforms (WhatsApp, Telegram, Discord, iMessage, etc.) to AI agents. This repo is **not** the gateway itself — it's the workspace configuration that OpenClaw loads at runtime. OpenClaw handles its own installation, Docker deployment, and secret management separately.

## Repository Structure

```
.
├── CLAUDE.md            # You are here. Developer/contributor guide.
├── AGENTS.md            # Top-level agent instructions (progressive disclosure)
├── SOUL.md              # Agent identity, values, interaction style
├── IDENTITY.md          # Agent name, avatar, vibe (filled at first run)
├── USER.md              # About the human the agent helps (filled at runtime)
├── HEARTBEAT.md         # Periodic task checklist (editable by agent)
├── TOOLS.md             # Environment-specific tool notes (filled at runtime)
├── spec/                # Detailed specifications (agent reads on-demand)
│   ├── MEMORY.md        # Memory system: daily notes, long-term, maintenance
│   ├── HEARTBEAT.md     # Heartbeat polling system spec
│   ├── COMMUNICATION.md # Group chat rules, platform formatting
│   ├── WORKFLOW.md      # Architect / Builder / Auditor execution loop
│   └── SAFETY.md        # Red lines, internal vs external actions
├── scripts/
│   └── setup.sh         # Links this repo as the OpenClaw workspace
├── .gitignore           # Protects secrets and runtime data
├── LICENSE              # MIT
└── README.md            # Public-facing documentation
```

## Two Audiences, Separate Files

| Audience | Files | Purpose |
|---|---|---|
| **Developers / Claude Code** | `CLAUDE.md` | Improve the agent, review specs, contribute |
| **The OpenClaw agent** | `AGENTS.md` → `spec/*`, `SOUL.md`, `IDENTITY.md`, `USER.md`, `HEARTBEAT.md`, `TOOLS.md` | Agent reads these at runtime for behavior |

**Never mix concerns.** This file (CLAUDE.md) is invisible to the OpenClaw agent. The agent files should not reference development workflows.

## Progressive Disclosure Pattern

The agent's instructions follow progressive disclosure:

1. **`AGENTS.md`** — Top-level overview. Short, scannable. Links to specs.
2. **`spec/*.md`** — Deep-dive documents. Agent reads only when needed.
3. **Runtime files** — `MEMORY.md`, `memory/`, `tasks.md`, `PLAN.md` — created at runtime, never committed.

This minimizes token usage while keeping full specifications accessible.

## How OpenClaw Configuration Works

This repo does **not** manage OpenClaw's configuration. OpenClaw stores its settings in `~/.openclaw/openclaw.json` (JSON5 format). Key concepts:

- **Workspace path**: Set via `openclaw config set agents.defaults.workspace /path/to/this/repo` or using `scripts/setup.sh`.
- **API keys & secrets**: Managed by OpenClaw's SecretRef system (`openclaw secrets configure`), or via environment variables like `ANTHROPIC_API_KEY`, `DISCORD_BOT_TOKEN`, `TELEGRAM_BOT_TOKEN`.
- **Channel pairing**: Done via `openclaw pairing whatsapp`, `openclaw pairing telegram`, etc.
- **Model selection**: Set in `openclaw.json` under `agents.defaults.model` or per-agent in `agents.list`.

See [OpenClaw docs](https://docs.openclaw.ai/gateway/configuration-reference) for the full configuration reference.

## Development Guidelines

- **Security first:** Never commit `MEMORY.md`, `memory/`, `.openclaw/`, or files with credentials. The `.gitignore` handles this.
- **Keep AGENTS.md lean:** Add detail to `spec/` files, not the top-level.
- **Test behavioral changes:** Modify the spec, run the agent, observe. The agent is autonomous — it will adapt.
- **No hardcoded paths:** Use relative paths within the workspace.

## Common Tasks

### Adding a new behavioral rule
1. Determine which spec it belongs to (safety, communication, workflow, etc.).
2. Add it to the relevant `spec/*.md` file.
3. If it's critical enough for top-level awareness, add a one-liner + link in `AGENTS.md`.

### Adding a new periodic check
1. Edit `HEARTBEAT.md` (or instruct the agent to do so).
2. For complex checks, document the pattern in `spec/HEARTBEAT.md`.

### Changing the agent's personality
1. Edit `SOUL.md` for values and interaction style.
2. Edit `IDENTITY.md` for name/avatar/vibe.

### Adding environment-specific tool config
1. Document it in `TOOLS.md` (agent-facing).
2. If it requires secrets, configure them via `openclaw secrets configure`.
