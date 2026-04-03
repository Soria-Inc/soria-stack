---
name: diagnose
version: 1.0.0
description: |
  Diagnose and fix broken pipelines, silent failures, missing data, and
  infrastructure issues. Triage-first — observe before hypothesizing.
  Use when something "isn't working", "returned wrong data", "said success
  but nothing happened", "is slow", or "is missing rows".
  Proactively invoke this skill (do NOT debug ad-hoc) when the user reports
  a failure or unexpected behavior. Structured triage prevents the AI from
  guessing wrong and wasting 30 minutes.
  Ends with either an inline fix or a Linear ticket for backend changes. (soria-stack)
benefits-from: [status, ingest, dashboard, verify]
allowed-tools:
  - sumo_*
  - mcp__linear__*
  - mcp__openclaw__search_context
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: diagnose"
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
```
database_query("SELECT column_name FROM information_schema.columns WHERE table_name = '{table}' AND table_schema = 'public' ORDER BY ordinal_position")
```

For warehouse tables:
```
warehouse_query("SELECT column_name FROM information_schema.columns WHERE table_schema = '{schema}' AND table_name = '{table}'")
```

If you skip this step and get a "column does not exist" error, that's on you.

---

## Step 1: Triage — What kind of failure?

Ask one question: **What did you expect to happen, and what happened instead?**

Then classify into one of five modes:

| Symptom | Mode | The problem |
|---------|------|-------------|
| "It said success but nothing happened" | **Silent Failure** | Tool returned OK but produced no output |
| "Wrong data / missing rows / NULLs" | **Data Trace** | Data exists somewhere but is wrong or incomplete |
| "Column/table doesn't exist" | **Schema Mismatch** | Migration not applied, wrong table name, stale schema |
| "Slow / timeout / connection error" | **Infrastructure** | Neon pool, MotherDuck cold start, deploy state |
| "Extraction produced bad data" | **Quality** | LLM output wrong, truncated, or incomplete |

Pick the mode. Say it out loud: "This looks like a **silent failure** — let me trace it."

---

## Mode 1: Silent Failure

Operations that report success but produce nothing. The most dangerous failure
type because the AI will initially believe the "OK" response.

**Core rule: Never trust tool return values. Verify independently.**

### Diagnostic steps

1. **What tool was called?** Note the exact operation and parameters.

2. **Verify the output exists independently:**
   - `warehouse_materialize` said OK → query `information_schema.tables` for the object
   - `extraction_run` said "started for N files" → query for child files:
     ```
     database_query("SELECT id, name, status FROM files WHERE parent_file_id IN (SELECT id FROM files WHERE group_id = '{group_id}') ORDER BY created_at DESC LIMIT 20")
     ```
   - `scraper_run` said "started" → check for downloaded files:
     ```
     database_query("SELECT id, name, status, created_at FROM files WHERE scraper_id = '{scraper_id}' ORDER BY created_at DESC LIMIT 10")
     ```
   - `workspace_manage(promote)` said OK → check prod models exist:
     ```
     sql_model_list()  -- filter for workspace_id is NULL
     ```

3. **If output doesn't exist, check known causes:**
   - **VIEW/TABLE type conflict:** `warehouse_materialize` fails silently when
     trying to CREATE TABLE over an existing VIEW (or vice versa). Check:
     ```
     warehouse_query("SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = '{schema}' AND table_name = '{table}'")
     ```
   - **Model not in workspace:** `warehouse_materialize` no-ops if the model
     doesn't have a `SqlModelCode` record in the target workspace.
   - **Wrong schema for workspace objects:** After `warehouse_materialize` in a
     workspace, the object lives at `{layer}__{postgres_schema}.{model_name}` —
     NOT `{layer}.{model_name}`. Querying `silver.stg_x` hits prod, not the
     workspace. Check what's actually materialized in the workspace:
     ```
     warehouse_query("SELECT table_schema, table_name, table_type FROM information_schema.tables WHERE table_schema LIKE '%ws_%'")
     ```
   - **`motherduck_database = NULL` misread:** NULL does NOT mean no MotherDuck
     state. The workspace shares the prod MotherDuck database but uses separate
     schemas: `{layer}__{postgres_schema}` in the same database.
   - **`sql_model_save` does not auto-materialize:** Saving a model writes the
     SQL definition to Postgres only. Must call `warehouse_materialize` explicitly
     in dependency order: silver → gold → platinum, each with `workspace="ws_xxx"`.
   - **Extractor stamp filtering:** Files may be filtered out before `force=True`
     is checked. Look for files with `extractor_id` already set.
   - **Event bus crash:** CSV saved but `event_bus.publish()` failed after —
     child file exists in storage but has no DB record.

4. **Check prior sessions for this exact failure:**
   ```
   search_context(query="silent failure {tool_name}", source="claude-code", limit=5)
   ```

### Disposition
- Tool bug (CREATE OR REPLACE, error swallowing) → **Ticket**
- Missing workspace model → **Fix inline** (save model first, retry)
- Stale artifact blocking → **Fix inline** (drop and recreate)

---

## Mode 2: Data Trace

Wrong data, missing rows, unexpected NULLs, or duplicate rows. Requires
multi-layer tracing.

### Diagnostic steps

1. **Identify the layer the user is seeing the problem at:**
   - Dashboard / platinum query → user-facing
   - Gold/silver query → analytical layer
   - Bronze / warehouse → raw data
   - Postgres metadata → pipeline state

2. **Trace backwards through every layer.** At each layer, get a row count
   and check for the specific problem:

   ```
   -- Layer 4: Platinum (what the user sees)
   warehouse_query("SELECT COUNT(*) FROM platinum.{model}")

   -- Layer 3: Gold (joins + logic)
   warehouse_query("SELECT COUNT(*) FROM gold.{model}")

   -- Layer 2: Silver (cleaned + typed)
   warehouse_query("SELECT COUNT(*) FROM silver.{model}")

   -- Layer 1: Bronze (raw data)
   warehouse_query("SELECT COUNT(*) FROM bronze.{table}")

   -- Layer 0: Postgres pipeline state
   database_query("SELECT COUNT(*) FROM files WHERE group_id = '{group_id}' AND status = 'published'")
   ```

3. **Find where the data disappears or goes wrong.** The layer where counts
   diverge or values change is where the bug lives.

4. **Common root causes by divergence point:**
   - Bronze has rows, silver doesn't → silver SQL filter is too aggressive, or
     bronze is un-materialized (silver VIEW chains to DuckLake, times out)
   - Silver has rows, gold doesn't → join condition wrong, or gold reads from
     wrong silver table
   - All layers have rows but values are wrong → extraction produced bad data,
     or value mapping created incorrect canonicals
   - Data loaded 2-3x → repeated `warehouse_manage(publish)` runs without
     dedup. Check `_source_file` column for duplicates.

### Disposition
- SQL bug in silver/gold/platinum → **Fix inline** (update the SQL model)
- Extraction produced bad data → Invoke `/ingest` to fix extractor
- Value mapping wrong → Invoke `/map`
- Duplicate publish → **Fix inline** (unpublish + republish, or dedup in silver)
- Stale materialization → **Fix inline** (`warehouse_materialize` to refresh)

---

## Mode 3: Schema Mismatch

Column doesn't exist, table not found, or queries return unexpected structure.

### Diagnostic steps

1. **Get the actual schema** (Rule Zero — should already be done):
   ```
   database_query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '{table}' AND table_schema = 'public' ORDER BY ordinal_position")
   ```

2. **Compare against what was expected.** Common mismatches:
   - **Column is a computed property, not a DB column:** e.g., `is_promoted`
     is a Python `@property`, not a column. Check the ORM model if available.
   - **Migration not applied:** Column exists in code but not in the database.
     Check if there's a pending Alembic migration.
   - **Workspace schema drift:** Workspace was cloned before the column was
     added. The column exists in public schema but not in `ws_*` schema.
   - **Wrong table name:** DuckLake table names use double underscores
     (e.g., `cms__star_ratings`), MotherDuck schema uses dots
     (e.g., `bronze.cms__star_ratings`).

3. **For warehouse schema issues:**
   ```
   warehouse_query("SELECT table_schema, table_name FROM information_schema.tables WHERE table_name LIKE '%{keyword}%'")
   ```

### Disposition
- Missing migration → **Ticket** (need Alembic migration + deploy)
- Workspace schema drift → **Fix inline** (recreate workspace from fresh clone)
- Wrong table/column name → **Fix inline** (correct the query)

---

## Mode 4: Infrastructure

Timeouts, connection errors, slow queries, cold starts.

### Diagnostic steps

1. **Identify the system:**
   - Neon (Postgres) → connection pool exhaustion, SSL drops
   - MotherDuck (DuckDB) → cold start (30-47s after idle), `pg_connection_limit`
   - GCS → parquet file 404, cross-cloud latency
   - DBOS Cloud → deploy state, worker containers

2. **For slow queries:** Check if bronze is materialized (Mode 2 overlap):
   ```
   warehouse_query("SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = 'bronze'")
   ```
   `VIEW` = un-materialized = slow. Fix: `warehouse_materialize`.

3. **For connection errors:** These are almost always transient. Retry once.
   If persistent, likely Neon pool exhaustion from stale worker containers.

4. **For MotherDuck cold start:** First query after idle takes 30-47s.
   Nothing to fix — it's architectural. If it causes gateway timeouts,
   that's a ticket for timeout configuration.

### Disposition
- Un-materialized bronze → **Fix inline** (`warehouse_materialize`)
- Connection pool exhaustion → **Ticket** (need container cleanup or pool config)
- Cold start timeout → **Ticket** (gateway timeout config)
- Transient error → **Retry** (no action needed)

---

## Mode 5: Quality

Extraction produced wrong, incomplete, or truncated data.

### Diagnostic steps

1. **Get the source file and extraction output side by side:**
   ```
   -- Find the source file
   database_query("SELECT id, name, storage_key FROM files WHERE group_id = '{group_id}' AND parent_file_id IS NULL LIMIT 5")

   -- Find extraction outputs (child files)
   database_query("SELECT id, name, storage_key, status FROM files WHERE parent_file_id = '{file_id}'")
   ```

2. **Check for known extraction failure patterns:**
   - **Truncated JSON:** LLM output hit token limit on large PDFs. Look for
     incomplete rows or malformed CSV.
   - **Missing pages:** Detection may not have flagged all relevant pages.
     Check detection results:
     ```
     database_query("SELECT file_id, detected_pages FROM detection_results WHERE file_id = '{file_id}'")
     ```
   - **Wrong schema applied:** Extractor used wrong column set. Compare
     extraction CSV headers against group schema columns.

3. **Spot-check 3 values** from the source against the extraction output.
   Don't check totals or obvious values — check middle-of-table specifics.

### Disposition
- Extractor bug → Invoke `/ingest` (fix extractor, re-run with `test=True`)
- Detection missed pages → **Fix inline** (adjust detection, re-run)
- LLM truncation → **Ticket** if systemic, or split extraction into smaller chunks

---

## Creating a Linear Ticket

When the disposition is **Ticket**, create one immediately. Don't just say
"this needs a ticket" — make it.

### When to ticket vs fix inline

| Situation | Action |
|-----------|--------|
| Backend code change needed (error swallowing, wrong logic) | Ticket |
| Infrastructure config (pool size, timeout, container cleanup) | Ticket |
| SQL model fix (wrong join, missing filter) | Fix inline |
| Re-materialization needed | Fix inline |
| Re-extraction with adjusted parameters | Fix inline via `/ingest` |
| Stale workspace, needs recreation | Fix inline |
| Systemic LLM extraction failure | Ticket |

### Ticket template

```
mcp__linear__save_issue(
  title="[component]: short description of the bug",
  team="Engineering",
  description="## Bug\n\n[1-2 sentence description]\n\n## Reproduction\n\n[Exact steps or tool call that triggers the issue]\n\n## Expected\n\n[What should happen]\n\n## Actual\n\n[What happens instead]\n\n## Root cause\n\n[What you found during debugging — be specific about file/function if known]\n\n## Suggested fix\n\n[If you have one]\n\n---\n_Filed from /diagnose skill during Claude Code session_",
  priority=3,
  labels=["bug"]
)
```

**Priority guide:**
- 1 (Urgent): Production data is wrong and visible to users
- 2 (High): Silent failure causing data loss or pipeline blockage
- 3 (Normal): Bug that has a workaround
- 4 (Low): Cosmetic or minor inconvenience

After creating, report the issue identifier (e.g., `ENG-123`) to the user.

---

## Searching Prior Sessions

Before deep-diving, check if this exact issue has been debugged before:

```
search_context(query="{description of the problem}", source="claude-code", limit=5)
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

## Triage
Mode: [Silent Failure | Data Trace | Schema Mismatch | Infrastructure | Quality]

## Investigation
[What you checked, what you found at each layer]

## Root Cause
[The actual problem — be specific]

## Disposition
[Fix inline | Ticket | Invoke /ingest | Invoke /map]

## Action Taken
[What was done — SQL fix, ticket created (ENG-XXX), re-materialization, etc.]

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

3. **Trusting tool return values.** "OK" doesn't mean it worked. Verify
   independently at the destination (MotherDuck, Postgres, or GCS).

4. **Checking one layer and declaring success.** Data exists in Postgres but not
   MotherDuck? That's not "data exists." Trace all layers.

5. **Saying "this needs a ticket" without creating one.** If the disposition is
   Ticket, use `mcp__linear__save_issue` right now. Don't defer.

6. **Re-debugging known issues.** Search prior sessions first. If it's been
   diagnosed, skip to the fix.

7. **Guessing the fix without confirming the cause.** "Let me try re-materializing"
   is not debugging. Find the root cause, then fix it.
