---
name: map
description: Value mapping in Codex. Use when raw values need to be normalized to canonical forms across eras and sources. Drive through `mcp__soria__value_manage` (index / map / unmap / rename / delete) with evidence, not string matching.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: map/SKILL.md
  variant: codex
---

# Map

Codex adaptation of the `Soria-Inc/soria-stack` `/map` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- `mcp__soria__value_manage(action="read"|"index"|"map"|"unmap"|"rename")`
- semantic normalization decisions with concrete evidence (typo vs rebrand
  vs methodology change vs genuinely distinct)
- mempalace support when available for ticker, company, or domain grounding
- re-publish bronze with `force=True` after mapping updates so mapped values
  propagate
- hand off to `verify` after substantial mapping changes
