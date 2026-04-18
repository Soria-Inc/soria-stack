---
name: status
description: Pipeline reconnaissance for Codex. Use when the user asks what exists for a concept, scraper, group, model, warehouse table, or dive, and answer through `soria` CLI inventory plus filesystem checks instead of guessing.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: status/SKILL.md
  variant: codex
---

# Status

Codex adaptation of the `Soria-Inc/soria-stack` `/status` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- `soria env status`, `soria list`, `soria group show`, `soria file show`
- `soria db query` and `soria warehouse query`
- dive filesystem and git-state reconnaissance
- report gaps, staleness, and incomplete pipeline stages explicitly
