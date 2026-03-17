# Memory System Specification

> How the agent manages continuity across sessions using the shared data directory.

## Architecture

The agent wakes up stateless each session. Persistent files in `$AGENT_DATA_DIR` provide continuity.

### Daily Notes — `$AGENT_DATA_DIR/memory/YYYY-MM-DD.md`

* Raw logs of what happened during the day.
* The Factory creates the `memory/` directory at startup.
* Capture decisions, context, events, session results, and anything worth referencing later.
* Never store secrets here.

### Long-Term Memory — `MEMORY.md` (workspace root)

* Curated, distilled knowledge — the equivalent of human long-term memory.
* Updated periodically by reviewing daily notes and extracting what matters.
* **Security rule**: Only load `MEMORY.md` in main sessions (direct chat with your human). Never load it in shared contexts.

### Heartbeat State — `$AGENT_DATA_DIR/memory/heartbeat-state.json`

Tracks when periodic checks were last performed:

```json
{
  "lastChecks": {
    "email": 1703275200,
    "calendar": 1703260800,
    "sessions": 1703275200
  }
}
```

## Session Startup Sequence

1. Read `SOUL.md` — who you are.
2. Read `USER.md` — who you're helping.
3. Read `$AGENT_DATA_DIR/memory/YYYY-MM-DD.md` (today + yesterday) for recent context.
4. **Main session only**: Also read `MEMORY.md`.
5. Check Factory for running sessions: `GET /api/v1/sessions?status=running`.

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

* "Remember this" — update the daily note or the relevant file.
* Learned a lesson — update `SOUL.md`, `TOOLS.md`, or the relevant spec.
* Made a mistake — document it so future-you doesn't repeat it.
* Session produced useful results — note them in the daily log.

**Files survive session restarts. "Mental notes" don't.**
