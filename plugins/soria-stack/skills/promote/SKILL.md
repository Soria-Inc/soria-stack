---
name: promote
description: Safe path to production in Codex. Use when the user wants to land Soria work through git + CI, after `mcp__soria__warehouse_diff`, `mcp__soria__warehouse_promote` posts the PR manifest, verification passes, and dashboard QA is clean for customer-facing dive changes.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: promote/SKILL.md
  variant: codex
---

# Promote

Codex adaptation of the `Soria-Inc/soria-stack` `/promote` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- pre-flight: clean git tree, recent `/verify` artifact, recent
  `/dashboard-review` artifact, `dbt test` passes, methodology + verify
  coverage present
- `mcp__soria__warehouse_diff` to surface bronze file-level changes vs prod
- `git push`, `gh pr create`, then `mcp__soria__warehouse_promote(pr=N)` to
  post the `<!-- soria-promotion-manifest -->` comment that CI reads
- CI executes on merge: `.github/workflows/dbt-deploy.yml` materializes
  marts into `soria_duckdb_main`; `.github/workflows/promote.yml` copies
  bronze `_file_id` rows from staging to prod
- final browser QA via `dashboard-review` against
  `https://soriaanalytics.com` after merge

## Notes

- Rollback is `git revert` the PR (for marts/bronze) or `database_mutate`
  flipping `deleted_at` (for Postgres state). No force-push.
- Follow the repo's `AGENTS.md` landing rules if you are actually committing.
- Use `ticket` instead of burying open concerns in the promotion flow.
