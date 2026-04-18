---
name: dive
description: Build or revise a dive end-to-end in Codex: dbt marts SQL, manifest, TSX component, DivesPage registration, verification rows, and methodology content. Use for new dives, major dive refactors, or deep review of an existing dive.
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

- marts SQL under `frontend/src/dives/dbt/models/...`
- manifests under `frontend/src/dives/manifests/...`
- React components under `frontend/src/dives/...`
- DivesPage registration, verify rows, and methodology surfacing
- grain-first design, not just visual assembly

## Notes

- Use `browse` or `dashboard-review` for live UI proof after implementation.
- Use mempalace when available for domain definitions or prior design context.
