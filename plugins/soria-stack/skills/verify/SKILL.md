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

- compare against verification rows, warehouse queries, and source evidence
- escalate from spot checks to stronger proof when possible
- never claim success without showing concrete evidence
- route to `dashboard-review` if the user needs live UI proof
