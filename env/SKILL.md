---
name: env
version: 2.0.0
description: |
  Sanity-check the Soria dev stack. There are no isolated dev environments
  anymore — the MCP writes directly to shared Postgres + soria_duckdb_staging,
  soft-delete keeps every write reversible, and prod MotherDuck is reached
  only via PR-gated CI. This skill confirms MCP reachability, local dev
  server health (https://dev.soriaanalytics.com), and warns on recent
  activity so the user knows the shared state they're about to touch.
  Use when asked "what am I pointed at", "is my dev stack working", "what's
  the state", or at the start of a session alongside /tools. Read-only.
  (soria-stack)
allowed-tools:
  - Read
  - Bash
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: env"
echo "---"
echo "Local repo:"
git rev-parse --show-toplevel 2>&1 | head -1
git status --short --branch 2>&1 | head -5
echo "---"
echo "dev-https cert:"
[ -f frontend/dev.soriaanalytics.com.pem ] && echo "  ✓ frontend/dev.soriaanalytics.com.pem" || echo "  ✗ missing — run: make dev-https-setup"
echo "---"
echo "Recent pipeline activity (via MCP — last 10 events):"
echo "  run: mcp__soria__pipeline_activity (limit=10) to see who changed what."
```

Read `ETHOS.md`. Key principle: MCP-First Tool Invocation — reversibility
over isolation.

## Skill routing (always active)

- User wants pipeline inventory → invoke `/status`
- User wants to plan work → invoke `/plan`
- User wants to build a pipeline → invoke `/ingest`
- User wants to build a dive → invoke `/dive`
- User wants to promote → invoke `/promote`
- User wants to diagnose a failure → invoke `/diagnose`

---

# /env — "What's my dev stack look like?"

You are the dev-stack preflight. There are no isolated environments to
switch between. Three shared resources back every session:

- **Postgres (state)** — scrapers, groups, files, schemas, mappings, events
- **`soria_duckdb_staging`** — the working MotherDuck database; bronze from
  ingest + dbt staging/intermediate/marts from local `dbt run`
- **`soria_duckdb_main`** — prod MotherDuck; written only by CI on PR merge

Your local work is:
- **Git checkout** of `soria-2` (ideally on a feature branch)
- **`make dev-https`** — vite at `https://dev.soriaanalytics.com` proxied
  to prod DBOS API + Clerk. No local backend needed for dive work.
- **Staging/prod badge** in the app chrome (amber "staging" / green "prod").
  Default is **prod**. Click to toggle. Picks which MotherDuck the backend
  queries for that session (via `X-SQLMESH-ENV` header — legacy name; it
  routes between `MOTHERDUCK_DATABASE` and `MOTHERDUCK_PROD_DATABASE`). To
  see your local `dbt run` output, toggle to **staging**.
- **`mcp__soria__*`** — how this skill pack reaches the Soria platform

---

## Checks

### 1. MCP reachable

Probe the Soria MCP with a trivial query:

```
mcp__soria__database_query(sql="SELECT 1 AS ok")
```

If it errors, the MCP server is unreachable or not configured. Tell the
user to check `~/.claude.json → mcpServers.soria` and restart Claude Code.

### 2. Local dev-https cert + vite process

```bash
[ -f frontend/dev.soriaanalytics.com.pem ] && echo "cert: ok" || echo "cert: missing — run make dev-https-setup"
curl -sk -o /dev/null -w "dev-https: %{http_code}\n" https://dev.soriaanalytics.com/
lsof -ti:5189 >/dev/null 2>&1 && echo "vite: running (pid $(lsof -ti:5189 | head -1))" || echo "vite: down"
```

- **Cert missing** → one-time setup: `make dev-https-setup`.
- **dev-https returns 000 or vite is down** → vite died. `make dev-https`
  runs in the foreground so it dies with its shell. Restart detached:
  ```bash
  cd frontend && nohup npx vite --port 5189 > /tmp/soria-vite.log 2>&1 &
  disown
  ```
  Stop later with `kill $(lsof -ti:5189)`. If this keeps happening, patch
  the `dev-https` Makefile target to daemonize (like `run-dev` does via
  `scripts/run-dev.sh`) — worth a `/ticket`.

### 3. Uncommitted / unpushed work

```bash
git status --short --branch
git log --oneline origin/main..HEAD 2>/dev/null | head -10
```

Surface uncommitted changes or unpushed commits. Every promote is a PR,
so unpushed work isn't promoted — the user should know.

### 4. Recent pipeline activity

```
mcp__soria__pipeline_activity(limit=10)
```

Report the last ~10 pipeline events — create/update/delete on scrapers,
groups, files, schemas, value mappings. This surfaces "who touched what
yesterday" so the user knows the shared state they're about to touch.

### 5. Warehouse freshness

```
mcp__soria__warehouse_query(sql="
  SELECT table_schema, table_name, estimated_size
  FROM duckdb_tables()
  WHERE table_schema IN ('bronze','staging','intermediate','marts')
  ORDER BY table_name
")
```

Report a compact table of what's in staging. If bronze is empty for a
group the user wants to dive on, flag it — they'll need `/ingest` first.

---

## Summary output

```
Dev stack status

  Repo:        soria-2 @ feat/medicaid-states (2 ahead, 0 behind)
  MCP:         ✓ reachable (soria)
  dev-https:   ✓ cert installed
  Uncommitted: 3 files
  Unpushed:    2 commits
  Recent MCP:  4 writes in last hour by you (groups, schemas, extractions)
  Staging:     bronze 12 tables, marts 9 tables

Next: /status (inventory), /plan (design work), /ingest (scrape),
      /dive (build a dive), /verify (check correctness).
```

---

## Anti-Patterns

1. **Claiming there are isolated envs.** There aren't. Every write is to
   shared state. Safety comes from soft-delete + audit trail, not from
   sandboxing.
2. **Running write-path skills blind.** Always surface recent pipeline
   activity so the user can see what state they're inheriting.
3. **Telling the user to install the `soria` CLI.** It doesn't exist.
   The MCP is the entry point.
4. **Trying to `soria env` anything.** All `soria env` commands are dead.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/env-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Dev stack preflight

## Summary
Repo: [branch, ahead/behind]
MCP: [reachable / error]
dev-https cert: [present / missing]
Uncommitted: [count]
Unpushed: [count]

## Recent MCP activity
[10 events — actor, action, entity]

## Warehouse
bronze: [count tables]
staging / intermediate / marts: [counts]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
ARTIFACT
```
