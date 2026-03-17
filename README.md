# OpenClaw Agent for Claude

An autonomous AI agent workspace for [OpenClaw](https://docs.openclaw.ai/) — a self-hosted gateway bridging messaging platforms to AI coding agents.

This repo defines a Claude-powered agent that operates as a **Lead Orchestrator** with three internal modes: Architect, Builder, and Auditor. It manages software projects end-to-end with shift-left quality, DDD architecture, and autonomous execution.

## Features

- **Autonomous execution** — Architect, Builder, Auditor loop with zero hand-holding
- **Multi-platform** — WhatsApp, Telegram, Discord, iMessage via OpenClaw
- **Persistent memory** — Daily notes + curated long-term memory across sessions
- **Heartbeat system** — Proactive background checks (email, calendar, mentions)
- **Progressive disclosure** — Lean top-level instructions, detailed specs on demand

## Quick Start

### Prerequisites

- [OpenClaw](https://docs.openclaw.ai/) installed and gateway running
- An AI provider API key (e.g., Anthropic) configured in OpenClaw

### 1. Install OpenClaw (if not already)

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon
```

### 2. Clone & Link Workspace

```bash
git clone https://github.com/your-org/openclaw-agent-claude.git
cd openclaw-agent-claude
./scripts/setup.sh
```

This runs `openclaw config set agents.defaults.workspace` to point OpenClaw at this repo.

### 3. Pair a Channel (optional)

```bash
openclaw pairing whatsapp    # Scan QR code
openclaw pairing telegram    # Enter bot token
openclaw dashboard           # Or just use the web chat
```

### 4. Start Chatting

The agent bootstraps on first message — it picks a name, learns about you, then gets to work.

### Docker

If running OpenClaw in Docker, mount this repo as the workspace volume:

```bash
# In your OpenClaw docker-compose.yml, set the workspace bind mount:
#   ~/.openclaw/workspace → /path/to/this/repo
```

See [OpenClaw Docker docs](https://docs.openclaw.ai/install/docker) for the full Docker setup.

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
├── scripts/
│   └── setup.sh         # Links this repo as the OpenClaw workspace
├── CLAUDE.md            # Developer/contributor guide
└── LICENSE              # MIT
```

## Configuration

This repo is a workspace — it defines agent behavior through markdown files. OpenClaw's own configuration (API keys, channels, models) lives in `~/.openclaw/openclaw.json`.

| What | Where | How |
|---|---|---|
| Agent personality | `SOUL.md` | Edit directly |
| Agent behavior | `AGENTS.md` → `spec/` | Edit, agent reads at session start |
| Model selection | `openclaw.json` | `openclaw config set agents.defaults.model <provider/model>` |
| API keys | OpenClaw secrets | `openclaw secrets configure` or env vars |
| Channel pairing | OpenClaw CLI | `openclaw pairing <channel>` |
| Heartbeat tasks | `HEARTBEAT.md` | Edit directly, or let the agent manage it |

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
