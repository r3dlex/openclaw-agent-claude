# Memory System Specification

> This document describes how the agent manages continuity across sessions.

## Architecture

The agent wakes up stateless each session. Persistent files provide continuity.

### Daily Notes — `memory/YYYY-MM-DD.md`

- Raw logs of what happened during the day.
- Create the `memory/` directory at runtime if it doesn't exist.
- Capture decisions, context, events, and anything worth referencing later.
- Never store secrets here unless explicitly asked.

### Long-Term Memory — `MEMORY.md`

- Curated, distilled knowledge — the equivalent of human long-term memory.
- Updated periodically by reviewing daily notes and extracting what matters.
- **Security rule**: Only load `MEMORY.md` in main sessions (direct chat with your human). Never load it in shared contexts (Discord groups, sessions with strangers).

### Heartbeat State — `memory/heartbeat-state.json`

Tracks when periodic checks were last performed:

```json
{
  "lastChecks": {
    "email": 1703275200,
    "calendar": 1703260800,
    "weather": null
  }
}
```

## Session Startup Sequence

1. Read `SOUL.md` — who you are.
2. Read `USER.md` — who you're helping.
3. Read `memory/YYYY-MM-DD.md` (today + yesterday) for recent context.
4. **Main session only**: Also read `MEMORY.md`.

No permission needed. Just do it.

## Memory Maintenance

Periodically (every few days), during a heartbeat:

1. Read recent daily note files.
2. Identify significant events, lessons, or insights.
3. Update `MEMORY.md` with distilled learnings.
4. Remove outdated entries from `MEMORY.md`.

Daily files are raw notes. `MEMORY.md` is curated wisdom.

## The Write-It-Down Rule

Memory is limited. If you want to remember something, **write it to a file**.

- "Remember this" → update `memory/YYYY-MM-DD.md` or the relevant file.
- Learned a lesson → update `AGENTS.md`, `TOOLS.md`, or the relevant spec.
- Made a mistake → document it so future-you doesn't repeat it.

**Files survive session restarts. "Mental notes" don't.**
