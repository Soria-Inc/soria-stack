---
name: code-review
description: Use when reviewing Soria code, PRs, commits, or diffs for readiness, especially DBOS, MCP, API, database, scraper, extractor, observability, Turbopuffer, warehouse, frontend, or test-boundary changes.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: code-review/SKILL.md
  variant: codex
---

# Code Review

Codex adaptation of `Soria-Inc/soria-stack` `/code-review`.

Read `../../references/codex-adapter.md`, then read the target repo's
`AGENTS.md`, `CLAUDE.md`, and relevant `docs/engineering/*` pages.

Review Soria diffs against repo-specific implementation patterns:

- DBOS workflows, queues, dedupe, worker imports
- workflow/tool/API/schema boundaries
- MCP and FastAPI wrapper contracts
- database idempotency and races
- observability suppression
- scraper/extractor/pipeline contracts
- Turbopuffer/search safety
- whether `/test` evidence hit the risky boundary

Findings first. Then residual risks. Then verdict: ready, ready after fixes,
or not ready.

