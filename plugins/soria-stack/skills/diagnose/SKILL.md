---
name: diagnose
description: Diagnose and fix broken Soria workflows in Codex. Use for silent failures, missing data, dive load failures, schema mismatches, infrastructure issues, or pipeline behavior that looks wrong and needs triage before guessing.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: diagnose/SKILL.md
  variant: codex
---

# Diagnose

Codex adaptation of the `Soria-Inc/soria-stack` `/diagnose` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- triage first, observe before hypothesizing
- schema discovery via `mcp__soria__database_query` /
  `mcp__soria__warehouse_query` on `information_schema.columns` before any
  other query
- trace failing data through layers: Postgres state → bronze → staging →
  intermediate → marts
- use `mcp__soria__pipeline_activity / pipeline_history` as the audit trail
- use mempalace when available for prior failures or known patterns
- either fix inline (flip `deleted_at`, re-run dbt, fix SQL) or hand off to
  `ticket` with a structured disposition
