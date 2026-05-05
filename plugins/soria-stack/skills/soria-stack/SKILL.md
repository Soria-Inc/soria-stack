---
name: soria-stack
description: Use when the task follows the Soria MCP workflow from the `Soria-Inc/soria-stack` repo — environment preflight, status/inventory, planning, ingest/publish work, dive implementation, verification, diagnosis, or promotion. Drive the Soria platform through `mcp__soria__*` tools and this repo's `AGENTS.md`. Pair with the `browse` skill for fast browser QA and UI debugging.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  variant: codex
---

# Soria Stack

Codex adaptation of the `Soria-Inc/soria-stack` workflow. This skill is the
MCP-first operating model for Soria work in Codex. There is no `soria` CLI.

## When to use this skill

- User wants to inventory what data / pipeline state exists for a concept
- User wants a plan before changing ingestion, mappings, or dives
- User is building or fixing a dive, verify flow, or promotion flow
- User wants the Soria-stack workflow specifically, but inside Codex

## When not to use it

- If the task is generic repo coding with no Soria workflow implications
- If the task is pure browser QA, jump straight to `browse`

## Session start

Run these before making assumptions:

```bash
git status --short
```

Probe the Soria MCP (once per session):

```
mcp__soria__database_query(sql="SELECT 1 AS ok")
```

If the probe fails, the user must configure the Soria MCP in their Codex
client (HTTP endpoint at `https://<your-dbos>.cloud.dbos.dev/mcp/`) and
restart. There is no fallback — every pipeline skill depends on it.

For dive work, the default local flow is `make dev-https` from the soria-2
repo root (vite at `https://dev.soriaanalytics.com` against prod DBOS).

## Core workflow

1. Inventory before action.
   Use `mcp__soria__database_query` (Postgres state),
   `mcp__soria__warehouse_query` (staging warehouse),
   `mcp__soria__pipeline_activity` (recent writes), and filesystem walks
   under `frontend/src/dives/` to understand what already exists.
2. Plan before building when the scope is not obvious.
   Be explicit about the target output: pipeline change, bronze table,
   dive, verify pass, or promotion.
3. Use MCP tools, not ad-hoc workarounds. The main surfaces are:
   - `mcp__soria__scraper_manage / scraper_run / scraper_upload_urls / scraper_confirm_uploads`
   - `mcp__soria__group_manage`, `schema_manage`, `schema_mappings`
   - `mcp__soria__detection_run`, `extraction_run`, `validation_run`
   - `mcp__soria__value_manage`, `derived_column_manage`
   - `mcp__soria__warehouse_query`, `warehouse_manage`, `warehouse_diff`, `warehouse_promote`
   - `mcp__soria__database_query`, `database_mutate`, `file_query`, `files_reprocess`
   - `mcp__soria__news_*`, `prompt_manage`, `pipeline_activity/history/cascade`
4. Verify with evidence.
   Show actual rows, counts, traces, or file state before claiming success.
5. Reversibility, not isolation. Writes hit shared state but soft-delete
   + the `PipelineEvent` audit trail make every write reversible.

## Dive work

For dive implementation, stick to the repo's file-based flow:

- dbt models under `frontend/src/dives/dbt/models/...`
  (staging / intermediate / marts — materialized as `main_staging`,
   `main_intermediate`, `main_marts` in MotherDuck)
- manifests under `frontend/src/dives/manifests/...`
- React components under `frontend/src/dives/...`
- registration in `frontend/src/pages/DivesPage.tsx`
- verify rows in `frontend/src/dives/dbt/seeds/verifications.csv`

Local `dbt run` writes to `soria_duckdb_staging`. Prod materialization
happens in CI on PR merge.

When the user wants UI proof, invoke `browse` instead of defaulting to the
slower Chrome-first browser tools.

## Guardrails

- No force-push. Rollback is `git revert` the PR (for warehouse / React) or
  `database_mutate` flipping `deleted_at` (for Postgres state).
- Promotion is PR + CI, never a command. `mcp__soria__warehouse_promote(pr=N)`
  posts the file-level manifest; CI executes on merge.
- Respect this repo's `AGENTS.md` completion rules if you end up committing:
  tests or validation, `git pull --rebase`, `git push`.
- Treat `direnv` and repo-local `.env` loading as the source of truth; do not
  tell the user to `source .env`.

## Routing hints

- Preflight: `/env` (MCP probe + dev-https cert + recent activity)
- Inventory and recon: `/status`
- Planning: `/plan`
- Ingestion path: `/ingest` (scrape → detect/extract/validate → mappings → publish)
- Value mapping: `/map` (or `/parent-map` for company rollup)
- Dive path: `/dive` (dbt + manifest + TSX + verifications + methodology)
- In-chat dive inspection: `/preview`
- Verification: `/verify`
- Diagnosis: `/diagnose`
- Ticketing: `/ticket`
- Browser QA: `/browse` or `/dashboard-review`
- Promotion: `/promote`
- Retrospective: `/lessons`

If a live page, screenshot, auth import, or UI repro is involved, switch to
`browse`.
