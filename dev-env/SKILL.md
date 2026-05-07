---
name: dev-env
version: 1.2.0
description: Use when entering a Soria app worktree, starting or repairing the local backend/frontend stack, preparing runtime tests, or needing an isolated branch dev environment with Neon and MotherDuck.
allowed-tools:
  - Read
  - Bash
---

# /dev-env

Engineering dev environments are for running Soria code against an isolated
branch backend/frontend. This is different from `/env`, which is the data/dive
preflight for MCP-first shared staging work.

Read the target repo's `AGENTS.md` first (in shifted-left repos `CLAUDE.md`
is a symlink to it). When `docs/cross-cutting/dev-env.md` exists, it's the
canonical dev-env reference for that codebase — read it before assuming
Soria conventions apply. Repo-local rules always win.

## What It Provisions

In `soria-2`, a branch dev environment gives the worktree:

- a Neon branch
- a MotherDuck clone
- a GCS prefix
- a local FastAPI/DBOS/FastMCP backend
- a local Vite frontend

It does not clone Turbopuffer. If the test touches chunks, search,
`chunk_delete`, `patch_for_file`, embeddings, or TP cleanup, the relevant test
flow may need the app repo helper script `scripts/seed-dev-tp.py` after the dev
stack is running.

## Preflight — what's running on this machine

Before spinning up another dev stack, check what's already there. Port collisions, sibling worktrees with `make run-dev` going, MotherDuck clones bound to other envs — `make run-dev` will pick free ports automatically, but knowing what's running lets you decide whether to kill the other stack first or co-exist on different ports.

```bash
bash ~/.claude/skills/soria-stack/scripts/dev-env-preflight.sh
```

The script is read-only — it never kills processes or deletes anything, just reports. Output:

- **Ports in use** across the Soria range (5173-5180 / 8900-8910) with the command + cwd that owns each
- **Sibling worktrees** with running `make run-dev` (frontend.pid + backend.pid + branch + DB they're using)
- **MotherDuck clone bindings** across all worktrees of the current repo, plus a duplicate-detection warning if two worktrees point at the same `MOTHERDUCK_STAGING_DATABASE`

Read the output. If a sibling worktree is already running the stack you want, switch to it (`cd <worktree>` + `make logs`) instead of starting a new one. If a clone-name collision shows up, fix it before continuing — two worktrees writing to the same DB is the worst kind of silent data loss.

## Fast Path

From the worktree root:

```bash
git status --short --branch
soria env status 2>/dev/null || true
if [ ! -f frontend/.env.local ] && [ -f "$HOME/workspace/soria-2/frontend/.env.local" ]; then
  mkdir -p frontend
  cp "$HOME/workspace/soria-2/frontend/.env.local" frontend/.env.local
fi
make run-dev
```

`make run-dev` is idempotent. It starts or restarts frontend and backend,
writes PIDs to `.dev/*.pid`, writes logs to `.dev/*.log`, auto-picks ports,
and rewrites `SERVER_URL`.

Clerk frontend auth lives in `frontend/.env.local` and is not tracked by git.
New worktrees often miss it. Copy it from the stable checkout
`~/workspace/soria-2/frontend/.env.local` into the current worktree when it is
missing. Copy only; do not move or delete the source file.

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

After entering the new worktree, ensure `frontend/.env.local` exists as above
before relying on frontend auth or browser tests.

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
if [ ! -f frontend/.env.local ] && [ -f "$HOME/workspace/soria-2/frontend/.env.local" ]; then
  mkdir -p frontend
  cp "$HOME/workspace/soria-2/frontend/.env.local" frontend/.env.local
fi
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
/dev-env -> make run-dev -> scripts/seed-dev-tp.py when needed -> /test
```

Use the script from the app repo, not from SoriaStack. Dry-run first:

```bash
python scripts/seed-dev-tp.py \
  --source-namespace soria_chunks_prod \
  --target-namespace "$TURBOPUFFER_NAMESPACE" \
  --file-ids <file_uuid> \
  --dry-run
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
