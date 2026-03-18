---
id: ARCH-002
title: Event-Driven Session Monitoring via SSE
domain: backend
rules: false
files: ["factory/lib/factory/events/**/*.ex", "factory/lib/factory/api/router.ex"]
---

# ARCH-002: Event-Driven Session Monitoring via SSE

## Context

The orchestrating agent needs real-time visibility into session lifecycle events (started, output, waiting, ended) without polling.

## Decision

Use Phoenix.PubSub as an internal event bus with Server-Sent Events (SSE) as the transport for external consumers. Events are published to both a global topic and per-session topics.

## Consequences

### Positive
- No polling overhead; instant notification of session state changes.
- Multiple subscribers can listen to the same events.
- SSE is simple, firewall-friendly, and requires no WebSocket upgrade.

### Negative
- SSE is unidirectional (server to client only). Responses still require HTTP POST.
- Long-lived HTTP connections consume resources.

### Risks
- Connection drops in unreliable networks. Mitigated by 30s keepalive pings.
