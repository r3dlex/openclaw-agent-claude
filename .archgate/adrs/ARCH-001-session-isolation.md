---
id: ARCH-001
title: Session Isolation via Erlang Ports
domain: backend
rules: false
files: ["factory/lib/factory/session/**/*.ex"]
---

# ARCH-001: Session Isolation via Erlang Ports

## Context

The Software Factory must run multiple Claude Code CLI sessions concurrently. Each session manipulates files in a target repository and may run for minutes. Sessions must be isolated from each other and from the Factory process itself.

## Decision

Each Claude CLI session runs as a separate OS process managed via Erlang Ports within a supervised GenServer. The Factory's OTP supervision tree ensures:

- **Process isolation**: A crashed CLI session does not bring down the Factory.
- **Resource limits**: MAX_SESSIONS enforced by the Session Manager.
- **Lifecycle management**: Idle timeout, garbage collection of completed sessions.
- **Communication**: stdin/stdout forwarding via Port for multi-turn interaction.

## Consequences

### Positive
- Fault tolerance: one session crash does not affect others.
- Each session runs in its own working directory.
- OTP supervision provides automatic cleanup.

### Negative
- Cannot share in-process memory between sessions.
- Erlang Port buffer management adds complexity.

### Risks
- Zombie processes if Port.close fails. Mitigated by OS pid tracking and kill -9 fallback.
