# OpenClaw Agent for Claude

An autonomous AI agent workspace for [OpenClaw](https://docs.openclaw.ai/) — a self-hosted gateway bridging messaging platforms to AI coding agents.

This repo defines a Claude-powered agent that operates as a **Lead Orchestrator** with three internal modes: Architect, Builder, and Auditor. It manages software projects end-to-end with shift-left quality, DDD architecture, and autonomous execution.

## Features

- **Autonomous execution** — Architect, Builder, Auditor loop with zero hand-holding
- **Multi-platform** — WhatsApp, Telegram, Discord, iMessage via OpenClaw
- **Persistent memory** — Daily notes + curated long-term memory across sessions
- **Heartbeat system** — Proactive background checks (email, calendar, mentions)
- **Progressive disclosure** — Lean top-level instructions, detailed specs on demand
- **Zero-install** — Docker container with everything included

## Quick Start

### 1. Clone & Configure

```bash
git clone https://github.com/your-org/openclaw-agent-claude.git
cd openclaw-agent-claude
cp .env.example .env
# Edit .env with your API key and preferences
```

### 2. Run with Docker (recommended)

```bash
docker build -t openclaw-agent -f scripts/Dockerfile .
docker run --rm --env-file .env -v "$(pwd)":/workspace openclaw-agent
```

### 3. Or Run Locally

Requires [Node.js 24+](https://nodejs.org/) and [OpenClaw](https://docs.openclaw.ai/):

```bash
npm install -g openclaw
openclaw start --workspace .
```

## Repository Structure

```
├── AGENTS.md            # Agent instructions (top-level, links to spec/)
├── SOUL.md              # Agent identity, values, interaction style
├── IDENTITY.md          # Name, avatar, vibe (filled during first run)
├── USER.md              # About the human (filled at runtime)
├── HEARTBEAT.md         # Periodic task checklist
├── TOOLS.md             # Environment-specific tool notes
├── spec/                # Detailed behavioral specifications
│   ├── MEMORY.md        # Memory system
│   ├── HEARTBEAT.md     # Heartbeat polling spec
│   ├── COMMUNICATION.md # Group chat & platform rules
│   ├── WORKFLOW.md      # Architect / Builder / Auditor loop
│   └── SAFETY.md        # Red lines & safety rules
├── scripts/             # Containerized operations
│   ├── Dockerfile       # Zero-install container
│   └── entrypoint.sh    # Container entrypoint
├── CLAUDE.md            # Developer/contributor guide
├── .env.example         # Environment variable template
└── LICENSE              # MIT
```

## Configuration

All configuration is via environment variables. Copy `.env.example` to `.env` and fill in your values.

| Variable | Required | Description |
|---|---|---|
| `AGENT_API_KEY` | Yes | AI provider API key |
| `OPENCLAW_WORKSPACE` | Yes | Path to this repo |
| `AGENT_MODEL` | No | Model ID (default: claude-sonnet-4-20250514) |
| `HEARTBEAT_INTERVAL` | No | Poll interval in seconds (default: 1800) |
| `AGENT_TIMEZONE` | No | Timezone (default: UTC) |
| `DISCORD_BOT_TOKEN` | No | Discord integration |
| `TELEGRAM_BOT_TOKEN` | No | Telegram integration |

## How It Works

1. **First run**: If `BOOTSTRAP.md` exists, the agent performs onboarding — picks a name, learns about you, then deletes the bootstrap file.
2. **Every session**: Reads `SOUL.md`, `USER.md`, and recent memory files to restore context.
3. **On request**: Enters Architect mode (plans DDD architecture), Builder mode (implements with tests), or Auditor mode (reviews for quality/security).
4. **Heartbeats**: Periodically checks email, calendar, and mentions. Reaches out when something needs attention.

## Contributing

See [CLAUDE.md](CLAUDE.md) for the developer guide covering:
- Repository structure and two-audience separation
- Progressive disclosure pattern
- How to add rules, modify personality, or extend capabilities

## License

[MIT](LICENSE)
