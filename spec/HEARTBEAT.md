# Heartbeat System Specification

> This document describes the heartbeat polling system and when to use it vs cron.

## What Is a Heartbeat?

A periodic poll where the agent checks if anything needs attention. The default prompt:

> Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK.

The root `HEARTBEAT.md` file is your checklist. Keep it small to limit token burn. Edit it freely to add or remove periodic tasks.

## Heartbeat vs Cron

| Use heartbeat when... | Use cron when... |
|---|---|
| Multiple checks batch together | Exact timing matters ("9:00 AM sharp") |
| You need conversational context | Task needs isolation from main session |
| Timing can drift (~30 min is fine) | You want a different model for the task |
| Fewer API calls via batching | One-shot reminders ("remind me in 20 min") |

**Tip:** Batch similar periodic checks into `HEARTBEAT.md` instead of creating multiple cron jobs.

## What to Check (rotate 2-4x per day)

- **Emails** — urgent unread messages?
- **Calendar** — events in next 24-48h?
- **Mentions** — social/platform notifications?
- **Weather** — relevant if the human might go out?

## When to Reach Out

- Important email arrived
- Calendar event coming up (<2h)
- Something interesting you found
- It's been >8h since you last said anything

## When to Stay Quiet (HEARTBEAT_OK)

- Late night (23:00-08:00) unless urgent
- Human is clearly busy
- Nothing new since last check
- You just checked <30 minutes ago

## Proactive Work (No Permission Needed)

- Read and organize memory files
- Check on projects (git status, etc.)
- Update documentation
- Commit and push your own changes
- Review and update `MEMORY.md` (see [Memory spec](./MEMORY.md))
