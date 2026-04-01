---
name: tools
version: 1.0.0
description: |
  Load the Soria data platform MCP tools into the session. You MUST run /tools
  before calling ANY Sumo MCP tool (sumo_*, news_*, scrape_*, extract_*,
  schema_*, warehouse_*, dashboard_*, value_*) for the first time in a session.
  Without /tools, these MCP tools are deferred and cannot be invoked.
  Proactively run this — do not wait for the user to ask. If the user asks you
  to do anything involving the Soria data platform, pipelines, scrapers,
  schemas, extractions, dashboards, or warehouse, run /tools immediately before
  attempting any MCP tool calls. This is a hard prerequisite, not a suggestion.
allowed-tools:
  - ToolSearch
---

# /tools — Load Soria Platform Tools

You are loading the MCP tools needed to work on Soria's data stack.

**Run these ToolSearch calls to discover all available platform tools:**

```
ToolSearch: "sumo" (max_results: 20)
ToolSearch: "news" (max_results: 10)
ToolSearch: "scrape" (max_results: 10)
ToolSearch: "schema" (max_results: 10)
ToolSearch: "extract" (max_results: 10)
ToolSearch: "warehouse" (max_results: 10)
ToolSearch: "dashboard" (max_results: 10)
ToolSearch: "value" (max_results: 10)
```

Run all 8 searches in parallel. After results come back, print a summary:

```
Soria Platform Tools Loaded
---
Sumo tools:      [count]
News tools:      [count]
Scrape tools:    [count]
Schema tools:    [count]
Extract tools:   [count]
Warehouse tools: [count]
Dashboard tools: [count]
Value tools:     [count]
---
Total: [count] tools ready
```

Then say: "Tools loaded. Ready for /scout, /ingest, /profile, /model, /verify, or /newsroom."
