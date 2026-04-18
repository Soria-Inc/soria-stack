---
name: ingest
version: 5.0.0
description: |
  Build and run data pipelines — scrape, organize, extract, validate, and publish.
  Five gates with human review at each stop. Handles both PDF/Excel extraction
  and CSV schema mapping paths. Drives the Soria platform through the
  `mcp__soria__*` MCP tool namespace — never a CLI. Ingestion writes to
  shared Postgres + `soria_duckdb_staging`; every write is soft-delete
  reversible via the `PipelineEvent` audit trail. Also handles refresh mode
  for re-running existing pipelines when new data drops.
  Use when asked to "scrape this", "build the pipeline", "extract this data",
  "run the pipeline", or "load this into the warehouse".
  Proactively invoke this skill (do NOT scrape or extract ad-hoc) when the user
  wants to build or run a data pipeline. Gates prevent costly mistakes.
  Use after /plan, before /map or /dive. Value mapping is handled by /map.
  (soria-stack)
benefits-from: [plan]
allowed-tools:
  - Read
  - Bash
  - Write
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: ingest"
echo "---"
echo "Git state (soria-2):"
git status --short 2>&1 | head -10 || echo "  (not in soria-2 checkout)"
echo "---"
echo "Checking for plan artifacts..."
ls -t ~/.soria-stack/artifacts/plan-*.md 2>/dev/null | head -3
```

Also run `mcp__soria__pipeline_activity(limit=10)` to see the last ~10
writes across scrapers/groups/files/schemas — ingestion lands on shared
state, so you should know what other people touched before you start.

Read `ETHOS.md`. All principles apply during ingestion.

**Check for prior plan:** If a plan artifact exists, read it — it has the ETVLR
phase status, verification criteria per phase, and sequencing. If no plan exists,
warn: "No /plan found. Consider running /plan first to avoid building the wrong thing."

**Pipeline framing:** This skill covers the **E, T, and L** phases of ETVLR.
Value mapping (V) is handled by `/map`. Representation (R) is handled by `/dive`.

## Skill routing (always active)

When the user's intent shifts mid-conversation, invoke the matching skill —
do NOT continue ad-hoc:

- User asks "what do we have" mid-pipeline → invoke `/status`
- User wants to revisit the plan → invoke `/plan`
- User says "now map the values" or values need normalization → invoke `/map`
- User wants to build a dive on the published data → invoke `/dive`
- User wants to verify extraction output → invoke `/verify` (Mode 1: Pipeline)

**After /ingest completes:**
- If values need normalization → suggest `/map`
- If data is clean → suggest `/dive`
- Always suggest `/verify` to confirm extraction quality
- **NEVER promote to prod from here.** If the user says "push to prod", invoke `/promote`.

---

# /ingest — "Build the pipeline with gates"

You are a pipeline builder. Your job is to scrape, organize, extract, validate,
and publish data — but NEVER skip a gate. Each gate is a checkpoint where the
human must see and approve the work before you proceed.

All writes land on shared state (`soria_duckdb_staging` + Postgres). Every
write is soft-delete reversible — but that's a safety net, not a license to
move fast. Use `mcp__soria__pipeline_activity` to surface recent changes so
you don't stomp on someone else's in-flight work.

---

## Where code lives

Scrapers and extractors are **code** stored in the shared Postgres through
MCP tools (`scraper_manage`, `extractor_manage`) — not files in your local
git. Iterate via the tools' `test=True` flags, which let you pass inline
code and dry-run without writing to shared state.

| Asset | Where | How it's edited |
|---|---|---|
| Scraper | Postgres (`scrapers` table) | `mcp__soria__scraper_manage(action="save", name=..., code=...)`, then `mcp__soria__scraper_run(name=..., test=True)` to dry-run. Save for real when it works. |
| Extractor | Postgres (`extractors` table, workspace-scoped) | `mcp__soria__extractor_manage(action="save", ...)` + `mcp__soria__extraction_run(..., test=True, code=...)` for iteration. |
| Schema columns | Postgres | `mcp__soria__schema_manage` |
| Schema (CSV) mappings | Postgres | `mcp__soria__schema_mappings` |
| Value mappings | Postgres | `mcp__soria__value_manage` (handled by `/map`) |
| dbt marts + verify seed + manifests + dive components | Git (`frontend/src/dives/...`) | See `/dive`. |

**Key distinction:** scraper/extractor code is owned by Postgres (so everyone
shares the latest version). Marts/manifests/React are owned by git (so dive
changes ship via PR, not direct edits).

## Reversibility

Every ingestion write sets `deleted_at` on soft-delete, never hard-deletes.
Unpublishing a group, deleting a file, re-extracting over an old CSV — all
reversible via `mcp__soria__database_mutate` setting `deleted_at = NULL`
(respect `SOFT_DELETE_CASCADES`).

When in doubt, check `mcp__soria__pipeline_history(entity_id=...)` to see
the sequence of events on a row.

---

## Gate 1: Scrape (E — Extract)

**Goal:** Download all source files.

**Steps:**
1. Check if files already exist (Principle #24 — inventory first)
   ```
   mcp__soria__database_query(sql="
     SELECT name, (SELECT COUNT(*) FROM files WHERE scraper_id = s.id) AS files
     FROM scrapers s
     WHERE name ILIKE '%{keyword}%'
   ")
   ```
2. If scraper exists and has files → skip to Gate 2.
3. If scraper exists but no files → run it:
   ```
   mcp__soria__scraper_run(name="{scraper_name}")
   ```
4. If no scraper → write one. Iterate with `test=True`:
   ```
   mcp__soria__scraper_run(name="{scraper_name}", test=True, code="""
     from soria.scrapers.core.base_scraper import SimpleScraper, get_html, ...
     class MyScraper(SimpleScraper):
         url = "..."
         def discover_files(self): ...
   """)
   ```
   When it works, save:
   ```
   mcp__soria__scraper_manage(action="save", name="{scraper_name}", code=...)
   ```
   Then run for real:
   ```
   mcp__soria__scraper_run(name="{scraper_name}")
   ```
5. Verify: show file count, sample filenames, date range:
   ```
   mcp__soria__file_query(scraper="{scraper_name}", limit=20)
   ```

### HTTP waterfall rule

**Always use `get_html()` / `get_json()`.** They auto-escalate through three tiers:
1. Direct HTTP request
2. Residential proxy
3. Browser Use CDP (stealth browser — bypasses Cloudflare, DataDome, AWS WAF)

`.gov` domains skip proxy (tunnels always fail on .gov) and go direct → Browser Use.

**Never import `curl_cffi`, `requests`, or `httpx` directly.** You lose all fallback
protection. A scraper that uses raw HTTP will die on the first bot-protection hit
instead of escalating.

### BI dashboard sources (Tableau, Power BI)

If the URL points to a BI dashboard (`tableau.*`, `app.powerbi.com`,
`powerbigov.us`, or similar), the data lives behind proprietary API endpoints.

**Approach:**
1. **Detect platform** from the URL pattern. If ambiguous, open in Chrome
   DevTools, screenshot, and check XHR endpoints.
2. **Recon with Chrome DevTools** — navigate to the URL, open the Network tab,
   identify the data endpoints:
   - Tableau: look for `bootstrapSession` responses (VizQL protocol)
   - Power BI: look for `querydata`, `conceptualschema`, `modelsAndExploration`
3. **Write a scraper** that replays those data endpoints using `get_html()` /
   `get_json()`. Most BI dashboards work with plain HTTP.
4. If plain HTTP doesn't work (auth walls, session tokens), use
   `needs_browser = True` with `self.page.evaluate()` to replay queries from
   inside the browser context.

### Manual upload path

If the scraper is genuinely blocked (MFA portal, emailed reports), use the
manual upload flow:

```
mcp__soria__scraper_upload_urls(scraper="{name}", count=N)   # presigned URLs
# user uploads files via the URLs
mcp__soria__scraper_confirm_uploads(scraper="{name}")         # ingest + pipeline
```

**Never pivot to manual upload on your own.** If the scraper is blocked, say
so and present the options.

**Present to human:**
```
Scraper: cms_hospital_cost_report
Files downloaded: 47
Date range: 2011-2024
File types: CSV (100%)
Sample: cms_hospital_cost_report_2024.csv, ...
```

**Verification (from /plan):** Check against the plan's E-phase criteria.

### ⛔ GATE 1 STOP
Show the inventory. Wait for approval before organizing.

---

## Gate 2: Organize + Schema (T — Transform, part 1)

**Goal:** Group files logically and propose the extraction schema.

**Steps:**
1. Examine file contents — look at headers, formats, structure across eras:
   ```
   mcp__soria__file_query(file_id="{id}")            # metadata + storage key
   mcp__soria__file_query(file_id="{id}", open=True) # presigned URL to inspect
   ```
2. Propose groups:
   - One group per logical collection
   - Note format eras (where column names/counts changed)
3. Create groups:
   ```
   mcp__soria__group_manage(action="create", scraper="{name}", name="{group_name}", pattern="{glob}")
   mcp__soria__group_manage(action="assign", group_id="{id}", file_ids=["..."])
   ```
4. Propose the extraction schema:
   - List every column with name, type, dimension vs metric
   - State what gets EXCLUDED and why (totals, derivable values — Principle #7)
   - Show options if there's a design decision
   - Apply via:
     ```
     mcp__soria__schema_manage(action="update", group_id="{id}", columns=[...])
     ```

**Two paths depending on file type:**

- **PDF/Excel:** Need detection + extraction. Schema defines what to extract.
  Propose columns based on sampling the source files.
- **CSV:** Already structured. Schema maps CSV headers to canonical column names:
   ```
   mcp__soria__schema_mappings(action="read", group_id="{id}")
   mcp__soria__schema_mappings(action="update", group_id="{id}", mappings={...})
   ```

**Pushback guidance:** Don't just present what's in the file. Challenge:
- "These 3 columns are derivable. I'd exclude them. Here's the math."
- "15 metric columns — I'd extract wide and unpivot in SQL (Principle #3)."
- "You asked for 5 groups but 1 group with era handling is simpler."

### ⛔ GATE 2 STOP
Schema design is a conversation (Principle #8). Present proposals with tradeoffs.
Take a position. Do NOT proceed until the human approves.

---

## Gate 3: Sample Extract (T — Transform, part 2)

**Goal:** Extract 3 files and verify against sources. Principle #2 in action.

**Steps:**
1. Pick 3 files: **oldest, newest, mid-history**
   - If format eras exist, pick one from each era
2. Run extraction on each:
   - **PDF/Excel:**
     ```
     mcp__soria__detection_run(group_id="{id}", file_ids=["...","...","..."])
     mcp__soria__extraction_run(group_id="{id}", file_ids=["...","...","..."])
     ```
   - **CSV:** Schema mapping already tested in Gate 2. Run validation:
     ```
     mcp__soria__validation_run(group_id="{id}", file_ids=["...","...","..."])
     ```
3. For each extracted file, compare against the source (Principle #11):
   - Pull 10 specific values from the source document
   - Find the same values in the extracted output
   - Show comparison table with match/mismatch per value

   ```
   File: cms_hospital_cost_report_2024.csv (newest)
   | Field | Source | Extracted | Match |
   |-------|--------|-----------|-------|
   | CCN 050454 net_revenue | $1,234,567 | 1234567 | ✅ |
   | CCN 050454 total_beds | 382 | 382 | ✅ |
   Result: 10/10 match
   ```

4. If mismatches: diagnose, fix extractor, re-run samples.
5. Check format-era handling: does the same extractor work across all 3?

### ⛔ GATE 3 STOP
All 3 samples must pass verification. If ANY mismatch, fix and re-verify.
Wait for human approval.

---

## Gate 4: Full Extract (T — Transform, part 3)

**Goal:** Run extraction on all files and validate at scale.

**Steps:**
1. Run extraction on all files in the group:
   ```
   mcp__soria__extraction_run(group_id="{id}")
   ```
2. Monitor for failures — never silently skip a file.
3. Run validation:
   ```
   mcp__soria__validation_run(group_id="{id}")
   ```
4. Post-extraction checks:
   - Total extracted vs total in group (expect 100% or explain gaps)
   - Row counts per file — reasonable? Any 0-row files?
   - Schema consistency — same columns across all outputs?
   - NULL rate scan — any unexpected NULL spikes?
5. If failures > 5%: stop, diagnose, fix, re-run failed files.

**Present to human:**
```
Extraction complete: 47/47 files (100%)
Total rows: 456,789
Row count range: 5,271 (2011) to 7,203 (2024) — increasing, expected
Schema: consistent (116 columns)
NULL rate: <1% on metrics, 3.2% on rural_urban (expected)
Failures: 0
```

### ⛔ GATE 4 STOP
Show summary statistics. Wait for approval before publishing.

---

## Gate 5: Publish + Verify (L — Load)

**Goal:** Publish to the warehouse bronze layer in `soria_duckdb_staging`.

**Steps:**
1. Publish to bronze (writes `soria_duckdb_staging.bronze.{table}`):
   ```
   mcp__soria__warehouse_manage(action="publish", group_id="{id}")
   ```
2. Verify row count landed:
   ```
   mcp__soria__warehouse_query(sql="SELECT COUNT(*) FROM soria_duckdb_staging.bronze.{table_name}")
   ```
   Compare against the extraction row count. If they don't match, something
   went wrong — flip back with `mcp__soria__warehouse_manage(action="unpublish", ...)`
   (soft-delete) and diagnose.
3. Sample query returns expected data. No NULL primary keys.
4. If /plan specified L-phase verification criteria, run those checks now.

**Present to human:**
```
Published to: soria_duckdb_staging.bronze.kaufman_hall__hospital_performance_metrics
Rows: 456,789 (matches extraction count)
Sample query: SELECT * WHERE year = 2024 LIMIT 5 → looks correct
```

### ⛔ GATE 5 STOP
Show the publish results. The pipeline is not "done" until verified. Note:
value mapping is handled by `/map` (separate skill). Dives by `/dive`.

**Suggest next step:** If values need normalization → `/map`. If data is
clean and ready for a dive → `/dive`. If you want to move bronze files to
prod MotherDuck → `/promote` (PR-gated).

---

## Refresh Mode

When new data drops for an existing pipeline:

1. **Check what's new:**
   ```
   mcp__soria__file_query(scraper="{name}", since="{last_run_timestamp}")
   ```
2. **Run existing extractor on new files only** — don't re-extract everything:
   ```
   mcp__soria__extraction_run(group_id="{id}", file_ids=[new_ids])
   mcp__soria__validation_run(group_id="{id}", file_ids=[new_ids])
   ```
3. **Re-publish:** Incremental add to bronze:
   ```
   mcp__soria__warehouse_manage(action="publish", group_id="{id}")
   ```
4. **Quick verify:** Spot-check new data points.

Refresh gates are softer — the pipeline is already proven. But flag anomalies:
- New columns that didn't exist before
- Significant row count changes
- Values that break established patterns

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/ingest-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Ingest Report: [Dataset Name]

## Pipeline Summary
- Scraper: [name, ID]
- Files: [count, types, date range]
- Groups: [names, file counts]
- Schema: [column count, key columns]

## Extraction Results
- Files extracted: [X/Y]
- Total rows: [count]
- Spot check: [X/X values match]

## Tables Published
- soria_duckdb_staging.bronze.[table name] — [row count]

## Next Steps
- [ ] /map — if value mapping needed
- [ ] /dive — if ready to build a dive
- [ ] /promote — when ready to move bronze files to prod MotherDuck

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

---

## When Things Fail

When extraction, publish, or scraper runs fail or time out, invoke `/diagnose`.
Don't retry blindly. The diagnose skill has the failure catalog for all
subsystems (MotherDuck, GCS, DBOS Cloud, Durable Object event relay, Clerk,
WASM, PG wire proxy).

---

## Anti-Patterns

1. **Skipping Gate 3.** Test on 3 first. Always. Every session where this was
   skipped wasted time on broken extractors running on all files.

2. **Silent failures.** A file that fails extraction is not OK to skip.
   Every file must extract or be explicitly flagged.

3. **Skipping the `test=True` dry-run.** For scrapers and extractors, always
   dry-run with inline code before `scraper_manage(action="save", ...)`.
   Saving broken code to shared state means everyone else gets your bug.

4. **Editing CSVs instead of fixing extractors.** Fix the extraction, not the
   output (Principle #6).

5. **Doing value mapping here.** Value mapping is `/map`. This skill gets data
   into the warehouse. `/map` normalizes it.

6. **Using raw HTTP libraries.** Never import `curl_cffi`, `requests`, or
   `httpx` in scraper code. Use `get_html()` / `get_json()`.

7. **Manual upload as a workaround for scraping failures.** If a scraper fails,
   the fix is to fix the scraper — not to manually upload files. Manual upload
   creates a one-time pipeline that breaks the next time data updates. Only
   acceptable when the human explicitly asks or the source genuinely has no
   scrapable URL.

8. **Republishing after a schema change without `force=True`.** If the warehouse
   table already exists with a different schema, `warehouse_manage(action="publish")`
   fails. Re-publish with `force=True` — safe when the schema change is
   intentional, but only after completing all downstream model updates (see
   `/dive` anti-patterns).

9. **Ignoring recent pipeline activity.** Before any write, check
   `mcp__soria__pipeline_activity` — you may be about to undo someone else's
   work or race a concurrent run.

10. **Promoting bronze files to prod from here.** `/promote` handles the
    PR-gated file-level manifest. Do not call `mcp__soria__warehouse_promote`
    outside `/promote`.
