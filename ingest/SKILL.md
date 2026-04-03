---
name: ingest
version: 3.0.0
description: |
  Build and run data pipelines — scrape, organize, extract, and publish.
  Five gates with human review at each stop.
  Handles both PDF/Excel extraction and CSV schema mapping paths.
  Also handles refresh mode for re-running existing pipelines when new data drops.
  Use when asked to "scrape this", "build the pipeline", "extract this data",
  "run the pipeline", or "load this into the warehouse".
  Proactively invoke this skill (do NOT scrape or extract ad-hoc) when the user
  wants to build or run a data pipeline. Gates prevent costly mistakes.
  Use after /plan, before /map or /dashboard. Value mapping is handled by /map. (soria-stack)
benefits-from: [plan]
allowed-tools:
  - sumo_*
  - Read
  - Bash
  - Write
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "SKILL: ingest"
echo "---"
echo "Checking for plan artifacts..."
ls -t ~/.soria-stack/artifacts/plan-*.md 2>/dev/null | head -3
```

Read `ETHOS.md` from this skill pack. All principles apply during ingestion.

**Check for prior plan:** If a plan artifact exists, read it — it has the ETVLR
phase status, verification criteria per phase, and sequencing. If no plan exists,
warn: "No /plan found. Consider running /plan first to avoid building the wrong thing."

**Pipeline framing:** This skill covers the **E, T, and L** phases of ETVLR.
Value mapping (V) is handled by `/map`. Representation (R) is handled by `/dashboard`.

## Skill routing (always active)

When the user's intent shifts mid-conversation, invoke the matching skill —
do NOT continue ad-hoc:

- User asks "what do we have" mid-pipeline → invoke `/status`
- User wants to revisit the plan → invoke `/plan`
- User says "now map the values" or values need normalization → invoke `/map`
- User wants to build SQL/dashboard on the published data → invoke `/dashboard`
- User wants to verify extraction output → invoke `/verify` (Mode 1: Pipeline)
- User wants to profile the data before modeling → invoke `/verify` (Mode 5)

**After /ingest completes:**
- If values need normalization → suggest `/map`
- If data is clean → suggest `/dashboard`
- Always suggest `/verify` to confirm extraction quality
- **NEVER promote to prod from here.** If the user says "push to prod", invoke `/promote`.

---

# /ingest — "Build the pipeline with gates"

You are a pipeline builder. Your job is to scrape, organize, extract, and
publish data — but NEVER skip a gate. Each gate is a checkpoint where the human
must see and approve the work before you proceed.

---

## Gate 1: Scrape (E — Extract)

**Goal:** Download all source files.

**Steps:**
1. Check if files already exist (Principle #24 — inventory first)
2. If scraper exists and has files → skip to Gate 2
3. If scraper exists but no files → run it
4. If no scraper → write one:
   - Write the scraper code
   - Test first (`test=True`)
   - Save, then run
5. Verify: show file count, sample filenames, date range covered

### HTTP waterfall rule

**Always use `get_html()` / `get_json()`.** They auto-escalate through three tiers:
1. Direct HTTP request
2. Residential proxy
3. Browser Use CDP (stealth browser — bypasses Cloudflare, DataDome, AWS WAF)

`.gov` domains skip proxy (tunnels always fail on .gov) and go direct → Browser Use.

**Never import `curl_cffi`, `requests`, or `httpx` directly.** You lose all fallback
protection. A scraper that uses raw HTTP will die on the first bot-protection hit
instead of escalating. This has caused real failures (TN Medicaid: SSL reset killed
`curl_cffi`, but `get_html()` would have auto-escalated to Browser Use and worked).

### BI dashboard sources (Tableau, Power BI)

If the URL points to a BI dashboard (`tableau.*`, `app.powerbi.com`, `powerbigov.us`,
or similar), the data lives behind proprietary API endpoints — not in downloadable files.

**Approach:**
1. **Detect platform** from the URL pattern. If ambiguous, open in Chrome DevTools,
   screenshot, and check XHR endpoints to identify the platform.
2. **Recon with Chrome DevTools** — navigate to the URL, open the Network tab, and
   identify the data endpoints:
   - Tableau: look for `bootstrapSession` responses (VizQL protocol)
   - Power BI: look for `querydata`, `conceptualschema`, `modelsAndExploration` responses
3. **Write a scraper** that replays those data endpoints using `get_html()` / `get_json()`.
   Most BI dashboards work with plain HTTP — no `needs_browser` needed. The scraper
   parses the protocol response and produces CSV output.
4. If plain HTTP doesn't work (auth walls, session tokens), use `needs_browser = True`
   with `self.page.evaluate()` to replay queries from inside the browser context where
   cookies and auth "just work."

The rest of the pipeline (Gates 2-5) is the same as any other source.

**Present to human:**
```
Scraper: cms_hospital_cost_report
Files downloaded: 47
Date range: 2011-2024
File types: CSV (100%)
Sample: cms_hospital_cost_report_2024.csv, ...
```

**Verification (from /plan):** Check against the plan's E-phase criteria. E.g.,
"50 states have filings" → verify state count in filenames.

### ⛔ GATE 1 STOP
Show the inventory. Wait for approval before organizing.

---

## Gate 2: Organize + Schema (T — Transform, part 1)

**Goal:** Group files logically and propose the extraction schema.

**Steps:**
1. Examine file contents — look at headers, formats, structure across eras
2. Propose groups:
   - One group per logical collection
   - Note format eras (where column names/counts changed)
3. Create groups with file patterns
4. Propose the extraction schema:
   - List every column with name, type, dimension vs metric
   - State what gets EXCLUDED and why (totals, derivable values — Principle #7)
   - Show options if there's a design decision

**Two paths depending on file type:**

- **PDF/Excel:** Need detection + extraction pipeline. Schema defines what to
  extract. Propose columns based on sampling the source files.
- **CSV:** Already structured. Schema maps CSV headers to canonical column names.
  Use `schema_manage(operation="auto_map")` for initial matching, then fix
  unmapped columns manually.

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
   - **PDF/Excel:** Run detection + extraction
   - **CSV:** Run schema mapping
3. For each extracted file, compare against the source (Principle #11):
   - Pull 10 specific values from the source document
   - Find the same values in the extracted output
   - Show comparison table with match/mismatch per value

   ```
   File: cms_hospital_cost_report_2024.csv (newest)
   | Field | Source | Extracted | Match |
   |-------|--------|-----------|-------|
   | CCN 050454 net_revenue | $1,234,567 | 1234567 | yes |
   | CCN 050454 total_beds | 382 | 382 | yes |
   Result: 10/10 match
   ```

4. If mismatches: diagnose, fix extractor, re-run samples
5. Check format-era handling: does the same extractor work across all 3?

**For Level 5 sources (from /plan):** The Transform step is custom code, not a
standard extractor. Run on 3 entities and verify the output.

### ⛔ GATE 3 STOP
All 3 samples must pass verification. If ANY mismatch, fix and re-verify.
Wait for human approval.

---

## Gate 4: Full Extract (T — Transform, part 3)

**Goal:** Run extraction on all files and validate at scale.

**Steps:**
1. Run extraction on all files in the group
2. Monitor for failures — never silently skip a file
3. Post-extraction validation:
   - Total extracted vs total in group (expect 100% or explain gaps)
   - Row counts per file — reasonable? Any 0-row files?
   - Schema consistency — same columns across all outputs?
   - NULL rate scan — any unexpected NULL spikes?
4. If failures > 5%: stop, diagnose, fix, re-run failed files

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

**Goal:** Publish to the warehouse and create the bronze model.

**Steps:**
1. Publish to bronze in the workspace (never directly to production)
2. **Materialize the bronze table** (Principle #4 — always materialize):
   ```
   warehouse_materialize(model_name="bronze.{table_name}", materialize=True)
   ```
   If working in a workspace, pass the workspace environment:
   ```
   warehouse_materialize(model_name="bronze.{table_name}", materialize=True, environment="ws_{workspace_schema}")
   ```
3. **Verify materialization landed** — don't trust the return value alone:
   ```
   warehouse_query("SELECT COUNT(*) FROM bronze.{table_name}")
   ```
   Compare against the extraction row count. If they don't match, something went wrong.
4. Additional publish verification:
   - Sample query returns expected data
   - No NULL primary keys
5. If /plan specified L-phase verification criteria, run those checks now

**Present to human:**
```
Published to workspace: ws_abc123
Table: kaufman_hall__hospital_performance_metrics
Rows published: 456,789
Materialized: ✅ (TABLE, 456,789 rows — matches)
Sample query: SELECT * WHERE year = 2024 LIMIT 5 → looks correct
```

### ⛔ GATE 5 STOP
Show the publish results. The pipeline is not "done" until verified. Note: value
mapping is handled by /map (separate skill). SQL models by /dashboard.

**Suggest next step:** If values need normalization → /map. If data is clean
and ready for SQL → /dashboard.

---

## Refresh Mode

When new data drops for an existing pipeline:

1. **Check what's new:** Compare current files vs last run
2. **Run existing extractor on new files only** — don't re-extract everything
3. **Validate new extractions:** Spot-check new files against source
4. **Re-publish:** Incremental add to bronze
5. **Quick verify:** Spot-check new data points

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
- Bronze: [table name, row count, materialized yes/no]

## Next Steps
- [ ] /map — if value mapping needed
- [ ] /dashboard — if ready for SQL models

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

---

## When Things Fail: Check Logfire

When extraction, publish, or scraper runs fail or time out, **check Logfire
before retrying blindly.** Use `logfire_query_run` to query recent traces.

### Common failure patterns

| Symptom | Logfire query | Root cause |
|---------|-------------|------------|
| Extraction times out | `SELECT * FROM spans WHERE span_name LIKE '%extract%' AND status = 'error' ORDER BY start DESC LIMIT 10` | GCS download overload, server restart under load, or Gemini API rate limit |
| Scraper 504 / timeout | Look for `Browser attempt failed: Timeout 30000ms exceeded` | Site WAF blocking headless browser, or site is down |
| Publish hangs | Look for `_get_group_context` completing but next step stalling | MotherDuck/DuckDB connection hanging — retry usually works |
| GCS 400 INVALID_ARGUMENT | Look for `ClientError 400` with auto-retry | Transient — DBOS auto-retries 3x, usually self-heals |
| DBOS reinitializing repeatedly | Multiple `DBOS init` spans in short window | Server overwhelmed by concurrent operations — back off |

### What to do
1. Query Logfire for the specific error
2. Identify the root cause from the trace (don't guess)
3. If transient (GCS 400, timeout): wait 2 min and retry
4. If structural (missing schema, bad UUID): fix the input and retry
5. If persistent (site blocking, DuckDB hanging): escalate to human

---

## Anti-Patterns

1. **Skipping Gate 3.** Test on 3 first. Always. Every session where this was
   skipped wasted time on broken extractors running on all files.

2. **Silent failures.** A file that fails extraction is not OK to skip.
   Every file must extract or be explicitly flagged.

3. **Publishing directly to production.** Always workspace first. Verify. Promote.

4. **Editing CSVs instead of fixing extractors.** Fix the extraction, not the
   output (Principle #6).

5. **Un-materialized bronze.** If bronze isn't materialized, queries take 40
   seconds instead of 0.02. Materialize at Gate 5. Always.

6. **Doing value mapping here.** Value mapping is /map. This skill gets data
   into the warehouse. /map normalizes it. Don't conflate the two.

7. **Using raw HTTP libraries.** Never import `curl_cffi`, `requests`, or `httpx`
   in scraper code. Use `get_html()` / `get_json()` — they have the proxy and
   Browser Use escalation built in. Raw HTTP bypasses all fallback protection.
