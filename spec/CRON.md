# Cron Schedules — openclaw-agent-claude

## Overview

The Claude agent is **on-demand only**. It does not run any recurring cron jobs.
All activity is triggered by incoming IAMQ messages from users or peer agents.

There is no scheduler service and no background timer loop.

## Heartbeat

The agent sends a heartbeat to IAMQ every **60 seconds** to remain registered
and receive messages. This is driven by the OpenClaw runtime heartbeat mechanism
defined in `HEARTBEAT.md`, not by a cron expression.

| Task | Interval | Mechanism |
|------|----------|-----------|
| IAMQ heartbeat | 60 seconds | OpenClaw heartbeat loop |
| Inbox poll | 30 seconds | OpenClaw heartbeat loop |
| Factory SSE reconnect | On disconnect | Factory event bus |

## No Scheduled Pipelines

Unlike data-gathering agents (Journalist, Tempo, Health Fitness), the Claude agent
does not schedule periodic data fetches. It responds to:

- Direct user messages via WhatsApp/Telegram/Discord
- IAMQ messages from peer agents requesting tasks, summaries, or code reviews
- Explicit requests to launch or monitor Factory sessions

## Session Cleanup

The Factory (Elixir OTP) internally enforces a session idle timeout (configurable
via `FACTORY_SESSION_TIMEOUT_SECONDS`). Timed-out sessions emit a `session_timeout`
SSE event. The agent monitors this event stream but the timeout mechanism is
internal to the Factory — not a user-visible cron.

## Adding a Recurring Task

If a scheduled task is needed in future:

1. Define the IAMQ `cron::` message subject in this file
2. Register with IAMQ on startup via `POST /crons`
3. Add a handler in the agent's heartbeat or a dedicated step module
4. Document the expected duration and failure behaviour here

---

**Related:** `spec/COMMUNICATION.md`, `spec/ARCHITECTURE.md`, `HEARTBEAT.md`

## References

- [IAMQ Cron Subsystem](https://github.com/r3dlex/openclaw-inter-agent-message-queue/blob/main/spec/CRON.md) — how cron schedules are stored and fired
- [IAMQ API — Cron endpoints](https://github.com/r3dlex/openclaw-inter-agent-message-queue/blob/main/spec/API.md#cron-scheduling)
- [IamqSidecar.MqClient.register_cron/3](https://github.com/r3dlex/openclaw-inter-agent-message-queue/tree/main/sidecar) — Elixir sidecar helper
- [openclaw-main-agent](https://github.com/r3dlex/openclaw-main-agent) — orchestrates cron-triggered pipelines
