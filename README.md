# SoriaStack — Data Pipeline Skills

SoriaStack is a collection of SKILL.md files that give AI agents structured
roles for data pipeline work at Soria Analytics. Seventeen skills covering the
full ETVLR cycle: Extract → Transform → Value-map → Load → Represent.

All skills drive the Soria platform through the **`soria` MCP server** (the
`mcp__soria__*` tool namespace). There is no `soria` CLI — every pipeline
verb is an MCP tool. SQL and React dives are authored locally in git.

## Architecture

```
                  ┌───────────────────────────────────────────┐
                  │  mcp__soria__* tools (one shared MCP)     │
                  │  scraper_run · detection_run · extraction │
                  │  validation · schema_manage · value_manage│
                  │  warehouse_manage · warehouse_query       │
                  └──────────────────┬────────────────────────┘
                                     ▼
        ┌───────────────────────┬───────────────────────────┐
        │  shared Postgres      │  soria_duckdb_staging     │
        │  (scrapers/groups/    │  (bronze + dbt staging/   │
        │   files/schemas)      │   intermediate/marts)     │
        └───────────────────────┴───────────────────────────┘
                                     ▲
                                     │ local dbt run
                      ┌──────────────┴───────────────┐
                      │  frontend/src/dives/dbt/     │  ← git
                      │  (staging → intermediate →   │
                      │   marts, verifications seed) │
                      └──────────────┬───────────────┘
                                     │ make dev-https
                                     ▼
                    https://dev.soriaanalytics.com
                    (local vite → prod DBOS API + Clerk,
                     DuckDB-WASM + Postgres wire proxy,
                     MethodologyModal + VerifyModal,
                     staging/prod badge ⟷ X-SQLMESH-ENV)
                                     │
                          git push → gh pr create
                                     ▼
                        CI: dbt-deploy.yml (marts → prod)
                            promote.yml  (bronze files → prod)
                                     ▼
                          soria_duckdb_main (prod)
```

Every MCP write to Postgres is **soft-delete reversible** via `deleted_at` /
`deleted_by` columns and a `PipelineEvent` audit trail. There are no hard
deletes. To undo, flip `deleted_at` through `mcp__soria__database_mutate`
(see `/diagnose` for the pattern).

**The staging/prod badge** in the app chrome (`EnvironmentBadge`) is the
dev iteration surface. Amber "staging" routes dive queries to
`soria_duckdb_staging` (where your local `dbt run` just landed); green
"prod" routes to `soria_duckdb_main` (customer-facing). Default is prod;
customer view locks to prod. Plumbed via the `X-SQLMESH-ENV` header
(legacy name — SQLMesh itself is retired).

Classic backend-rendered dashboards (AG-Grid + `@dashboard` YAML) are gone.
The backend is a thin FastAPI shell: auth, scraper management, news, file
processing. Dive data flows from MotherDuck to the browser.

## Available skills

Skills live in their own directories. Invoke them by name (e.g., `/status`).

| Skill | What it does |
|-------|-------------|
| `/browse` | Persistent headless Chromium (`$B`) for dive verification, bug repro, scraper recon. Vendored from gstack (MIT). `/dashboard-review` calls this under the hood. |
| `/env` | Sanity-check the dev stack — MCP reachable, `make dev-https` cert present, prod URL responding. There are no isolated envs; this skill is a preflight, not a provisioner. |
| `/tools` | Verify the `mcp__soria__*` tools load and the local dev stack (uv, node, dbt, make, git) is installed. |
| `/status` | Investigate what exists for a concept — pipeline inventory via `mcp__soria__database_query` + `mcp__soria__warehouse_query` + dive filesystem walk. |
| `/plan` | ETVLR orchestrator — break work into phases, plan verification upfront. |
| `/ingest` | Scrape, organize, extract, validate, and publish through five hard-stop gates. |
| `/map` | Value mapping — normalize raw values to canonical forms across eras. |
| `/parent-map` | Resolve company names/codes to ultimate parent companies via parallel.ai. One centralized table, all data sources. |
| `/dive` | Build a dive end-to-end: dbt marts SQL + manifest + TSX component + `DivesPage.tsx` registration + rows in the shared `verifications.csv` seed + methodology content wired into the component. Grain-first thinking, domain grounding, SQL review checklist. |
| `/preview` | Render a dive as markdown tables in chat — read the manifest, build SQL, query MotherDuck via MCP, format as a pivot. |
| `/verify` | Prove data is correct. Pipeline verify, Model verify, Semantic verify — three tiers of evidence per mode. |
| `/dashboard-review` | Ship-readiness review for a dive. Runs six gates end-to-end via `/browse` against `https://dev.soriaanalytics.com`: render, data correctness (seed + warehouse cross-ref), interactivity, methodology/verify modals, edge cases, perf. Aggregates into one report; hands off to `/ticket` or `/diagnose` on failure. |
| `/diagnose` | Triage-first failure investigation: silent failures, data traces, schema mismatches, infrastructure, quality. Invokes `/ticket` when ticketing is needed. |
| `/ticket` | File a structured Linear ticket mid-session. Owns all Linear writes. Scans for duplicates and active interactive-agent runs before filing. Side-quest — returns the user to their previous skill. |
| `/promote` | Safe path to production. `mcp__soria__warehouse_diff` → `mcp__soria__warehouse_promote` (posts PR manifest) → `git push` → `gh pr create` → CI (`dbt-deploy.yml` + `promote.yml`) materializes to prod MotherDuck on merge. |
| `/newsroom` | News pipeline ops — branch management, prompt tuning, source review. Driven by `mcp__soria__news_*`. |
| `/lessons` | Retrospective — review recent work, find patterns, propose principle updates. |

## Principles

Read `ETHOS.md` before any data pipeline work. Includes:

- Numbered data principles extracted from real sessions
- Resolver pattern (context efficiency)
- Completion & escalation protocol
- Anti-sycophancy & simplicity guidance
- MCP-first tool invocation
- PR-gated promotion semantics
- Dual-mode loading invariant for dives
- Methodology-per-element as "done"

See `MCP_TOOL_MAP.md` for the concise mapping of every `mcp__soria__*` tool
the skills call, grouped by domain.

## Installation

This skill pack assumes the `soria` MCP server is already configured in
Claude Code (`~/.claude.json` → `mcpServers.soria`, typically an HTTP
endpoint at `https://<your-dbos>.cloud.dbos.dev/mcp/`). No CLI to install.

Clone this repo and run the installer:

```bash
git clone https://github.com/Soria-Inc/soria-stack ~/.claude/skills/soria-stack
cd ~/.claude/skills/soria-stack
./install.sh
```

The installer creates symlinks like `~/.claude/skills/ingest -> soria-stack/ingest`
for every skill. It's idempotent — rerun any time after `git pull` to pick
up new skills, remove stale symlinks, or repoint moved targets.

Verify in a fresh Claude Code session:

```
/tools    # verify MCP + local stack
/status   # pipeline recon
```

## Keeping the pack up to date

```bash
cd ~/.claude/skills/soria-stack
git pull
./install.sh   # propagate any new/removed skills
```

Most updates propagate automatically because top-level symlinks point into
the pack — `git pull` rewrites the content the symlinks resolve to.
Re-running `install.sh` is only strictly necessary when skills are added or
removed, but running it every time is cheap and safe.

## Skill chaining (ETVLR)

```
/tools (verify MCP + local dev stack)
   ↓
/status → status report (what exists, what's missing)
   ↓
/plan → ETVLR plan (phases, verification criteria, sequencing)
   ↓
/ingest → ingest report (files, schema, extraction results, bronze tables)
   ↓
/map → mapping report (canonical values, decisions made)
   ↓
/dive → dive spec (grain, dbt model, manifest, TSX, modals, semantic checks)
   ↓
/verify → scorecard (semantic check results, tier evidence, confidence)
   ↓
/promote → promotion report (PR URL, CI status, canary results)
   ↓
/lessons → retro report (patterns, principle updates) [periodic]

   + /dashboard-review (browser QA via make dev-https)
   + /preview (render a dive in chat — any time)
   + /diagnose (enters from any phase when something breaks)
```

Artifacts saved to `~/.soria-stack/artifacts/`. Each skill reads prior
artifacts and writes its own. Every artifact includes completion status and
lessons learned.
