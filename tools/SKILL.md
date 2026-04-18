---
name: tools
version: 3.0.0
description: |
  Verify the Soria MCP server is reachable and the local dev stack is
  installed. Run at the START of every session. All skills drive the Soria
  platform through the `mcp__soria__*` tool namespace — there is no `soria`
  CLI. Also checks local tools needed for dive work: uv, node, dbt, make,
  git, gh. If you see "MCP not reachable" or a missing local tool, run this
  skill to diagnose and fix before doing any other work.
allowed-tools:
  - Read
  - Bash
---

# /tools — Verify MCP + Local Stack

You are confirming the session can actually do work: the Soria MCP is
reachable and the local tools needed for dive authoring are installed.
There is no `soria` CLI — don't look for one.

External MCP tools are owned by specific skills: `mcp__linear__*` by
`/ticket`, `mcp__openclaw__mempalace_search` by `/lessons`/`/map`/`/dive`
for domain grounding. Those load on first use — not this skill's job.

---

## Step 1: Soria MCP reachable

Probe with a trivial query:

```
mcp__soria__database_query(sql="SELECT 1 AS ok")
```

If it errors:

```
⚠️  Soria MCP not reachable.

Check ~/.claude.json → mcpServers.soria — it should point at an HTTP
endpoint like https://<your-dbos>.cloud.dbos.dev/mcp/. Restart Claude
Code after edits. If auth is failing, sign in at the endpoint in your
browser first.
```

STOP. Every pipeline skill depends on the MCP.

## Step 2: Local tools

```bash
for t in uv node npm dbt make git gh; do
  if command -v "$t" >/dev/null 2>&1; then
    printf "  ✓ %s: %s\n" "$t" "$("$t" --version 2>&1 | head -1)"
  else
    printf "  ✗ %s: missing\n" "$t"
  fi
done
```

Missing tools and their install:

- `uv` — `brew install uv` (Python package manager; drives the soria-2 venv)
- `node` / `npm` — `brew install node` (needed for the vite frontend)
- `dbt` — installed in the soria-2 venv via `uv sync`; run from repo root
- `make` — usually present on macOS; `brew install make` otherwise
- `gh` — `brew install gh` (used by `/promote` for PR creation)

If `dbt` is missing but `uv` works, tell the user to run `uv sync` in the
soria-2 repo root.

## Step 3: dbt profile reachable

From the soria-2 checkout:

```bash
cd frontend/src/dives/dbt 2>/dev/null && ../../../../.venv/bin/dbt debug 2>&1 | tail -10 || echo "(dbt project not present in this dir — run from soria-2 root)"
```

`dbt debug` succeeds = MotherDuck staging is reachable with the current
credentials (`MOTHERDUCK_TOKEN` + `MOTHERDUCK_STAGING_DATABASE` in `.env`).
Failure usually means the `.env` isn't sourced or the token is missing.

## Step 4: dev-https cert

```bash
[ -f frontend/dev.soriaanalytics.com.pem ] && echo "  ✓ dev-https cert present" || echo "  ✗ dev-https cert missing — run: make dev-https-setup"
```

Without the cert, `https://dev.soriaanalytics.com` won't load. One-time
setup: `make dev-https-setup`. After that, daily is just `make dev-https`.

## Step 5: Summary

```
Soria stack ready.
  MCP:        ✓ reachable
  Local:      uv, node, dbt, make, git, gh all present
  dbt:        ✓ debug passes against soria_duckdb_staging
  dev-https:  ✓ cert installed

Next: /status (inventory), /plan (design work), /ingest (scrape),
      /dive (build a dive), /verify (check correctness).
```

---

## Skill routing (always active)

After /tools, the user's next message determines which skill to invoke.
Do NOT answer directly — invoke the matching skill via the Skill tool:

- "What's the status of X", "let's work on X" → invoke `/status`
- "Come up with a plan", "what should we do" → invoke `/status` first, then `/plan`
- "Is my dev stack ok", "what am I pointed at" → invoke `/env`
- "Scrape this", "build the pipeline", "extract" → invoke `/ingest`
- "Value map", "normalize values", "canonical" → invoke `/map`
- "Map parent companies" → invoke `/parent-map`
- "Build a dive", "build a dashboard", "write the SQL" → invoke `/dive`
- "Show me the dive", "preview" → invoke `/preview`
- "Verify", "spot check", "prove it" → invoke `/verify`
- "Test the UI", "click through it", "browser QA" → invoke `/dashboard-review`
- "This isn't working", "it broke", "wrong data" → invoke `/diagnose`
- "Promote", "push to prod" → invoke `/promote`
- "News pipeline", "tune prompts" → invoke `/newsroom`
- "Retro", "what did we learn" → invoke `/lessons`

---

## Anti-Patterns

1. **Looking for a `soria` CLI.** It's retired. The MCP is the entry point.
2. **Proceeding when MCP probe failed.** Every pipeline skill depends on it.
   Don't skip to `/status` or `/ingest` — fix the MCP first.
3. **Confusing `dev-https` (HTTPS against prod backend) with `run-dev`
   (full local stack).** `dev-https` is the default for soria-stack work.
   `make run-dev` is only for people working on the backend.
