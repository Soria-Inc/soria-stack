---
name: diagnose
description: Diagnose and fix broken Soria workflows in Codex. Use for silent failures, missing data, dive load failures, schema mismatches, infrastructure issues, or pipeline behavior that looks wrong and needs triage before guessing.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: diagnose/SKILL.md
  variant: codex
---

# Diagnose

Codex adaptation of the `Soria-Inc/soria-stack` `/diagnose` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- triage first, observe before hypothesizing
- inspect logs, state, schemas, queries, and UI evidence
- use mempalace when available for prior failures or known patterns
- either fix inline or hand off to `ticket` with a structured disposition
