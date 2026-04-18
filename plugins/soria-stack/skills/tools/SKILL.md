---
name: tools
description: Verify the Soria MCP and local dev stack are ready in Codex. Use at the start of a Soria session or whenever the workflow is blocked by missing MCP config, missing local tools (uv, node, dbt, make, git, gh), or a broken dev-https cert.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: tools/SKILL.md
  variant: codex
---

# Tools

Codex adaptation of the `Soria-Inc/soria-stack` `/tools` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- probe `mcp__soria__database_query "SELECT 1"` to confirm MCP reachability
- verify local tools: `uv`, `node`, `dbt`, `make`, `git`, `gh`
- confirm `dbt debug` passes against `soria_duckdb_staging`
- confirm the `dev-https` cert exists (`frontend/dev.soriaanalytics.com.pem`)
- route the user into `status`, `plan`, `ingest`, or `dive` once the shell is ready

## Notes

- There is no `soria` CLI anymore. If you reach for one, stop and fix the
  MCP config instead.
