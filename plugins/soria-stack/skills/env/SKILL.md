---
name: env
description: Manage Soria development environments through the `soria env` CLI in Codex. Use for listing, creating, checking out, diffing, restoring, or tearing down environments, and keep the same CLI-first workflow as the Claude `env` skill without using Soria MCP.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: env/SKILL.md
  variant: codex
---

# Env

Codex adaptation of the `Soria-Inc/soria-stack` `/env` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- `soria env list|status|branch|checkout|diff|teardown|restore`
- environment selection, worktree awareness, and prod safety
- concrete next CLI commands instead of vague environment advice

## Notes

- Use a short direct question if the user must choose an environment.
- Honor repo `AGENTS.md` safety rules for teardown and diff checks.
