---
name: tools
version: 2.0.0
description: |
  Verify the Soria CLI is installed and report the active environment.
  Run at the START of every session alongside /env. This skill replaces
  the old MCP tool loader — there are no MCP tools to load anymore.
  All skills drive the Soria platform through the `soria` CLI.
  If you see "soria not found" or "no active environment", run this skill
  to diagnose and fix before doing any other work.
allowed-tools:
  - Read
  - Bash
---

# /tools — Verify CLI + Active Environment

You are checking that the Soria CLI is installed and that an environment is
active. **No Soria MCP tools to load** — the Soria platform is driven
entirely through the `soria` CLI now.

External MCP tools are still allowed where skills reference them:
`mcp__linear__*` (owned by `/ticket` — `/diagnose` and `/promote` invoke
`/ticket` rather than calling Linear directly) and
`mcp__openclaw__mempalace_search` (for `/lessons`, `/map`, `/dive`, `/plan`,
`/ticket` — domain grounding and prior-session search). Those do NOT need
to be loaded via ToolSearch at session start — Claude Code loads them on
first use. This skill does not touch them.

---

## Step 1: CLI installed?

```bash
which soria && soria --version
```

If missing:

```
⚠️  soria CLI not installed.

Install from the soria-2 repo root:

    uv tool install --from ./cli soria-cli
    soria auth setup
    soria shell-setup >> ~/.zshrc
    source ~/.zshrc

Then re-run /tools.
```

STOP if the CLI is missing. Don't try to work around it.

## Step 2: Auth configured?

```bash
soria env list 2>&1 | head -5
```

If the output is `{"error": "No prod server configured. Run: soria auth setup"}`:

```
⚠️  soria auth not set up.

Run:

    soria auth setup

This prompts for the prod server URL and opens a browser for OAuth.

Then re-run /tools.
```

STOP if auth isn't configured.

## Step 3: Active environment?

```bash
soria env status
```

Report what `soria env status` returns. If the output indicates no active
env, tell the user:

```
No active environment.

Run /env to list and switch to one, or /env branch to create a new dev env.
```

## Step 3b: dbt profile set up?

```bash
cd frontend/src/dives/dbt 2>/dev/null && dbt debug --target dev 2>&1 | tail -20 || echo "(dbt project not present — skip)"
```

If the dbt project exists and `dbt debug` fails, the `soria_dives` profile
isn't configured or MotherDuck credentials are missing. Tell the user to
check `~/.dbt/profiles.yml` or the `MOTHERDUCK_TOKEN` env var. This is a
one-time setup that every new developer hits.

## Step 4: Prod warning

If the active environment is `prod`:

```
⚠️  POINTING AT PROD

All write-path skills (/ingest, /map, /parent-map, /dive) will refuse to
run against prod without explicit acknowledgment. /promote is the only
skill that expects to touch prod.

To switch to a dev env: soria env checkout <name>
To create a new dev env: soria env branch <name>
```

## Step 5: Summary

Print a concise summary:

```
Soria CLI ready.
  Version: soria X.Y.Z
  Auth:    configured (prod: https://...)
  Active:  prickle-bottle (dev)

Next: /status (inventory), /plan (design work), /ingest (scrape),
      /dive (build a dive), /verify (check correctness).
```

---

## Skill routing (always active)

After /tools, the user's next message determines which skill to invoke.
Do NOT answer directly — invoke the matching skill via the Skill tool:

- "What's the status of X", "let's work on X" → invoke `/status`
- "Come up with a plan", "what should we do" → invoke `/status` first, then `/plan`
- "Manage envs", "switch env", "new branch" → invoke `/env`
- "Scrape this", "build the pipeline", "extract" → invoke `/ingest`
- "Value map", "normalize values", "canonical" → invoke `/map`
- "Map parent companies" → invoke `/parent-map`
- "Build a dive", "build a dashboard", "write the SQL" → invoke `/dive`
- "Show me the dive", "preview" → invoke `/preview`
- "Verify", "spot check", "prove it" → invoke `/verify`
- "Test the UI", "click through it", "browser QA" → invoke `/smoke`
- "This isn't working", "it broke", "wrong data" → invoke `/diagnose`
- "Promote", "push to prod" → invoke `/promote`
- "News pipeline", "tune prompts" → invoke `/newsroom`
- "Retro", "what did we learn" → invoke `/lessons`

---

## Anti-Patterns

1. **Looking for MCP tools.** There are no Soria MCP tools. There is no
   ToolSearch call to run. The `soria` CLI is the only surface.
2. **Running other skills when the CLI is missing or auth isn't set up.**
   Every skill depends on the CLI — fix the CLI first.
3. **Proceeding silently when the active env is prod.** Print the warning
   and wait for explicit user acknowledgment before suggesting any
   write-path skill.
