---
name: soria-stack
version: 3.0.0
description: |
  Data pipeline skills for Soria Analytics. IMPORTANT: Run /tools FIRST in every
  session before using any other soria-stack skill or calling any Soria MCP tool.
  The Soria MCP tools (sumo_*, news_*, mcp__sumo__*) are deferred at startup and
  will fail unless /tools has loaded them via ToolSearch.
  Nine cognitive modes: /tools (load MCP tools), /status (what exists today),
  /plan (ETVLR orchestrator), /ingest (scrape+extract+publish), /map (value mapping),
  /model (grain-first SQL), /verify (prove it with evidence), /newsroom (news ops),
  /retro (learn from what happened).
  Suggest the right skill by stage: starting a session → /tools; investigating what
  exists → /status; planning work → /plan; building a pipeline → /ingest;
  normalizing values → /map; designing SQL models → /model; verifying data or
  reviewing SQL or profiling data quality → /verify; news pipeline → /newsroom;
  reviewing recent work → /retro.
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

Nine cognitive modes for data pipeline work. Each sets how to think, when to stop,
and what to verify.

## Skill routing

| If the user is... | Suggest |
|-------------------|---------|
| Starting a new session | `/tools` (always first) |
| Asking "what do we have for X?" | `/status` |
| Saying "let's work on X" or "come up with a plan" | `/plan` |
| Ready to scrape, extract, or publish | `/ingest` |
| Normalizing values across eras | `/map` |
| Building SQL models or dashboards | `/model` |
| Checking if data is correct | `/verify` (Modes 1-3) |
| Reviewing SQL quality | `/verify` (Mode 4) |
| Profiling data before writing SQL | `/verify` (Mode 5) |
| Working with the news pipeline | `/newsroom` |
| Reviewing recent work for lessons | `/retro` |

## The sequence

```
/tools (always first)
   ↓
/status → /plan → /ingest → /map → /model → /verify
                                                ↑
                                     (verify runs after any phase)
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
R (Represent) → /model: bronze → silver → gold → platinum SQL
```

/plan orchestrates these phases. /verify runs after each.

## Quick reference

- **Principles** in `ETHOS.md` — the source of truth
- **Artifacts** in `~/.soria-stack/artifacts/` — state passed between skills
- **Gates** in every skill — hard stops where the human must review
- **Completion status** — every skill ends with DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT
