---
name: soria-stack
version: 4.0.0
description: |
  Data pipeline skills for Soria Analytics. IMPORTANT: Run /tools FIRST in every
  session before using any other soria-stack skill or calling any Soria MCP tool.
  The Soria MCP tools (sumo_*, news_*, mcp__sumo__*) are deferred at startup and
  will fail unless /tools has loaded them via ToolSearch.
  Fourteen skills: /tools (load MCP tools), /status (what exists today),
  /plan (ETVLR orchestrator), /ingest (scrape+extract+publish), /map (value mapping),
  /dashboard (grain-first SQL + data survey + SQL review + semantic checks),
  /verify (prove it — semantic checks foundation + pipeline/model/semantic verify),
  /smoke (adversarial browser QA), /diagnose (diagnose failures),
  /ticket (file structured tickets mid-session),
  /promote (push to prod), /preview (render dashboards in chat),
  /newsroom (news ops), /lessons (learn from what happened).
  Suggest the right skill by stage: starting a session → /tools; investigating what
  exists → /status; planning work → /plan; building a pipeline → /ingest;
  normalizing values → /map; profiling data or designing SQL models or reviewing SQL
  → /dashboard; proving data correct → /verify; testing live dashboard UI → /smoke;
  something broke → /diagnose; filing a ticket → /ticket; news pipeline → /newsroom;
  reviewing recent work → /lessons.
allowed-tools:
  - Read
  - Bash
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SoriaStack v3 loaded"
echo "---"
echo "Recent artifacts:"
ls -t ~/.soria-stack/artifacts/*.md 2>/dev/null | head -5 || echo "  (none)"
```

Read `ETHOS.md` before any data pipeline work. All principles apply.

# SoriaStack — Data Pipeline Skills

Ten cognitive modes for data pipeline work. Each sets how to think, when to stop,
and what to verify.

## Skill routing

| If the user is... | Suggest |
|-------------------|---------|
| Starting a new session | `/tools` (always first) |
| Asking "what do we have for X?" | `/status` |
| Saying "let's work on X" or "come up with a plan" | `/plan` |
| Ready to scrape, extract, or publish | `/ingest` |
| Normalizing values across eras | `/map` |
| Resolving company names to parent companies | `/parent-map` |
| Profiling data, building SQL models, or reviewing SQL | `/dashboard` |
| Checking if data is correct, proving it | `/verify` |
| Testing the live dashboard in a browser | `/smoke` |
| Wanting to see dashboard data in chat | `/preview` |
| Something broke or isn't working | `/diagnose` |
| Hit a bug, need to file a ticket | `/ticket` |
| Promoting to production | `/promote` (requires human approval) |
| Working with the news pipeline | `/newsroom` |
| Reviewing recent work for lessons | `/lessons` |

## The sequence

```
/tools (always first)
   ↓
/status → /plan → /ingest → /map → /dashboard → /verify → /promote
                          ↑
                   /parent-map (entity resolution — parallel to /map)
                                        ↑              ↑
                              (survey + SQL review     (semantic checks
                               built into /dashboard)   foundation of /verify)
   + /smoke (browser QA — after deploy)
   + /diagnose (when something breaks — can enter from any phase)
   + /ticket (file a ticket mid-session — can enter from any phase)
   + /promote (ONLY when human says "push to prod")
   + /preview (render dashboard data in chat)
   + /newsroom (separate domain)
   + /lessons (periodic)
```

Each skill produces an artifact that the next skill consumes.
Don't skip steps — every pipeline that went poorly started with the AI building
before looking.

## ETVLR Framework

Every data concept follows this lifecycle:

```
E (Extract)   → /ingest Gate 1: scrape files
T (Transform) → /ingest Gates 2-4: group, schema, extract
V (Value Map) → /map: normalize values to canonicals
L (Load)      → /ingest Gate 5: publish to warehouse
R (Represent) → /dashboard: bronze → silver → gold → platinum SQL
```

/plan orchestrates these phases. /verify runs after each.

## Workspace resolution

Write-path skills (`/ingest`, `/map`, `/dashboard`, `/promote`) require a workspace.
Before any write operation, resolve which workspace you're working in:

1. **User named one** — use it.
2. **Obvious from context** (just created, only one active, continuing prior work) — use it.
3. **Multiple active workspaces exist** — list them and ask:
   ```
   workspace_manage(operation="list")
   ```
   Then: "I see these active workspaces: [list]. Which one should I work in?"
4. **None exist** — offer to create one (`/ingest`, `/map`, `/dashboard`), or error (`/promote` — nothing to promote).

Read-only skills (`/status`, `/verify`, `/plan`, `/newsroom`, `/lessons`) don't need
a workspace — they query across all schemas.

## Quick reference

- **Principles** in `ETHOS.md` — the source of truth
- **Artifacts** in `~/.soria-stack/artifacts/` — state passed between skills
- **Gates** in every skill — hard stops where the human must review
- **Completion status** — every skill ends with DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT
