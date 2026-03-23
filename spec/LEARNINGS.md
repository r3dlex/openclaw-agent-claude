# Learnings

> Timestamped log of discoveries, mistakes, and insights accumulated during development and operation.

## Format

Each entry follows this structure:

```
### YYYY-MM-DD — Short title

What happened, what was learned, and what changed as a result.
Optionally link to relevant specs, commits, or files.
```

Entries are appended chronologically. Never delete old entries — they are the project's institutional memory.

---

### 2026-03-23 — IAMQ integration added to the Factory

The Factory now includes two GenServer clients for the Inter-Agent Message Queue:

- **`Factory.MqClient`** — HTTP-based registration, heartbeat, inbox polling, and message sending via `POST /send`.
- **`Factory.MqWsClient`** — WebSocket client (`ws://:18793/ws`) for real-time message push without polling delay.

Key decisions:
- Registration happens on Factory boot. If IAMQ is unreachable, the client retries with backoff rather than crashing the supervision tree.
- Heartbeat interval defaults to 60s (`IAMQ_HEARTBEAT_MS`). Inbox polling defaults to 30s (`IAMQ_POLL_MS`), but WebSocket mode makes polling a fallback.
- The OpenClaw gateway (Node.js) can intercept `127.0.0.1` — when running behind the gateway, set `IAMQ_WS_URL` to the host LAN IP.

Gotcha: the HTTP API runs on `:18790` but WebSocket runs on `:18793`. Mixing them up causes silent connection failures.

> IAMQ config: [.env.example](../.env.example) | Troubleshooting: [spec/TROUBLESHOOTING.md](TROUBLESHOOTING.md#iamq-integration)
