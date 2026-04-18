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

## Common infra recipes

- **Vite died** (`curl https://dev.soriaanalytics.com/` → 000):
  `cd frontend && nohup npx vite --port 5189 > /tmp/soria-vite.log 2>&1 & disown`.
  `make dev-https` is foreground-only; it dies with its shell. If recurrent,
  ticket the Makefile to daemonize like `run-dev` does.
- **"Data looks wrong" on the dev URL:** check the `EnvironmentBadge` mode
  (staging amber vs prod green) before chasing it as a pipeline bug. Routes
  via the `X-SQLMESH-ENV` header (legacy name).
