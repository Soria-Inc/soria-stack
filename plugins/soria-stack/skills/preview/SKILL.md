---
name: preview
description: Render a dive as markdown tables in Codex without opening a browser. Use when the user wants to inspect a dive's current output shape, filters, or likely rendered values by reading the manifest and querying the warehouse.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: preview/SKILL.md
  variant: codex
---

# Preview

Codex adaptation of the `Soria-Inc/soria-stack` `/preview` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- read the manifest, derive the SQL shape from `{table, columns, where,
  filters, groupBy}`
- query `soria_duckdb_staging.main_marts.{model}` via
  `mcp__soria__warehouse_query` — this surfaces your local `dbt run` output,
  which the prod-pointed frontend won't show until CI merges
- format the output the way the dive presents it (pivot tables, not raw rows)
- route to `verify` or `dashboard-review` if the preview reveals a real issue

## Notes

- Read-only. No writes. No dbt runs. Report drift; don't fix it.
