# Codex Adapter

These wrappers mirror the canonical `Soria-Inc/soria-stack` Claude skill pack
for Codex.

## Core rules

- Stay MCP-first. The Soria platform is driven through the `soria` MCP server
  (`mcp__soria__*` tools — `scraper_run`, `detection_run`, `extraction_run`,
  `warehouse_query`, `warehouse_manage`, `database_query`, etc.). There is no
  `soria` CLI; any wrapper that looks like one is obsolete.
- Codex doesn't ship the Soria MCP by default. The user must configure it in
  their Codex client (HTTP endpoint at
  `https://<your-dbos>.cloud.dbos.dev/mcp/`) before these skills work. If a
  session lacks Soria MCP, say so and fall back to filesystem reads + git.
- If the upstream Claude skill mentions `AskUserQuestion`, use normal Codex
  commentary updates and, when necessary, a short direct user question.
- If the upstream Claude skill mentions browser QA, use the Codex `browse`
  skill first. It prefers the fast `$B` runtime and only falls back to
  Playwright MCP when needed.
- If the upstream Claude skill mentions `mcp__openclaw__mempalace_search`,
  use it when the connector is available. If not, say that the memory search
  connector is unavailable and continue with local evidence.
- If the upstream Claude skill mentions `mcp__linear__*`, use Linear only if
  the connector exists in the Codex session. Otherwise fall back to a GitHub
  issue, or produce a ticket draft for the user.
- Read the current repo's `AGENTS.md` before following write or landing
  workflows. Repo rules take precedence over generic skill text.
- Reversibility over isolation. There are no isolated dev environments.
  MCP writes hit shared Postgres + `soria_duckdb_staging`. Every write is
  soft-delete reversible via `deleted_at` + the `PipelineEvent` audit trail.
  Promotion to prod MotherDuck is PR-gated through `.github/workflows/
  promote.yml` and `dbt-deploy.yml`.

## Canonical source

When these wrappers are used inside the actual `Soria-Inc/soria-stack` repo,
the Claude `SKILL.md` files at the repo root remain the most detailed source of
truth (along with `ETHOS.md` and `MCP_TOOL_MAP.md`). The Codex wrappers exist
to make those workflows discoverable and usable inside Codex without assuming
Claude-specific tool names.
