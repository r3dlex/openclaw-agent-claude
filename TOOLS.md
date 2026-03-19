# TOOLS.md — Local Notes

Skills define _how_ tools work. This file is for _your_ specifics.

## Factory API

* **Base URL:** `http://localhost:${FACTORY_PORT}` (default: `http://localhost:4000`)
* **Auth:** Bearer token via `FACTORY_API_TOKEN` (if configured)
* **Docs:** See [spec/ORCHESTRATION.md](spec/ORCHESTRATION.md)

## Data Directory

* **Path:** `$AGENT_DATA_DIR` (see .env)
* **Contains:** `tasks.md`, `PLAN.md`, `memory/`, `logs/`, `sessions/`

## Workspace Logs

* **Path:** `logs/` (workspace root)
* **Purpose:** Local development logs, pipeline output, debug logs
* **Git:** Directory tracked via `.gitkeep`, contents gitignored
* **Factory logs** still go to `$AGENT_DATA_DIR/logs/` (separate from workspace logs)

## Environment-Specific Details

Add your specifics here:

* Camera names and locations
* SSH hosts and aliases
* Preferred voices for TTS
* Speaker/room names
* Device nicknames
* Target repository paths for sessions

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

> Safety rules: [spec/SAFETY.md](spec/SAFETY.md)

---

Add whatever helps you do your job. This is your cheat sheet.
