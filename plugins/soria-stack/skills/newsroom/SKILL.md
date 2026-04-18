---
name: newsroom
description: News pipeline operations in Codex. Use for news branch management, prompt tuning, source review, event review, and newsletter workflow. Driven through `mcp__soria__news_*` plus `mcp__soria__database_query` / `prompt_manage`.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: newsroom/SKILL.md
  variant: codex
---

# Newsroom

Codex adaptation of the `Soria-Inc/soria-stack` `/newsroom` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- `mcp__soria__news_branches` (list/clone/update) — test prompts on a clone
  first, never the active branch
- `mcp__soria__news_pipeline` for step-level runs
- `mcp__soria__news_articles` / `news_events` for inspection
- `mcp__soria__prompt_manage` for prompt CRUD
- source/event/article health checks via `mcp__soria__database_query`
- explicit operator judgment for editorial or review steps
- newsletter sends need explicit human approval; verify the dev audience
  guard (`is_dev = true`) before testing
