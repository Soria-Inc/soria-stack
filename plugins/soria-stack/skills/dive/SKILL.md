---
name: dive
description: Build or revise a dive end-to-end in Codex — dbt marts SQL, manifest, TSX component, DivesPage registration, verification rows, and methodology content. Use for new dives, major dive refactors, or deep review of an existing dive.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: dive/SKILL.md
  variant: codex
---

# Dive

Codex adaptation of the `Soria-Inc/soria-stack` `/dive` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- dbt marts SQL under `frontend/src/dives/dbt/models/marts/...`
  (layers: staging → intermediate → marts; no upstream SQLMesh)
- manifests under `frontend/src/dives/manifests/...`
- React components under `frontend/src/dives/...`
- DivesPage registration, rows in the shared `verifications.csv` seed,
  methodology content wired into the component
- grain-first design, not just visual assembly
- data survey via `mcp__soria__warehouse_query` before writing SQL

## Notes

- Local `dbt run` writes to `soria_duckdb_staging`. Prod target is absent
  from committed `profiles.yml`; CI injects it on PR merge.
- Use `preview` for in-chat output or `dashboard-review` for live UI proof
  after implementation.
- Use mempalace when available for domain definitions or prior design context.
