# SoriaStack — Agent Instructions

This file exists for agents (Claude Code, Clawd, etc.) that look for an
`AGENTS.md` by convention. The content lives in `README.md` — read that.

## Key rules for agents

1. **Start data/pipeline sessions with `/tools`.** No data skill should run
   until the `soria` MCP is confirmed reachable and the local dev stack is
   installed. For branch-local app engineering, route first to `/dev-env`,
   `/test`, or `/code-review` based on the task.
2. **MCP-first for platform data work.** The Soria platform is driven through the
   `mcp__soria__*` tool namespace — `scraper_run`, `detection_run`,
   `extraction_run`, `validation_run`, `warehouse_query`, `warehouse_manage`,
   `schema_manage`, `value_manage`, `database_query`, `database_mutate`,
   `news_*`, etc. There is no `soria` CLI fallback for pipeline operations.
   Branch-local engineering dev environments may use app repo `soria env`
   commands when that repo documents them. `mcp__linear__*` is owned by
   `/ticket`; `mcp__openclaw__mempalace_search` is used for domain grounding
   and prior-session search across several skills.
3. **Git-native authoring for dives.** dbt SQL, manifests, dive TSX all
   live as files in `frontend/src/dives/`. Edit locally, commit in logical
   chunks, push a PR. Promotion runs in CI, not a command.
4. **Reversibility over isolation.** There are no isolated environments.
   MCP writes hit shared Postgres + `soria_duckdb_staging`. Every write is
   soft-delete reversible via `deleted_at` + the `PipelineEvent` audit
   trail. Skills should prefer undoing over asking permission for reversible
   changes — but still surface what was changed so the user can audit.
5. **Read `ETHOS.md`** before any data pipeline work. All numbered
   principles apply.
6. **Engineering skills are first-class.** Use `/dev-env` for branch-local
   app environments, `/test` for proof selection and E2E testing,
   `/code-review` for Soria-specific code review, and `/seed-dev-tp` when
   Turbopuffer-backed runtime tests need real chunks in a dev namespace.
7. **Lessons close the loop.** Repeated test/review/dev-env discoveries
   belong back in this repo's skills; current codebase invariants belong in
   the app repo's `docs/engineering/*`.

## Skill index

See `README.md` for the full skill list and architecture diagram. Skills
live in their own directories — invoke by name (e.g., `/status`).
