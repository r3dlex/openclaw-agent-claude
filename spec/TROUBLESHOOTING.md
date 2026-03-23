# Troubleshooting

> Common issues, root causes, and fixes for the Software Factory stack.

## Factory Server

### Factory won't start

| Symptom | Cause | Fix |
|---|---|---|
| `eaddrinuse` on port 4000 | Another process on the port | `lsof -i :4000` and kill the stale process, or set `FACTORY_PORT` to a different port |
| `(Mix) Could not start application factory` | Missing deps or config | Run `mix deps.get` then verify `.env` is sourced |
| Crash loop on boot | Missing `AGENT_DATA_DIR` directory | Create it: `mkdir -p $AGENT_DATA_DIR/logs` |
| `(RuntimeError) :crypto not available` | Erlang built without OpenSSL | Reinstall Erlang/OTP with OpenSSL support (`asdf install erlang` with `KERL_CONFIGURE_OPTIONS`) |

### Port conflicts with IAMQ

The Factory defaults to `:4000` and IAMQ to `:18790`. If the OpenClaw gateway (Node.js) intercepts `127.0.0.1`, set explicit host IPs:

```bash
# .env
FACTORY_PORT=4000
IAMQ_HTTP_URL=http://192.168.1.X:18790
IAMQ_WS_URL=ws://192.168.1.X:18793/ws
```

### Factory crashes under load

Check `logs/factory.log` for OTP crash reports. Common causes:

- Too many concurrent sessions — lower `MAX_SESSIONS` (default 5)
- Erlang Port buffer overflow — a single session producing massive output; kill it with `POST /api/v1/sessions/:name/kill`

## Session Management

### Session stuck in `running` state

1. Check if the CLI process is alive: `GET /api/v1/sessions/:name`
2. Look at the last output: `GET /api/v1/sessions/:name/output?lines=20`
3. If waiting for input, the SSE stream should have emitted `session_waiting` — respond or kill

| Cause | Fix |
|---|---|
| Session waiting for a prompt you missed | `POST /api/v1/sessions/:name/respond` with `{"message": "yes"}` |
| Claude CLI hung (no output for minutes) | `POST /api/v1/sessions/:name/kill` and relaunch |
| Idle timeout not firing | Verify `IDLE_TIMEOUT_MINUTES` env var is set (default 30) |

### Session OOM (out of memory)

Symptoms: session killed by OS, no `session_ended` event, zombie Erlang Port.

- Reduce `max_budget_usd` to limit session length
- Avoid dumping entire codebases into prompts — provide only relevant context
- Monitor with `GET /api/v1/stats` for session count and memory trends

### Session timeout

Sessions idle for `IDLE_TIMEOUT_MINUTES` are killed automatically. If sessions time out too early:

```bash
# .env — increase to 60 minutes
IDLE_TIMEOUT_MINUTES=60
```

## Code Review

### Review not starting

```bash
# Verify the Factory is healthy
curl http://localhost:4000/health

# Launch a review
curl -X POST http://localhost:4000/api/v1/reviews \
  -H 'Content-Type: application/json' \
  -d '{"type": "codebase", "target": "full", "workdir": "/path/to/repo"}'
```

| Cause | Fix |
|---|---|
| `workdir` does not exist | Use an absolute path to a valid git repo |
| Max sessions reached | Wait for running sessions to finish or kill idle ones |
| Model error (rate limit, auth) | Check `ANTHROPIC_API_KEY` is valid; retry after backoff |

### Review produces no scores

The review session must output structured JSON scores. If it ends without scores:

1. Read the full output: `GET /api/v1/reviews/:id`
2. Check if the session crashed: look for `session_ended` with error in SSE events
3. Relaunch with a smaller scope (e.g., `"target": "lib/"` instead of full repo)

## IAMQ Integration

### Registration fails

```
[MQ] Registration failed: :econnrefused
```

The IAMQ service is not running or unreachable.

| Check | Command |
|---|---|
| IAMQ is running | `curl http://127.0.0.1:18790/health` |
| Correct URL configured | Verify `IAMQ_HTTP_URL` in `.env` |
| Gateway intercepting localhost | Use the host LAN IP instead of `127.0.0.1` |

### Heartbeat timeout

The Factory sends heartbeats every `IAMQ_HEARTBEAT_MS` (default 60s). If the IAMQ marks the agent as offline:

- Check the WebSocket connection: Factory logs will show `[MqWsClient]` reconnection attempts
- Verify `IAMQ_WS_URL` points to port `18793` (WebSocket), not `18790` (HTTP)
- If the gateway is in the way, set `IAMQ_WS_URL=ws://<host-ip>:18793/ws`

### Inbox empty (messages not arriving)

1. Confirm registration: `GET http://127.0.0.1:18790/agents` should list `agent_claude`
2. Check the sender used the correct `to` field: `agent_claude`
3. Verify polling is active: `IAMQ_POLL_MS` (default 30s) — or use WebSocket mode for real-time delivery
4. Check message status: messages must be `status: unread` to appear in inbox

## Docker / Deployment

### Container won't build

| Error | Fix |
|---|---|
| `npm ERR! claude` not found | The Dockerfile installs Claude CLI via npm — ensure the build has network access |
| Elixir release fails | Check `mix.exs` for version constraints; run `mix deps.get` inside the container |
| `COPY failed: file not found` | Ensure you are building from the repo root: `docker compose build` |

### Container starts but Factory unreachable

```bash
# Check the container is running
docker compose ps

# Check Factory logs
docker compose logs factory

# Verify port mapping
docker compose port factory 4000
```

Common causes:

- Factory binds to `127.0.0.1` inside the container — set `FACTORY_HOST=0.0.0.0`
- Port not exposed in `docker-compose.yml` — verify the `ports:` section
- Health check failing — `GET /health` must return 200

### Claude CLI auth inside Docker

The CLI needs `ANTHROPIC_API_KEY` at runtime. Pass it via `.env` or Docker secrets:

```yaml
# docker-compose.yml
services:
  factory:
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
```

Never bake the key into the image.

> Session management: [spec/ORCHESTRATION.md](ORCHESTRATION.md)
> Safety rules: [spec/SAFETY.md](SAFETY.md)
> Docker setup: [scripts/setup.sh](../scripts/setup.sh)
