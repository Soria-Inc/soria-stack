---
name: dev-dives
version: 1.0.0
description: Use when setting up, repairing, or verifying the Soria dev HTTPS dive frontend at https://dev.soriaanalytics.com, especially when iterating on dives against the remote prod API, checking Vite/MotherDuck env alignment, or diagnosing empty dashboard grids.
allowed-tools:
  - Read
  - Bash
---

# /dev-dives

Use this for the local dev HTTPS mode used to iterate on Soria dive frontends:
`https://dev.soriaanalytics.com` served by local Vite, with API calls proxied
to the remote prod backend. This is different from `/dev-env`, which starts a
full local backend/frontend stack, and from `/browse`, which handles browser
auth, screenshots, console, and network evidence after the runtime is sane.

Read the target repo's `AGENTS.md` and `CLAUDE.md` first. Repo-local rules win.

## Runtime Contract

- Bare `https://dev.soriaanalytics.com/...` is the canonical browser URL for
  Soria Clerk auth and dive QA.
- On macOS, `/etc/hosts` maps that host to `127.0.0.1`; `pf` redirects port
  `443` to local Vite on `5189`.
- `https://dev.soriaanalytics.com:5189/...` is a liveness diagnostic only.
  Do not use the explicit port for final auth assertions.
- In frontend-only dive iteration, Vite must run from the intended app
  worktree's `frontend/` directory and proxy `/api` to
  `https://cameron-soria.cloud.dbos.dev`.
- MotherDuck catalogs must be explicit:
  `VITE_MOTHERDUCK_STAGING=soria_duckdb_staging` and
  `VITE_MOTHERDUCK_PROD=soria`.
- Do not assume dbt tables were deleted because a grid is empty. First verify
  the served Vite env and the selected app data environment.

## Preflight

From the app worktree root:

```bash
pwd
git status --short --branch
lsof -nP -iTCP:5189 -sTCP:LISTEN || true

for pid in $(lsof -tiTCP:5189 -sTCP:LISTEN 2>/dev/null || true); do
  ps -p "$pid" -o pid,ppid,lstart,command
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n/cwd: /p'
done

curl -skI --max-time 3 https://dev.soriaanalytics.com/ | head -n 12 || true
curl -skI --max-time 3 https://dev.soriaanalytics.com:5189/ | head -n 12 || true
curl -sk https://dev.soriaanalytics.com/src/api/dashboardClient.ts \
  | rg -o 'VITE_API_PROXY_TARGET[^,]+|VITE_MOTHERDUCK_STAGING[^,]+|VITE_MOTHERDUCK_PROD[^,]+' || true
```

The served module is the source of truth. Seeing the right process in `ps` is
not enough if Vite was launched with stale env.

Expected frontend-only dive env:

```text
VITE_API_PROXY_TARGET": "https://cameron-soria.cloud.dbos.dev"
VITE_MOTHERDUCK_PROD": "soria"
VITE_MOTHERDUCK_STAGING": "soria_duckdb_staging"
```

## Start Or Repair Frontend-Only Mode

Stop only the Vite listener on `5189`. Do not kill local Python backends unless
the user explicitly asked for full local dev stack repair.

```bash
set -e

for pid in $(lsof -tiTCP:5189 -sTCP:LISTEN 2>/dev/null || true); do
  echo "stopping vite pid $pid"
  ps -p "$pid" -o pid,ppid,command || true
  kill "$pid" || true
done
sleep 1

mkdir -p .dev
(
  cd frontend
  VITE_API_PROXY_TARGET=https://cameron-soria.cloud.dbos.dev \
  VITE_MOTHERDUCK_STAGING=soria_duckdb_staging \
  VITE_MOTHERDUCK_PROD=soria \
  nohup python3 -c 'import os,sys; os.setsid(); os.execvpe(sys.argv[1], sys.argv[1:], os.environ)' \
    ./node_modules/.bin/vite --port 5189 \
    > ../.dev/dev-dives-vite.log 2>&1 < /dev/null &
  echo $! > ../.dev/dev-dives-vite.pid
)

sleep 2
lsof -nP -iTCP:5189 -sTCP:LISTEN
tail -n 60 .dev/dev-dives-vite.log
```

Then rerun the preflight curl against `dashboardClient.ts`.

If the repo has a maintained `make dev-https-prod` target that sets the same
three env vars, use it. If that target omits the MotherDuck vars, prefer the
explicit command above and consider fixing the Makefile separately.

## Data Checks

If a dive renders but shows no rows:

1. Confirm the left-sidebar data badge is on the expected environment.
2. Confirm the served Vite module has the expected MotherDuck catalog names.
3. Query the mart directly with the available Soria warehouse tool. Use the
   fully qualified catalog when checking staging:

```sql
SELECT COUNT(*) AS rows
FROM soria_duckdb_staging.main_marts.<mart_name>;
```

Only call it a missing-data problem after the warehouse check proves the table
is absent or empty in the selected catalog.

## Browser QA Handoff

After runtime setup:

- hard-refresh any already-open browser tab so it reloads Vite env modules
- use `/browse` for cookie import, manual Clerk fallback, screenshots,
  console/network capture, and interaction testing
- if `$B` shows sign-in after cookie import, follow `/browse` auth rules
  rather than restarting Vite again

## Common Failure Modes

- **Connection refused on bare host**: Vite is down or `pf` is not redirecting
  `443` to `5189`.
- **Bare host down, explicit `:5189` works**: rerun local HTTPS setup
  (`make dev-https-setup` or `scripts/setup-local-https.sh`) with sudo.
- **Grid says `No Rows To Show`**: suspect wrong catalog/env first, especially
  `VITE_MOTHERDUCK_STAGING=my_db` or a local API proxy to an older checkout.
- **`/api/runtime` returns 404**: not always fatal in remote-prod API mode;
  older remote backends may not expose that diagnostic route.
- **API returns 401**: auth/session problem. Use `/browse` cookie import or
  manual Soria login fallback.
