---
name: dev-env
version: 1.0.0
description: Use when entering a Soria app worktree, starting or repairing the local backend/frontend stack, preparing runtime tests, or needing an isolated branch dev environment with Neon and MotherDuck.
allowed-tools:
  - Read
  - Bash
---

# /dev-env

Engineering dev environments are for running Soria code against an isolated
branch backend/frontend. This is different from `/env`, which is the data/dive
preflight for MCP-first shared staging work.

Read the target repo's `AGENTS.md` and `CLAUDE.md` first. Repo-local rules win.

## What It Provisions

In `soria-2`, a branch dev environment gives the worktree:

- a Neon branch
- a MotherDuck clone
- a GCS prefix
- a local FastAPI/DBOS/FastMCP backend
- a local Vite frontend

It does not clone Turbopuffer. If the test touches chunks, search,
`chunk_delete`, `patch_for_file`, embeddings, or TP cleanup, use
`/seed-dev-tp` after the dev stack is running.

## Fast Path

From the worktree root:

```bash
git status --short --branch
soria env status 2>/dev/null || true
make run-dev
```

`make run-dev` is idempotent. It starts or restarts frontend and backend,
writes PIDs to `.dev/*.pid`, writes logs to `.dev/*.log`, auto-picks ports,
and rewrites `SERVER_URL`.

Report:

```text
Worktree: <pwd>
Branch:   <git branch>
Frontend: <frontend URL from make output/logs>
Backend:  <SERVER_URL from .env>
Logs:     make logs
```

## Create A Branch Environment

If the worktree has no dev environment:

```bash
soria env branch --from prod
```

This creates the git worktree, Neon branch, MotherDuck clone, `.env`, and
starts the stack. If shell setup did not cd into the new worktree, use the path
printed by the command.

Older `make setup-dev` flows may still exist in some branches. If the repo docs
say to use them, follow the repo docs and preserve per-worktree names:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD | tr '/' '-' | tr -cd 'a-zA-Z0-9-' | cut -c1-40)
NAME="dev-${BRANCH}"
NAME="$NAME" make setup-dev
make run-dev
```

## Repair Flow

Use this when the page does not load, MCP points at the wrong backend, or a
runtime test cannot connect:

```bash
pwd
git rev-parse --show-toplevel
soria env status 2>/dev/null || true
make stop-dev
make run-dev
make logs
```

Check `.env` for `SERVER_URL`. Use `lsof -i :<port> -P` only when logs do not
identify the owner.

## Turbopuffer Gap

Dev envs clone Postgres and MotherDuck, not TP namespaces. That means a dev DB
may contain file/chunk metadata copied from prod while the dev TP namespace is
empty.

Before runtime or E2E tests for search/chunk behavior:

```text
/dev-env -> make run-dev -> /seed-dev-tp -> /test
```

Do not claim search/chunk runtime proof until the target TP namespace contains
real rows and the test verified the mutation/search against that namespace.

## Teardown

Never run destructive teardown first. Use the repo's dry-run path when it
exists:

```bash
soria env teardown --dry-run
```

Show the dry-run result and ask before running teardown without `--dry-run`.

