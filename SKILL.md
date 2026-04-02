---
name: soria-stack
version: 3.0.0
description: |
  Data pipeline skills for Soria Analytics. IMPORTANT: Run /tools FIRST in every
  session before using any other soria-stack skill or calling any Soria MCP tool.
  The Soria MCP tools (sumo_*, news_*, mcp__sumo__*) are deferred at startup and
  will fail unless /tools has loaded them via ToolSearch.
  Ten cognitive modes: /tools (load MCP tools), /status (what exists today),
  /plan (ETVLR orchestrator), /ingest (scrape+extract+publish), /map (value mapping),
  /dashboard (grain-first SQL), /verify (prove it with evidence), /diagnose (diagnose failures),
  /newsroom (news ops), /retro (learn from what happened).
  Suggest the right skill by stage: starting a session → /tools; investigating what
  exists → /status; planning work → /plan; building a pipeline → /ingest;
  normalizing values → /map; designing SQL models → /dashboard; verifying data or
  reviewing SQL or profiling data quality → /verify; something broke or isn't working
  → /diagnose; news pipeline → /newsroom; reviewing recent work → /retro.
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
| Building SQL models or dashboards | `/dashboard` |
| Checking if data is correct | `/verify` (Modes 1-3) |
| Reviewing SQL quality | `/verify` (Mode 4) |
| Profiling data before writing SQL | `/verify` (Mode 5) |
| Something broke or isn't working | `/diagnose` |
| Promoting to production | `/promote` (requires human approval) |
| Working with the news pipeline | `/newsroom` |
| Reviewing recent work for lessons | `/retro` |

## The sequence

```
/tools (always first)
   ↓
/status → /plan → /ingest → /map → /dashboard → /verify → /promote
                                                ↑
                                     (verify runs after any phase)
   + /diagnose (when something breaks — can enter from any phase)
   + /promote (ONLY when human says "push to prod")
   + /newsroom (separate domain)
   + /retro (periodic)
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

Read-only skills (`/status`, `/verify`, `/plan`, `/newsroom`, `/retro`) don't need
a workspace — they query across all schemas.

## Quick reference

- **Principles** in `ETHOS.md` — the source of truth
- **Artifacts** in `~/.soria-stack/artifacts/` — state passed between skills
- **Gates** in every skill — hard stops where the human must review
- **Completion status** — every skill ends with DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT
