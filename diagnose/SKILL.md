---
name: diagnose
version: 2.0.0
description: |
  Diagnose and fix broken pipelines, silent failures, missing data, dive
  load failures, and infrastructure issues. Triage-first — observe before
  hypothesizing. Five modes: Silent Failure, Data Trace, Schema Mismatch,
  Infrastructure, Quality. Investigates via `soria` CLI commands, never
  MCP. Ends with either an inline fix or a Linear ticket for backend
  changes.
  Use when something "isn't working", "returned wrong data", "said success
  but nothing happened", "is slow", "is missing rows", or a dive "won't
  load" or "shows NaN". Proactively invoke this skill when the user
  reports a failure or unexpected behavior. (soria-stack)
benefits-from: [status, ingest, dive, verify]
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: diagnose"
echo "---"
echo "Active environment:"
soria env status 2>&1 || echo "  (soria CLI not authed — run /env first)"
echo "---"
echo ".soria-env.json (per-worktree config):"
cat .soria-env.json 2>/dev/null || echo "  (not set in this worktree)"
echo "---"
echo "Recent debug artifacts:"
ls -t ~/.soria-stack/artifacts/diagnose-*.md 2>/dev/null | head -3 || echo "  (none)"
```

Read `ETHOS.md` from this skill pack.

## Skill routing (always active)

When the user's intent shifts away from debugging, invoke the matching skill:

- User wants to rebuild the pipeline → invoke `/ingest`
- User wants to re-map values → invoke `/map`
- User wants to verify data correctness → invoke `/verify`
- User wants to check what exists → invoke `/status`
- User wants to promote after fixing → invoke `/promote`

**After /diagnose completes with a fix**, suggest `/verify` to confirm the fix worked.

---

# /diagnose — "Why isn't this working?"

You are a diagnostic investigator. Your job is to find root causes, not guess.
**Observe first, hypothesize second.** The AI's #1 debugging mistake is jumping
to a hypothesis before looking at the actual data.

---

## Rule Zero: Schema Discovery Before Any Query

**NEVER query a column without first confirming it exists.** This is the single
most common AI debugging mistake — querying columns that exist in Pydantic models
or ORM classes but not in the actual database table.

Before ANY diagnostic query, run:
```bash
# Postgres state DB
soria db query "SELECT column_name FROM information_schema.columns WHERE table_name = '{table}' AND table_schema = 'public' ORDER BY ordinal_position"
```

For warehouse tables:
```bash
soria warehouse query "SELECT column_name FROM information_schema.columns WHERE table_schema = '{schema}' AND table_name = '{table}'"
```

For dive manifests — read the file directly:
```bash
cat frontend/src/dives/manifests/{dive-id}.manifest.ts
```

If you skip this step and get a "column does not exist" error, that's on you.

---

## Step 1: Triage — What kind of failure?

Ask one question: **What did you expect to happen, and what happened instead?**

Then classify into one of five modes:

| Symptom | Mode | The problem |
|---------|------|-------------|
| "It said success but nothing happened" | **Silent Failure** | Command returned 0 but produced no output |
| "Wrong data / missing rows / NULLs" | **Data Trace** | Data exists somewhere but is wrong or incomplete |
| "Column/table doesn't exist" | **Schema Mismatch** | Migration not applied, wrong table name, stale schema |
| "Slow / timeout / connection error / dive won't load" | **Infrastructure** | Neon pool, MotherDuck cold start, DBOS Cloud, WASM cold start, Durable Object event relay |
| "Extraction produced bad data" | **Quality** | LLM output wrong, truncated, or incomplete |

Pick the mode. Say it out loud: "This looks like a **silent failure** — let me trace it."

---

## Mode 1: Silent Failure

Operations that report success but produce nothing. The most dangerous failure
type because the AI will initially believe the "OK" response.

**Core rule: Never trust CLI exit codes alone. Verify independently.**

### Diagnostic steps

1. **What command was run?** Note the exact invocation and flags.

2. **Verify the output exists independently:**

   - `soria scraper run` said "started" → check for downloaded files:
     ```bash
     soria db query "SELECT id, name, status, created_at FROM files WHERE scraper_id = '{scraper_id}' ORDER BY created_at DESC LIMIT 10"
     ```

   - `soria extract` said "started for N files" → check for child files:
     ```bash
     soria db query "SELECT id, name, status FROM files WHERE parent_file_id IN (SELECT id FROM files WHERE group_id = '{group_id}') ORDER BY created_at DESC LIMIT 20"
     ```

   - `soria warehouse publish` said OK → check the warehouse table:
     ```bash
     soria warehouse query "SELECT COUNT(*) FROM bronze.{table_name}"
     ```

   - `soria warehouse materialize` said OK → verify table type:
     ```bash
     soria warehouse query "SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = '{schema}' AND table_name = '{table}'"
     ```

   - `dbt run` said "1 of 1 OK" → query the materialized marts row:
     ```bash
     soria warehouse query "SELECT COUNT(*) FROM soria_duckdb_main.main_marts.{model}"
     ```

   - `dbt test` said pass → read the most recent run-results:
     ```bash
     cat frontend/public/dbt-run-results.json | jq '.results[] | select(.status != "pass")'
     ```

3. **If output doesn't exist, check known causes:**

   - **VIEW/TABLE type conflict:** `soria warehouse materialize` fails silently
     when trying to CREATE TABLE over an existing VIEW (or vice versa).
   - **Wrong env:** You may be reading prod while writing to dev. Check:
     ```bash
     soria env list
     ```
   - **Extractor stamp filtering:** Files may be filtered out before `--force`
     is checked. Look for files with `extractor_id` already set.
   - **Upstream event relay crash:** Cloudflare Durable Object event relay
     (`workers/event-relay`) may have dropped the notify event — the row
     landed but downstream skills never heard about it.

4. **Check prior sessions for this exact failure:**
   ```
   mcp__openclaw__mempalace_search: query="silent failure {command_name}"
   ```

### Disposition
- Backend bug (error swallowing, race condition) → **Ticket**
- Wrong env → **Fix inline** (switch envs, retry)
- Stale artifact blocking → **Fix inline** (drop and retry)
- Upstream event relay issue → **Ticket** + manual re-trigger

---

## Mode 2: Data Trace

Wrong data, missing rows, unexpected NULLs, or duplicate rows. Requires
multi-layer tracing.

### Diagnostic steps

1. **Identify the layer the user is seeing the problem at:**
   - Dive (browser) → user-facing
   - dbt marts → dive SQL layer
   - Gold / silver → upstream analytical layer
   - Bronze / warehouse → raw data
   - Postgres state → pipeline state

2. **Trace backwards through every layer.** At each layer, get a row count
   and check for the specific problem:

   ```bash
   # Layer 5: Dive marts (what the dive queries)
   soria warehouse query "SELECT COUNT(*) FROM soria_duckdb_main.main_marts.{model}"

   # Layer 4: Gold (joins + logic)
   soria warehouse query "SELECT COUNT(*) FROM gold.{model}"

   # Layer 3: Silver (cleaned + typed)
   soria warehouse query "SELECT COUNT(*) FROM silver.{model}"

   # Layer 2: Bronze (raw data)
   soria warehouse query "SELECT COUNT(*) FROM bronze.{table}"

   # Layer 1: Postgres pipeline state
   soria db query "SELECT COUNT(*) FROM files WHERE group_id = '{group_id}' AND status = 'published'"
   ```

3. **Find where the data disappears or goes wrong.** The layer where counts
   diverge or values change is where the bug lives.

4. **Common root causes by divergence point:**
   - Bronze has rows, silver doesn't → silver SQL filter too aggressive
   - Silver has rows, gold doesn't → join condition wrong
   - Gold has rows, marts don't → dbt model staleness (run `dbt run --select {model}`)
   - Marts has rows, dive shows nothing → manifest filter value drift —
     the manifest references a filter value that doesn't exist in the data:
     ```bash
     cat frontend/src/dives/manifests/{dive}.manifest.ts
     soria warehouse query "SELECT DISTINCT {filter_column} FROM soria_duckdb_main.main_marts.{model}"
     ```
   - Data loaded 2-3x → repeated `soria warehouse publish` without dedup.
     Check `_source_file` column for duplicates.

### Disposition
- SQL bug in silver/gold → **Fix inline** (update the SQL model, re-run)
- dbt model stale → **Fix inline** (`dbt run --select {model}`)
- Manifest filter drift → **Fix inline** (update manifest values list)
- Extraction produced bad data → Invoke `/ingest` to fix extractor
- Value mapping wrong → Invoke `/map`
- Duplicate publish → **Fix inline** (`soria warehouse unpublish`, then re-publish)

---

## Mode 3: Schema Mismatch

Column doesn't exist, table not found, or queries return unexpected structure.

### Diagnostic steps

1. **Get the actual schema** (Rule Zero):
   ```bash
   soria db query "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '{table}' AND table_schema = 'public' ORDER BY ordinal_position"
   ```

2. **Compare against what was expected.** Common mismatches:
   - **Computed property, not a DB column:** e.g., something that exists as a
     Python `@property` but not in the database. Check the model code if available.
   - **Migration not applied:** Column exists in code but not in the database.
     Check Alembic migration status.
   - **Env branch drift:** Your env was branched before the column was added.
     Solution: `soria env teardown` + `soria env branch` to get a fresh clone.
   - **Wrong table name:** dbt marts use `soria_duckdb_main.main_marts.{model}`,
     NOT `marts.{model}`. Bronze/silver/gold live in `soria_duckdb`.

3. **For warehouse schema issues:**
   ```bash
   soria warehouse query "SELECT table_schema, table_name FROM information_schema.tables WHERE table_name LIKE '%{keyword}%'"
   ```

### Disposition
- Missing migration → **Ticket** (need Alembic migration + deploy)
- Env branch drift → **Fix inline** (recreate env from fresh clone)
- Wrong table/column name → **Fix inline** (correct the query)

---

## Mode 4: Infrastructure

Timeouts, connection errors, slow queries, cold starts, dive load failures.

### Subsystem catalog

| System | Common failure | Fix |
|--------|---------------|-----|
| **Neon (Postgres)** | Pool exhaustion, SSL drops | Transient — retry once; if persistent, ticket |
| **MotherDuck (DuckDB)** | Cold start 30-47s after idle | Architectural — not a bug unless causing gateway timeout |
| **S3 / managed DuckLake** | Parquet 404, cross-region latency | Check object exists; if transient, retry |
| **DBOS Cloud** | Worker restart, PG wire timeout | Check DBOS dashboard; ticket if persistent |
| **Clerk JWT** | Stale token, admin/user role mismatch | Re-login; if role issue, check user metadata |
| **Durable Object event relay** (`workers/event-relay`) | Event dropped, relay stuck | Check Cloudflare worker logs; re-trigger event |
| **WASM cold start** (dive) | First load takes ~20s to download/compile client | Normal — distinguish from "broken" (see dual-mode loading invariant) |
| **Postgres wire proxy** (dive fallback) | 30s statement timeout | Reduce query complexity or add marts aggregation |

### Diagnostic steps

1. **Identify the subsystem** from the error message, URL pattern, or stack trace.

2. **For slow dive queries:** Check marts table exists and dbt is fresh:
   ```bash
   soria warehouse query "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main_marts'"
   cat frontend/public/dbt-run-results.json | jq '.generated_at'
   ```

3. **For connection errors:** Almost always transient. Retry once. If
   persistent, likely Neon pool exhaustion or DBOS Cloud worker issue.

4. **For MotherDuck cold start:** First query after idle takes 30-47s.
   Not a bug. If it causes gateway timeouts, ticket for timeout config.

5. **For dive "won't load" reports:** Distinguish the two load modes —
   ```
   Is it: (a) first paint blank/stuck for >5s?      → Postgres proxy failing
          (b) first paint OK but stale after?       → WASM upgrade failing
          (c) worked once, now broken on refresh?   → Session cache poison
   ```
   Check the browser console and the network tab. WASM cold start for the
   first ~20s is normal — the Postgres proxy must return data first.

6. **For Durable Object event relay issues:**
   ```bash
   # Check worker logs (user may need to run this themselves if they're in CF dashboard)
   cd workers/event-relay && wrangler tail
   ```

### Disposition
- Transient → **Retry** (no action needed)
- Stale dbt marts → **Fix inline** (`dbt run --select {model}`)
- Manifest/data drift → **Fix inline** (update manifest filter values)
- Pool exhaustion → **Ticket** (container cleanup or pool config)
- Event relay stuck → **Ticket** + manual re-trigger
- WASM cold start confused for breakage → **Document** (not a bug)

---

## Mode 5: Quality

Extraction produced wrong, incomplete, or truncated data.

### Diagnostic steps

1. **Get the source file and extraction output side by side:**
   ```bash
   # Find the source file
   soria file show {file_id}

   # Find extraction outputs (child files)
   soria db query "SELECT id, name, storage_key, status FROM files WHERE parent_file_id = '{file_id}'"
   ```

2. **Check for known extraction failure patterns:**
   - **Truncated JSON:** LLM output hit token limit on large PDFs. Look for
     incomplete rows or malformed CSV.
   - **Missing pages:** Detection may not have flagged all relevant pages.
     Check detection results:
     ```bash
     soria db query "SELECT file_id, detected_pages FROM detection_results WHERE file_id = '{file_id}'"
     ```
   - **Wrong schema applied:** Extractor used wrong column set. Compare
     extraction CSV headers against group schema columns.

3. **Spot-check 3 values** from the source against the extraction output.
   Don't check totals or obvious values — check middle-of-table specifics.

### Disposition
- Extractor bug → Invoke `/ingest` (fix extractor, re-run with `soria scraper test`)
- Detection missed pages → **Fix inline** (adjust detection, re-run)
- LLM truncation → **Ticket** if systemic, or split extraction into smaller chunks

---

## Check for the Interactive Agent

Before filing a ticket or force-fixing something, check whether the Modal
sandbox interactive agent is already working on it. It listens for comments
on PRs and investigations on Linear issues and replies in real time.

Use signals you can observe without Linear MCP:

```bash
# auto-fix branches on origin matching the ENG-ticket you're debugging
git branch -r | grep -E "auto-fix/ENG-"

# Open PRs from the agent's service account
gh pr list --state open --json number,author,title,headRefName
```

Linear inspection is owned by `/ticket` — if you need a deeper check
(duplicate/regression/active agent run with `agent` label), **invoke
`/ticket`** and let it do the Linear query. That way the ticket skill
either defers to the agent or files a clean new issue.

If an active agent run is investigating the same failure, **defer to it** —
report that the agent is on it and move on. Don't duplicate work or race
the agent.

---

## Filing a Ticket

When the disposition is **Ticket**, **invoke `/ticket`** — don't file directly.
`/ticket` owns all Linear writes, checks for duplicates, scans for active
interactive-agent runs, and classifies priority consistently. Pass it your
diagnostic findings so it can write a complete repro + root-cause ticket
without re-discovering the problem.

### When to ticket vs fix inline

| Situation | Action |
|-----------|--------|
| Backend code change needed (error swallowing, wrong logic) | invoke `/ticket` |
| Infrastructure config (pool size, timeout, container cleanup) | invoke `/ticket` |
| SQL model fix (wrong join, missing filter) | Fix inline (dbt model or silver/gold) |
| Stale dbt marts | Fix inline (`dbt run`) |
| Manifest filter value drift | Fix inline (update manifest) |
| Re-extraction with adjusted parameters | Fix inline via `/ingest` |
| Stale env, needs recreation | Fix inline (`soria env teardown` + `branch`) |
| Systemic LLM extraction failure | invoke `/ticket` |
| Durable Object event relay stuck | invoke `/ticket` |
| Modal sandbox agent stuck PR | invoke `/ticket` (agent will pick it up) |
| `soria` CLI gap (command doesn't exist) | invoke `/ticket` (classify as "Missing feature") |

After `/ticket` files the issue, return to `/diagnose` if the user wants
to continue debugging, or close out with a report.

---

## Searching Prior Sessions

Before deep-diving, check if this exact issue has been debugged before:

```
mcp__openclaw__mempalace_search: query="{description of the problem}"
```

If a prior session found the root cause, skip straight to the fix or ticket.
Don't re-debug what's already been diagnosed.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/diagnose-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Debug Report: [Short description]

## Symptom
[What the user reported]

## Environment
[Active soria env, from `soria env list`]

## Triage
Mode: [Silent Failure | Data Trace | Schema Mismatch | Infrastructure | Quality]

## Investigation
[What you checked, what you found at each layer]

## Root Cause
[The actual problem — be specific]

## Disposition
[Fix inline | Ticket | Invoke /ingest | Invoke /map | Defer to interactive agent]

## Action Taken
[What was done — SQL fix, ticket created (ENG-XXX), dbt run, etc.]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was unexpected or worth remembering]
ARTIFACT
```

---

## Anti-Patterns

1. **Hypothesizing before observing.** Don't say "this is probably a schema issue"
   before running a single query. Look first.

2. **Querying columns without schema discovery.** Rule Zero exists because the AI
   gets this wrong in almost every debug session. `information_schema` first.

3. **Trusting CLI exit codes.** `soria warehouse publish` returning 0 doesn't
   mean data landed. Verify independently at the destination.

4. **Checking one layer and declaring success.** Data exists in Postgres but not
   MotherDuck? That's not "data exists." Trace all layers.

5. **Saying "this needs a ticket" without creating one.** If the disposition is
   Ticket, invoke `/ticket` right now. Don't defer.

6. **Re-debugging known issues.** Search prior sessions first. If it's been
   diagnosed, skip to the fix.

7. **Guessing the fix without confirming the cause.** "Let me try re-running dbt"
   is not debugging. Find the root cause, then fix it.

8. **Racing the interactive agent.** If the Modal sandbox agent has an active
   run on the same PR or ticket, defer to it. Don't comment, don't fix, don't
   ticket — report and move on.

9. **Calling WASM cold start a bug.** First dive load takes ~20s to warm the
   DuckDB-WASM client. The Postgres proxy fallback must return data in the
   meantime. If first paint is slow but data arrives, that's normal.
