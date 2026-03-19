# CLAUDE.md — Developer & Contributor Guide

> For **developers and Claude Code** improving this workspace. The OpenClaw agent does **not** read this file.

## What Is This Repo?

A Software Factory built on [OpenClaw](https://docs.openclaw.ai/) and an Elixir/OTP backend. It defines an autonomous AI agent that orchestrates multiple Claude Code CLI sessions to build software end-to-end.

**Components:**

1. **Agent Workspace** (root markdown files) — behavioral instructions read by OpenClaw at runtime
2. **Factory** (`factory/`) — Elixir application that manages Claude CLI sessions as supervised OTP processes
3. **Infrastructure** (Docker, scripts) — zero-install deployment

## Repository Structure

```
.
├── AGENTS.md                      # Top-level agent instructions
├── SOUL.md                        # Agent identity, roles, execution loop
├── IDENTITY.md                    # Name, avatar (filled at first run)
├── USER.md                        # About the human (filled at runtime)
├── HEARTBEAT.md                   # Periodic task checklist
├── TOOLS.md                       # Environment notes + Factory API reference
├── spec/                          # Detailed specs (agent reads on-demand)
│   ├── ORCHESTRATION.md           # Factory API, session management
│   ├── WORKFLOW.md                # Execution loop (5 phases)
│   ├── PIPELINES.md               # Pipeline runner framework
│   ├── ARCHITECTURE.md            # ADR management via archgate
│   ├── TESTING.md                 # Testing strategy and coverage
│   ├── MEMORY.md                  # Memory system
│   ├── HEARTBEAT.md               # Heartbeat system
│   ├── COMMUNICATION.md           # Channel rules (Telegram, Discord, etc.)
│   └── SAFETY.md                  # Red lines, session safety
├── factory/                       # Elixir/OTP session manager
│   ├── mix.exs                    # Dependencies (Bandit, Plug, Jason, PubSub)
│   ├── Dockerfile                 # Multi-stage: Elixir release + Node.js (for claude CLI)
│   ├── config/                    # App config (reads env vars at runtime)
│   └── lib/factory/
│       ├── application.ex         # OTP supervision tree
│       ├── session/worker.ex      # GenServer per CLI session (Port-based)
│       ├── session/manager.ex     # Lifecycle, limits, GC
│       ├── workspace/tasks.ex     # tasks.md parser/writer
│       ├── workspace/plan.ex      # PLAN.md reader/writer
│       ├── review/evaluator.ex    # Code review session orchestrator
│       ├── review/scoring.ex      # Weighted scoring engine (0-100%)
│       ├── review/manager.ex      # Review lifecycle management
│       ├── api/router.ex          # HTTP API + SSE endpoints
│       ├── events/bus.ex          # PubSub event bus
│       └── logging/               # Disk-based session logging
├── tools/                         # Development tooling
│   └── pipeline_runner/           # Python pipeline framework (Poetry)
│       ├── pyproject.toml         # Dependencies, pytest config, ruff
│       ├── pipeline_runner/       # Source: models, steps, runner, cli
│       └── tests/                 # pytest suite (80% coverage target)
├── logs/                          # Local dev logs (gitkeep'd, contents ignored)
├── .archgate/                     # Architecture Decision Records
│   └── adrs/                      # ARCH-###-title.md files
├── scripts/
│   ├── Dockerfile                 # OpenClaw gateway image
│   ├── entrypoint.sh             # Gateway startup
│   └── setup.sh                   # Local or Docker setup
├── docker-compose.yml             # Two services: openclaw + factory
├── .env.example                   # All configuration variables
├── .gitignore
├── LICENSE
└── README.md
```

## Two Audiences

| Audience | Files | Purpose |
|---|---|---|
| **Developers / Claude Code** | `CLAUDE.md`, `factory/` | Improve the factory, review specs |
| **The OpenClaw agent** | `AGENTS.md` > `spec/*`, `SOUL.md`, `TOOLS.md` | Behavioral instructions at runtime |

Never mix concerns. This file is invisible to the agent.

## Architecture

```
OpenClaw Gateway (Node.js)
  ↕ messaging platforms
Agent reads: AGENTS.md → SOUL.md → spec/*
  ↕ HTTP / SSE
Factory (Elixir/OTP, port 4000)
  ↕ Erlang Ports
Claude CLI sessions (--dangerously-skip-permissions)
  ↕ filesystem
Target repositories
```

**Data flow:**
1. User sends message via WhatsApp/Telegram/Discord
2. OpenClaw routes to agent (reads workspace markdown)
3. Agent calls Factory API to launch/monitor sessions
4. Factory manages CLI processes, streams events back via SSE
5. Agent reviews output, reports to user

## Development

### Running the Factory locally

```bash
cd factory
mix deps.get
AGENT_DATA_DIR=./data FACTORY_PORT=4000 mix run --no-halt
```

### Running everything via Docker

```bash
cp .env.example .env
# Edit .env
docker compose up --build
```

### Adding a new behavioral rule
1. Add to the relevant `spec/*.md` file.
2. If critical, add a one-liner + link in `AGENTS.md`.

### Modifying the Factory
1. Edit Elixir modules in `factory/lib/`.
2. Run tests: `cd factory && mix test`.
3. The API surface is in `factory/lib/factory/api/router.ex`.

### Running Pipelines
```bash
cd tools/pipeline_runner
poetry install
poetry run pytest                              # Run pipeline runner tests
poetry run pipeline run security --project ../..   # Security scan
poetry run pipeline run full --project ../..       # All checks
```

### Adding an Architecture Decision
1. Create `.archgate/adrs/ARCH-###-title.md` with YAML frontmatter (id, title, domain).
2. Validate: `poetry run pipeline run architecture --project ../..`
3. See [spec/ARCHITECTURE.md](spec/ARCHITECTURE.md) for the full template.

### Modifying the agent's personality
1. Edit `SOUL.md` for roles, values, interaction style.
2. Edit `IDENTITY.md` for name/avatar.

## Security Rules

* **Never commit** `.env`, `MEMORY.md`, `memory/`, `.openclaw/`, `data/`, or credentials.
* The `.gitignore` is comprehensive. Verify with `git status` before committing.
* All secrets flow through env vars or OpenClaw SecretRef.
* Runtime data lives in `$AGENT_DATA_DIR`, outside the repo.
