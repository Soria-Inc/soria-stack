---
name: ingest
description: Build and run Soria ingestion pipelines in Codex. Use for scraping, grouping, schema work, extraction, validation, value mapping handoff, refresh runs, and publishing through the `soria` CLI rather than Soria MCP.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: ingest/SKILL.md
  variant: codex
---

# Ingest

Codex adaptation of the `Soria-Inc/soria-stack` `/ingest` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- scraper -> groups/schema -> detect/extract -> validate -> publish
- exact `soria scraper`, `soria detect`, `soria extract`, `soria validate`,
  `soria schema`, and `soria warehouse` commands
- human review gates at each major step
- browser inspection only when it materially helps the scrape or extract path
