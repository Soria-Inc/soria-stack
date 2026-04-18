---
name: ingest
description: Build and run Soria ingestion pipelines in Codex. Use for scraping, grouping, schema work, extraction, validation, value-mapping handoff, refresh runs, and publishing bronze — all through `mcp__soria__*` tools.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: ingest/SKILL.md
  variant: codex
---

# Ingest

Codex adaptation of the `Soria-Inc/soria-stack` `/ingest` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- scraper -> groups/schema -> detect/extract -> validate -> publish (bronze)
- exact MCP tools:
  `mcp__soria__scraper_manage / scraper_run`,
  `mcp__soria__group_manage`,
  `mcp__soria__schema_manage / schema_mappings`,
  `mcp__soria__detection_run / extraction_run / validation_run`,
  `mcp__soria__warehouse_manage(action="publish")`
- `test=True` on scraper_run + extraction_run to dry-run inline code before
  `scraper_manage(action="save")` commits it to shared state
- human review gates at each major step
- browser inspection only when it materially helps the scrape or extract path

## Notes

- Writes are soft-delete reversible via `deleted_at` + the `PipelineEvent`
  audit trail. Check `mcp__soria__pipeline_activity` before starting so you
  don't race a concurrent run.
- Bronze lands at `soria_duckdb_staging.bronze.{table}`. Prod promotion is
  PR-gated; do not call `warehouse_promote` from here (that's `/promote`).
