---
name: ingest
version: 4.0.0
description: |
  Build and run data pipelines — scrape, organize, extract, validate, and publish.
  Five gates with human review at each stop. Handles both PDF/Excel extraction
  and CSV schema mapping paths. Drives the Soria platform through the `soria`
  CLI — never MCP. Also handles refresh mode for re-running existing pipelines
  when new data drops.
  Use when asked to "scrape this", "build the pipeline", "extract this data",
  "run the pipeline", or "load this into the warehouse".
  Proactively invoke this skill (do NOT scrape or extract ad-hoc) when the user
  wants to build or run a data pipeline. Gates prevent costly mistakes.
  Use after /plan, before /map or /dive. Value mapping is handled by /map. (soria-stack)
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
echo "Active environment:"
soria env status 2>&1 || echo "  (soria CLI not authed — run /env first)"
echo "---"
echo "Git state in worktree:"
git status --short 2>&1 | head -10 || echo "  (not in a worktree)"
echo "---"
echo "Checking for plan artifacts..."
ls -t ~/.soria-stack/artifacts/plan-*.md 2>/dev/null | head -3
```

**Before proceeding:** Read the `soria env status` output. If the active
environment type is `prod`, refuse to run any write step (Gate 1 onwards)
unless the user explicitly acknowledges with a phrase like "yes, I know
it's prod". For dev/preview envs, proceed normally.

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

---

## Where code lives (git-native authoring)

You're writing Python files in the env's worktree, committing them, and
letting the server pick them up. The CLI is the dispatcher — the code itself
is managed through git.

| Asset | Path (in the worktree) | How it's edited |
|---|---|---|
| Scraper | `soria/scrapers/{name}.py` | Edit the file directly. `soria scraper test NAME --url URL` tells the server to read its copy of `scrapers/{name}.py` and run it. For dev iteration, you need a local backend running against your worktree (`make run-dev`) so the server sees your edits. |
| Extractor code | `soria/extraction/` for built-in extractors; custom extractor code can be passed inline via `soria extract --code-file PATH --test` for dev iteration | Edit locally, test with `--code-file`, commit when working. Workspace-scoped extractor code lives in the database (see alembic migration `2026_04_02_make_extractor_code_workspace_scoped`) and is authored via the CLI extractor flow — for most pipelines, start with `soria extractor list SCRAPER` to see what exists. |
| dbt marts + verify seed + manifests + dive components | `frontend/src/dives/dbt/models/`, `frontend/src/dives/dbt/seeds/`, `frontend/src/dives/manifests/`, `frontend/src/dives/*.tsx` | Git-native; see `/dive` for the full layout. |
| Schema definitions | Postgres state, authored via `soria schema update` | Not file-native — state lives in the Neon branch. |
| Value mappings | Postgres state, authored via `soria value map` | Not file-native. |

**The key distinction:** scrapers and extractors are CODE and live in git.
Schemas and value mappings are DATA and live in Postgres (per env = per Neon
branch). Promotion carries both via `soria env diff` + PR merge.

## Git discipline

Every file you write or edit in this skill must be committed before moving
to the next gate. Uncommitted work is invisible to `/promote` and dies with
the worktree if you `soria env teardown` prematurely.

At each Gate, if you wrote or modified files:

```bash
git status --short
git add {specific files}
git commit -m "ingest(gate N): {what you did}"
```

Commit granularity should match gates: one commit per gate is a good default.
Don't wait until Gate 5 to commit everything — you'll lose context and make
`soria env diff` unreadable.

---

## Gate 1: Scrape (E — Extract)

**Goal:** Download all source files.

**Steps:**
1. Check if files already exist (Principle #24 — inventory first)
   ```bash
   soria list | grep -i {keyword}
   soria scraper --help   # verify the subcommand surface
   ```
2. If scraper exists and has files → skip to Gate 2
3. If scraper exists but no files → run it:
   ```bash
   soria scraper run {scraper_name}
   ```
4. If no scraper → write one (file lives in the scrapers directory — check
   `soria extractor list` for related extractors first):
   - Write the scraper code in the env's worktree
   - Test first:
     ```bash
     soria scraper test {scraper_name}
     ```
   - Save (commit in the worktree), then run:
     ```bash
     soria scraper run {scraper_name}
     ```
5. Verify: show file count, sample filenames, date range covered
   ```bash
   soria file list --scraper {scraper_name} --limit 20
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

```bash
soria scraper upload-urls {scraper_name}   # generates presigned URLs
# user uploads files via the URLs
soria scraper confirm {scraper_name}       # ingests + triggers pipeline
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
1. Examine file contents — look at headers, formats, structure across eras
   ```bash
   soria file show {file_id}
   soria file open {file_id}   # opens URL in browser for PDF/Excel inspection
   ```
2. Propose groups:
   - One group per logical collection
   - Note format eras (where column names/counts changed)
3. Create groups:
   ```bash
   soria group create {scraper_name} {group_name} --pattern "{glob}"
   soria group assign {group_id} {file_id} ...
   ```
4. Propose the extraction schema:
   - List every column with name, type, dimension vs metric
   - State what gets EXCLUDED and why (totals, derivable values — Principle #7)
   - Show options if there's a design decision
   - Apply via:
     ```bash
     soria schema update {group_id}
     ```

**Two paths depending on file type:**

- **PDF/Excel:** Need detection + extraction pipeline. Schema defines what to
  extract. Propose columns based on sampling the source files.
- **CSV:** Already structured. Schema maps CSV headers to canonical column names.
  Use:
  ```bash
  soria schema mappings-read {group_id}
  soria schema mappings-update {group_id}   # apply fixes
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
     ```bash
     soria detect {group_id} --files {file_id_1},{file_id_2},{file_id_3}
     soria extract {group_id} --files {file_id_1},{file_id_2},{file_id_3}
     ```
   - **CSV:** Schema mapping already tested in Gate 2. Run validation:
     ```bash
     soria validate {group_id} --files {file_id_1},{file_id_2},{file_id_3}
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

4. If mismatches: diagnose, fix extractor, re-run samples
5. Check format-era handling: does the same extractor work across all 3?

### ⛔ GATE 3 STOP
All 3 samples must pass verification. If ANY mismatch, fix and re-verify.
Wait for human approval.

---

## Gate 4: Full Extract (T — Transform, part 3)

**Goal:** Run extraction on all files and validate at scale.

**Steps:**
1. Run extraction on all files in the group:
   ```bash
   soria extract {group_id}
   ```
2. Monitor for failures — never silently skip a file
3. Run validation:
   ```bash
   soria validate {group_id}
   ```
4. Post-extraction checks:
   - Total extracted vs total in group (expect 100% or explain gaps)
   - Row counts per file — reasonable? Any 0-row files?
   - Schema consistency — same columns across all outputs?
   - NULL rate scan — any unexpected NULL spikes?
5. If failures > 5%: stop, diagnose, fix, re-run failed files

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

**Goal:** Publish to the warehouse bronze layer in the current env.

**Steps:**
1. Publish to bronze in the active env (never prod directly):
   ```bash
   soria warehouse publish {group_id}
   ```
2. **Check warehouse status:**
   ```bash
   soria warehouse status {group_id}
   ```
3. **Verify row count landed:**
   ```bash
   soria warehouse query "SELECT COUNT(*) FROM bronze.{table_name}"
   ```
   Compare against the extraction row count. If they don't match, something
   went wrong.
4. **Materialize if needed** (for perf — bronze views chain through DuckLake
   at ~2-3s per query; materialized tables are instant):
   ```bash
   soria warehouse materialize bronze.{table_name}
   ```
5. Additional publish verification:
   - Sample query returns expected data
   - No NULL primary keys
6. If /plan specified L-phase verification criteria, run those checks now

**Present to human:**
```
Published to env: prickle-bottle
Table: bronze.kaufman_hall__hospital_performance_metrics
Rows published: 456,789
Materialized: ✅ (BASE TABLE, 456,789 rows — matches)
Sample query: SELECT * WHERE year = 2024 LIMIT 5 → looks correct
```

### ⛔ GATE 5 STOP
Show the publish results. The pipeline is not "done" until verified. Note:
value mapping is handled by `/map` (separate skill). Dives by `/dive`.

**Suggest next step:** If values need normalization → `/map`. If data is clean
and ready for a dive → `/dive`.

---

## Refresh Mode

When new data drops for an existing pipeline:

1. **Check what's new:** `soria file list --scraper {name}` vs previous run
2. **Run existing extractor on new files only** — don't re-extract everything:
   ```bash
   soria extract {group_id} --files {new_file_ids}
   soria validate {group_id} --files {new_file_ids}
   ```
3. **Re-publish:** Incremental add to bronze:
   ```bash
   soria warehouse publish {group_id}
   ```
4. **Quick verify:** Spot-check new data points

Refresh gates are softer — the pipeline is already proven. But flag anomalies:
- New columns that didn't exist before
- Significant row count changes
- Values that break established patterns

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/ingest-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Ingest Report: [Dataset Name]

## Environment
[Active soria env]

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
- Bronze: [table name, row count, materialized yes/no]

## Next Steps
- [ ] /map — if value mapping needed
- [ ] /dive — if ready to build a dive

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

---

## When Things Fail

When extraction, publish, or scraper runs fail or time out, invoke `/diagnose`.
Don't retry blindly. The diagnose skill has the failure catalog for all
subsystems (Neon, MotherDuck, S3 / managed DuckLake, DBOS Cloud, Durable
Object event relay, Clerk, WASM, PG wire proxy).

---

## Anti-Patterns

1. **Skipping Gate 3.** Test on 3 first. Always. Every session where this was
   skipped wasted time on broken extractors running on all files.

2. **Silent failures.** A file that fails extraction is not OK to skip.
   Every file must extract or be explicitly flagged.

3. **Publishing directly to prod.** Always work in a dev env first. Verify.
   Let `/promote` handle the PR-to-prod path.

4. **Editing CSVs instead of fixing extractors.** Fix the extraction, not the
   output (Principle #6).

5. **Un-materialized bronze.** If bronze isn't materialized, queries take 40
   seconds instead of 0.02. Materialize at Gate 5.

6. **Doing value mapping here.** Value mapping is `/map`. This skill gets data
   into the warehouse. `/map` normalizes it.

7. **Using raw HTTP libraries.** Never import `curl_cffi`, `requests`, or
   `httpx` in scraper code. Use `get_html()` / `get_json()`.

8. **Manual upload as a workaround for scraping failures.** If a scraper fails,
   the fix is to fix the scraper — not to manually upload files. Manual upload
   creates a one-time pipeline that breaks the next time data updates. Only
   acceptable when the human explicitly asks or the source genuinely has no
   scrapable URL.

9. **Republishing after a schema change without `--force`.** If the warehouse
   table already exists with a different schema (e.g., you changed from
   wide-format to long-format), `soria warehouse publish` fails with
   "Table does not have a column with name 'x'". Re-publish with `--force` —
   safe when the schema change is intentional, but only after completing all
   downstream model updates (see `/dive` anti-patterns).

10. **Running without confirming the active env.** The preamble exits if env
    is unset or prod. If you bypassed it, you're about to write to the wrong
    place.
