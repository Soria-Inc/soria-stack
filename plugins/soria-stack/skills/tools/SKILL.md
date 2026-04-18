---
name: tools
description: Verify that the `soria` CLI, auth, and the active environment are ready in Codex. Use at the start of a Soria session or whenever the workflow is blocked by missing CLI setup, missing auth, or no active environment.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: tools/SKILL.md
  variant: codex
---

# Tools

Codex adaptation of the `Soria-Inc/soria-stack` `/tools` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- verify `soria` is installed and report its version
- verify auth/bootstrap and active env state
- stop early if the CLI or auth is missing
- route the user into `env`, `status`, `plan`, or `ingest` once the shell is ready
