---
name: promote
description: Safe path to production for Codex. Use when the user wants to land Soria work through git and CI, after reviewing `soria env diff`, passing verification, and completing browser QA for customer-facing dive changes.
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

- pre-flight checks before landing
- `soria env diff` review
- git + PR + CI orchestration rather than a fake `soria promote` command
- final browser QA via `dashboard-review` when the change is user-facing

## Notes

- Follow the repo's `AGENTS.md` landing rules if you are actually committing.
- Use `ticket` instead of burying open concerns in the promotion flow.
