---
name: tools
version: 1.0.0
description: |
  Load the Soria data platform MCP tools into the session. The Soria MCP server
  provides all tools for working with Soria's data — scrapers, schemas,
  extractions, value maps, warehouse publishing, SQL models, dashboards, and
  news intelligence. These tools are DEFERRED at session start, meaning they
  exist but have no schema loaded and CANNOT be called until discovered via
  ToolSearch. Run /tools at the START of every session before doing ANY work
  with the Soria platform. This is not just for skills — any direct MCP tool
  call (sumo_*, news_*, mcp__sumo__*) will fail without running /tools first.
  If you see a Soria MCP tool name in the deferred tools list, that means
  /tools has not been run yet. Run it immediately, do not ask the user.
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
