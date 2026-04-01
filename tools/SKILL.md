---
name: tools
version: 1.0.0
description: |
  Load the Soria data platform tools. Run this FIRST before any data pipeline
  work — /scout, /ingest, /profile, /model, /verify, /newsroom all depend on
  MCP tools that must be discovered before use. Searches for all available
  Sumo, news, and pipeline tools via ToolSearch.
  Proactively suggest when the user starts any data work and tools haven't been
  loaded yet. Required before calling any sumo_*, news_*, or pipeline MCP tools.
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
