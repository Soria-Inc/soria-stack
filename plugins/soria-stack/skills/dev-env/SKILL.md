---
name: dev-env
description: Use when entering a Soria app worktree, starting or repairing the local backend/frontend stack, preparing runtime tests, or needing an isolated branch dev environment.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: dev-env/SKILL.md
  variant: codex
---

# Dev Env

Codex adaptation of `Soria-Inc/soria-stack` `/dev-env`.

Read `../../references/codex-adapter.md`, then read the target repo's
`AGENTS.md` and `CLAUDE.md`.

Use the canonical top-level skill logic:

- start or repair the Soria branch dev stack
- report frontend/backend URLs and logs
- distinguish branch dev envs from data/dive `/env`
- explain that Postgres and MotherDuck are cloned but Turbopuffer is not
- route chunk/search/delete runtime tests to the app repo helper
  `scripts/seed-dev-tp.py` when real dev TP rows are needed
