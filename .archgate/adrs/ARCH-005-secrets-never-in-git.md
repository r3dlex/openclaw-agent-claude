---
id: ARCH-005
title: Secrets Never in Git
domain: security
rules: false
files: [".gitignore", ".env.example", "**/*.md"]
---

# ARCH-005: Secrets Never in Git

## Context

The repository is public on GitHub. Any committed secret is permanently compromised regardless of subsequent removal.

## Decision

1. All secrets flow through environment variables or OpenClaw's SecretRef system.
2. `.gitignore` must include: `.env`, `*.pem`, `*.key`, `*.crt`, `memory/`, `MEMORY.md`, `data/`.
3. `.env.example` contains only placeholder/default values, never real credentials.
4. The `secrets-scan` pipeline step validates every commit.
5. CI pipeline runs `secrets-scan` on every push and PR.

## Consequences

### Positive
- Zero risk of secret leakage through git history.
- Pipeline enforcement catches accidental inclusions before push.

### Negative
- Developers must maintain .env locally.
- New secret types require updating the scanner patterns.

### Risks
- Scanner false negatives for novel secret formats. Mitigated by conservative pattern matching and periodic pattern updates.
