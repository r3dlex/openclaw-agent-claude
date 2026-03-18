# Software Factory: Claude Code Orchestrator

An autonomous software factory built on [OpenClaw](https://docs.openclaw.ai/) and Elixir/OTP. It orchestrates multiple [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI sessions to build software end-to-end through messaging platforms.

## Architecture

```
User (WhatsApp / Telegram / Discord)
  |
  v
OpenClaw Gateway (Node.js)
  |
  v
Lead Orchestrator Agent (AGENTS.md + SOUL.md + spec/)
  |
  v  HTTP / SSE
Factory (Elixir/OTP)
  |
  v  Erlang Ports
Claude CLI Sessions (background, parallel, --dangerously-skip-permissions)
  |
  v
Code changes, tests, commits in target repositories
```

**The agent operates in two modes:**

* **ARCHITECT** — DDD expert, security architect, code reviewer, quality engineer, DevOps engineer, performance engineer. Plans architecture, decomposes tasks, reviews output.
* **BUILDER** — Session orchestrator, TDD implementation lead, reliability engineer, documentation writer. Launches Claude CLI sessions, monitors progress, auto-responds to routine questions.

**Execution loop:** Architecture > Execution > Quality Gate > Delivery + Code Review/PR Evaluation

## Quick Start

### Option A: Docker (zero-install)

```bash
git clone https://github.com/r3dlex/openclaw-agent-claude.git
cd openclaw-agent-claude
cp .env.example .env
# Edit .env: set AGENT_DATA_DIR and optionally channel tokens
./scripts/setup.sh --docker --detach
```

This starts two containers:
* **openclaw** — Gateway + agent workspace (port 18789)
* **factory** — Elixir session manager (port 4000)

Open `http://localhost:18789` for the web chat UI.

### Option B: Local Install

```bash
# 1. Install OpenClaw
npm install -g openclaw@latest
openclaw onboard --install-daemon
openclaw plugins install @betrue/openclaw-claude-code-plugin

# 2. Clone and link workspace
git clone https://github.com/r3dlex/openclaw-agent-claude.git
cd openclaw-agent-claude
./scripts/setup.sh

# 3. Start the Factory
cd factory && mix deps.get && mix run --no-halt &

# 4. Pair a channel (or use web chat)
openclaw pairing whatsapp     # Scan QR code
openclaw pairing telegram     # Enter bot token
openclaw dashboard            # Web chat UI
```

### First Conversation

The agent bootstraps on its first message. It picks a name, learns about you, then gets to work. Send it a project description and watch it decompose, plan, launch sessions, and deliver.

## Repository Structure

```
AGENTS.md                      # Top-level agent instructions
SOUL.md                        # Identity, roles, execution loop
IDENTITY.md                    # Name, avatar (filled at bootstrap)
USER.md                        # About you (filled at runtime)
HEARTBEAT.md                   # Periodic task checklist
TOOLS.md                       # Environment notes + Factory API
spec/                          # Detailed behavioral specs
  ORCHESTRATION.md             # Factory API, session management
  WORKFLOW.md                  # Execution loop (5 phases)
  PIPELINES.md                 # Pipeline runner framework
  ARCHITECTURE.md              # ADR management via archgate
  TESTING.md                   # Testing strategy and coverage
  MEMORY.md                    # Memory system
  HEARTBEAT.md                 # Heartbeat system
  COMMUNICATION.md             # Group chat rules
  SAFETY.md                    # Red lines & session safety
factory/                       # Elixir/OTP session manager
  mix.exs                      # Elixir project (Bandit, Plug, PubSub)
  Dockerfile                   # Multi-stage build (Elixir + Node.js)
  lib/factory/
    session/worker.ex          # GenServer per Claude CLI session
    session/manager.ex         # Lifecycle, limits, garbage collection
    workspace/tasks.ex         # tasks.md parser
    workspace/plan.ex          # PLAN.md manager
    review/evaluator.ex        # Code review session manager
    review/scoring.ex          # Weighted scoring engine (0-100%)
    review/manager.ex          # Review lifecycle
    api/router.ex              # HTTP API + SSE endpoints
    events/bus.ex              # PubSub event bus
tools/                         # Development tooling
  pipeline_runner/             # Python pipeline framework (Poetry)
    pyproject.toml             # Dependencies, pytest config, ruff
    pipeline_runner/           # Source: models, steps, runner, cli
    tests/                     # pytest suite (80% coverage target)
.archgate/                     # Architecture Decision Records
  adrs/                        # ARCH-###-title.md files
scripts/
  Dockerfile                   # OpenClaw gateway image
  entrypoint.sh                # Gateway startup
  setup.sh                     # Setup (local or Docker)
docker-compose.yml             # Two-service deployment
.env.example                   # All configuration variables
```

## Configuration

| What | Where | How |
|---|---|---|
| Data directory | `.env` | `AGENT_DATA_DIR=/path/to/data` |
| Max sessions | `.env` | `MAX_SESSIONS=5` |
| Agent personality | `SOUL.md` | Edit directly |
| Agent behavior | `AGENTS.md` > `spec/` | Edit, agent reads at session start |
| Session orchestration | `spec/ORCHESTRATION.md` | Factory API patterns |
| Model selection | `.env` or `openclaw.json` | `DEFAULT_MODEL=claude-opus-4-20250514` (opus/sonnet/haiku) |
| Channel pairing | OpenClaw CLI | `openclaw pairing <channel>` |

## Factory API

The Factory exposes an HTTP API at `http://localhost:${FACTORY_PORT}`:

| Endpoint | Description |
|---|---|
| `POST /api/v1/sessions` | Launch a Claude CLI session |
| `GET /api/v1/sessions` | List all sessions |
| `POST /api/v1/sessions/:name/respond` | Send input to a waiting session |
| `POST /api/v1/sessions/:name/kill` | Terminate a session |
| `GET /api/v1/events` | SSE event stream |
| `GET /api/v1/workspace/tasks` | Read tasks.md |
| `PUT /api/v1/workspace/plan` | Write PLAN.md |
| `POST /api/v1/reviews` | Launch a code review (codebase or PR) |
| `GET /api/v1/reviews/:id` | Get review results with scores (0-100%) |

See [spec/ORCHESTRATION.md](spec/ORCHESTRATION.md) for the full API reference.

## Pipelines

Automated validation via Python pipeline runner (`tools/pipeline_runner/`):

```bash
cd tools/pipeline_runner && poetry install
poetry run pipeline run security --project ../..   # Secrets, .gitignore, .env
poetry run pipeline run full --project ../..       # All checks
poetry run pipeline run ci --project ../.. --ci    # CI mode (exit code)
```

Available pipelines: `security`, `architecture`, `quality`, `test`, `full`, `pre-commit`, `ci`.

GitHub Actions run all pipelines on every push and PR (`.github/workflows/ci.yml`). PRs also get a sensitive data scan (`.github/workflows/pr-review.yml`).

See [spec/PIPELINES.md](spec/PIPELINES.md) for details. Architecture decisions tracked via [archgate](https://github.com/archgate/cli) in `.archgate/adrs/`. See [spec/ARCHITECTURE.md](spec/ARCHITECTURE.md).

## Contributing

See [CLAUDE.md](CLAUDE.md) for the developer guide.

## License

[MIT](LICENSE)
