---
name: plan
description: ETVLR planning for Codex. Use when the user wants a plan before building, when a data task needs phase breakdowns, verification criteria, or sequencing across ingest, mapping, dive work, verification, and promotion.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: plan/SKILL.md
  variant: codex
---

# Plan

Codex adaptation of the `Soria-Inc/soria-stack` `/plan` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- break work into Extract, Transform, Value Map, Load, and Represent phases
- R phase targets a dive (dbt marts + manifest + TSX + DivesPage entry +
  verify seed rows + methodology content) — not a legacy dashboard
- define verification before implementation
- ask clarifying questions directly when the plan depends on a real choice
- use mempalace when available for prior context and domain grounding
- t-shirt sizing (S/M/L/XL), never time estimates
