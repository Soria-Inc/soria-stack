---
name: map
description: Value mapping for Codex. Use when raw values need to be normalized to canonical forms across eras and sources, and drive the workflow through `soria value` commands with evidence instead of hand-wavy string matching.
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

- `soria value index`, `soria value read`, and mapping updates
- semantic normalization decisions with concrete evidence
- mempalace support when available for ticker, company, or domain grounding
- hand off to `verify` after substantial mapping changes
