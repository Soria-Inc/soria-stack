---
name: env
description: Preflight the Soria dev stack in Codex. Use when the user asks what they're pointed at or whether their local setup is working. There are no isolated envs anymore — MCP writes land on shared state with soft-delete safety.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: env/SKILL.md
  variant: codex
---

# Env

Codex adaptation of the `Soria-Inc/soria-stack` `/env` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- probe `mcp__soria__database_query "SELECT 1"` to confirm MCP reachability
- check `make dev-https` cert presence (`frontend/dev.soriaanalytics.com.pem`)
- report recent writes via `mcp__soria__pipeline_activity`
- surface uncommitted / unpushed work — shared state doesn't forgive WIP

## Notes

- If the MCP probe fails, the user must configure `soria` MCP in their Codex
  client (HTTP endpoint) and restart.
- There is no `soria env branch/checkout/status/diff/teardown/restore` — the
  CLI is gone. `git checkout` + `make dev-https` is the local flow.
- **Vite liveness:** `curl -sk -o /dev/null -w "%{http_code}\n"
  https://dev.soriaanalytics.com/` — if 000, `make dev-https` runs in the
  foreground and died with its shell. Restart detached:
  `cd frontend && nohup npx vite --port 5189 > /tmp/soria-vite.log 2>&1 & disown`.
- **Staging/prod badge:** default is prod; toggle to staging to see your
  local `dbt run` output. Customer view locks to prod.
