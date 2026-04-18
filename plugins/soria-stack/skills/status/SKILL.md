---
name: status
description: Pipeline reconnaissance in Codex. Use when the user asks what exists for a concept, scraper, group, marts model, warehouse table, or dive. Drive through `mcp__soria__database_query` / `warehouse_query` / `file_query` / `pipeline_activity` plus filesystem walks.
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

- Postgres state via `mcp__soria__database_query` (scrapers, groups, files,
  schemas, mappings, events)
- warehouse state via `mcp__soria__warehouse_query` against
  `soria_duckdb_staging` (bronze + dbt layers)
- `mcp__soria__warehouse_diff` for staging vs prod at `_file_id` grain
- dive filesystem and git-state reconnaissance under `frontend/src/dives/`
- report gaps, staleness, and incomplete pipeline stages explicitly
- read-only — never modify anything
