---
name: tools
version: 1.0.0
description: |
  Tool discovery and retrieval-led reasoning for the Soria MCP. Forces the agent
  to search for tools before calling them, read descriptions and parameters,
  and consult the matching ref file for the cognitive frame.
  Use as a preamble to any data pipeline work. Other skills invoke this pattern
  implicitly, but /tools can be called standalone when exploring what's available,
  troubleshooting a tool call, or learning the MCP surface area.
  Trigger phrases: "what tools do we have", "how do I do X", "search for tools",
  "what MCP tools exist for Y", or any time the agent is unsure which tool to call.
allowed-tools:
  - sumo_*
  - Read
  - Bash
---

# /tools — "Search before you call"

You are in tool discovery mode. The Soria MCP has dozens of tools across multiple
domains. You do NOT have them memorized. You do NOT guess at parameters.
You search, read, then call.

This is retrieval-led reasoning applied to tool usage.

---

## The Rule

**Before calling ANY MCP tool:**

1. **Search** — Find the tool and confirm it exists
2. **Read** — Check the tool's parameters, types, and required fields
3. **Ref** — If a ref file exists for this domain, read it for the cognitive frame

Never call a tool from memory. Tool signatures change. Parameters get added.
Defaults shift. The 30 seconds you spend searching saves the 5 minutes you'd
spend debugging a bad call.

---

## Step 1: Search

Use `sumo_tool_search` to find tools by keyword:

```
sumo_tool_search({ query: "scraper" })
→ scraper_manage, scraper_run, derived_column_manage

sumo_tool_search({ query: "extract" })
→ extractor_manage, extraction_run, detection_run, validation_run

sumo_tool_search({ query: "warehouse" })
→ warehouse_manage, database_query

sumo_tool_search({ query: "schema" })
→ schema_manage, schema_mappings
```

If you're not sure what to search for, start broad:
```
sumo_tool_search({ query: "file" })
sumo_tool_search({ query: "group" })
sumo_tool_search({ query: "model" })
sumo_tool_search({ query: "news" })
```

## Step 2: Read the Tool

Once you've found the tool, read its full description and parameter schema.
The search result includes:
- Tool name
- Description (what it does, when to use it)
- Parameters with types and required/optional flags
- Example calls (if provided)

**Pay attention to:**
- Required vs optional parameters
- Parameter types (string, number, boolean, JSON object)
- Enum values (e.g., `action: "read" | "create" | "update" | "delete"`)
- Default values that might not be what you expect

## Step 3: Check the Ref File

The ref file adds the cognitive frame — not just *how* to call the tool, but *when*
and *why* and *what to watch out for*.

```
Tool domain         →  Ref file
─────────────────────────────────────────
scraper_*           →  ref/data/scraper.md
group_*, file_*     →  ref/data/organize.md
extractor_*         →  ref/data/simple-extraction.md
detection/extract   →  ref/data/ai-pipeline.md
warehouse_*, value_ →  ref/data/publish.md
sql_model_*         →  ref/data/sql-models.md
news_*              →  ref/data/news-mcp-tools.md
database_query      →  (universal — used everywhere)
```

The ref file tells you:
- The workflow sequence (which tool comes before/after)
- Gotchas and known issues (e.g., `update_columns` deletes columns not in the list)
- Checkpoints where you should pause for human review
- Common failure modes and troubleshooting

---

## Quick Reference: Universal Gotchas

These are the mistakes that burn time. Know them.

| Gotcha | Details |
|--------|---------|
| `file_name` not `filename` | Column name in the database. Wrong casing = empty results. |
| No `date` column | Use `file_metadata->>'date'` for date-based queries. |
| `file_query` = exact match | For fuzzy search, use `database_query` with `ILIKE`. |
| `scraper_manage` can't list all | Use `database_query` with SQL to list scrapers. |
| `group_manage(read)` needs `group_id` | Can't list all groups — use SQL: `SELECT id, name FROM groups WHERE scraper_id = '...'` |
| `update_columns` is destructive | Deletes columns not in the list. Cascades to mappings. Always include ALL columns. |
| `value_manage` index/embed are standalone | Can't combine with read or mutations in the same call. |
| Async ops need polling | detection/extraction/validation are async — poll `database_query` before proceeding. |
| `workspace_id` required | Without it you see only the public schema. Always pass it for workspace queries. |
| Stale UUIDs | IDs from memory/context may be stale. Re-read from DB before using. |

---

## Standalone Mode

When invoked as `/tools` directly (not as part of another skill):

1. **Ask what the user is trying to do** — "What are you trying to accomplish?"
2. **Search for relevant tools** — Run `sumo_tool_search` with keywords from their answer
3. **Present a map** — Show which tools exist, what they do, and which ref file to read
4. **Demonstrate** — Show an example call with correct parameters

If the user is exploring ("what can the MCP do?"), give them the domain overview:

```
SORIA MCP — Tool Domains
═══════════════════════════════════════

Scrapers     scraper_manage, scraper_run, derived_column_manage
             → Download files from government/corporate sources

Organize     group_manage, schema_manage, schema_mappings, file_query
             → Group files, define target schemas, map columns

Extract      extractor_manage, extraction_run (simple)
             detection_run, extraction_run, validation_run (AI/PDF)
             prompt_manage
             → Turn raw files into structured data

Publish      value_manage, warehouse_manage
             → Normalize values, publish to DuckDB/MotherDuck

Model        sql_model_*, sqlmesh_plan, sqlmesh_apply
             get_lineage, get_model_sql, run_sqlmesh_audits
             → Bronze/silver/gold/platinum SQL models

Query        database_query, database_mutate
             → Direct SQL on Postgres (Sumo metadata) or DuckDB (warehouse)

News         news_articles, news_events, news_pipeline, news_branches
             → News intelligence pipeline

Search first. Read second. Call third.
```

---

## For Other Skills

Other skills don't need to invoke `/tools` explicitly. Instead, they follow the
same pattern in their preamble:

> Before calling any MCP tool, confirm it exists and check its parameters.
> Don't call tools from memory — signatures change.

The ref file for each domain provides the tool-specific guidance. `/tools` exists
for when the agent needs to explore beyond a single domain, or when the user is
learning the system.
