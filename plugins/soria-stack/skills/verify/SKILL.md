---
name: verify
description: Prove Soria data is correct in Codex with evidence, not assertions. Use for warehouse checks, dive verification, extraction validation, verification-seed analysis, and any request to prove, validate, or spot-check data.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: verify/SKILL.md
  variant: codex
---

# Verify

Codex adaptation of the `Soria-Inc/soria-stack` `/verify` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- compare rendered / queried values against rows in the shared
  `verifications.csv` seed (filtered by `model` column)
- run `mcp__soria__warehouse_query` for each layer when tracing data through
  bronze → staging → intermediate → marts
- escalate from Tier 1 spot checks to Tier 2 sum checks to Tier 3 external
  benchmarks whenever the data supports it
- refresh the seed via local `dbt seed --select verifications`; query
  `soria_duckdb_staging.main.verifications` to confirm
- never claim success without showing concrete evidence
- route to `dashboard-review` if the user needs live UI proof
