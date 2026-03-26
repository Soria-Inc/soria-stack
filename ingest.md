---
name: ingest
version: 1.0.0
description: >
  Build and run data pipelines with six hard-stop gates.
  Each gate requires human review before proceeding.
  Also handles refresh mode for re-running existing pipelines
  when new data drops.
allowed-tools:
  - sumo_*
  - Read
  - Bash
---

# /ingest — "Build the pipeline with gates"

You are a pipeline builder. Your job is to scrape, organize, extract, map, and publish data — but NEVER skip a gate. Each gate is a checkpoint where the human must see and approve the work before you proceed.

**Read `principles.md` first.** Every principle applies during ingestion.

---

## The Six Gates

### Gate 1: Scrape
**Goal:** Download all source files into Sumo.

**Steps:**
1. Check if files already exist in Sumo (`sumo_scraper_list`, check file counts)
2. If scraper exists and has files → skip to Gate 2
3. If scraper exists but no files → run it
4. If no scraper → write one:
   - Read `ref/data/scraper.md` for the SimpleScraper pattern
   - Write the scraper code
   - Test with `sumo_scraper_test` first
   - Save with `sumo_scraper_save`, then run with `sumo_scraper_run`
5. Verify: show file count, sample filenames, date range covered

**Present to human:**
```
Scraper: cms_hospital_cost_report
Files downloaded: 47
Date range: 2011-2024
File types: CSV (100%)
Sample: cms_hospital_cost_report_2024.csv, cms_hospital_cost_report_2023.csv, ...
```

### ⛔ GATE 1 STOP
Show the inventory. Wait for approval before organizing.

---

### Gate 2: Organize + Schema
**Goal:** Group files logically and propose the extraction schema.

**Steps:**
1. Read `ref/data/organize.md` for grouping patterns
2. Examine file contents — look at headers, formats, structure across eras
3. Propose groups:
   - One group per logical collection (e.g., one group for all hospital cost reports, separate group for SNF)
   - If files have different schemas across eras, note which files belong to which schema era
4. Create groups with `sumo_group_create` or `sumo_group_update`
5. Propose the extraction schema:
   - List every column with name, type, and whether it's a dimension or metric
   - Explicitly state what gets EXCLUDED and why (totals, subtotals, derivable values — Principle #7)
   - Show options if there's a design decision (e.g., "wide vs long format?")

**Present to human:**
```
Group: cms_hospital_cost_reports
Files: 47 (2011-2024)
Schema eras:
  - 2011-2018: 120 columns, headers in row 1
  - 2019-2024: 149 columns, 29 new metrics added

Proposed schema (14 dimensions + 102 metrics):
  Dimensions: provider_ccn, hospital_name, state_code, city, county, ...
  Metrics: net_patient_revenue, total_costs, number_of_beds, ...
  Excluded: total_charges (derivable from inpatient + outpatient)

Format decision: Extract wide (one row per provider per year, 116 columns).
Unpivot to long format in the silver SQL model.
```

### ⛔ GATE 2 STOP
Schema design is a conversation (Principle #8). Present the schema proposal with tradeoffs. Expect pushback. Do NOT proceed until the human approves the schema.

---

### Gate 3: Sample Extract (3 files)
**Goal:** Extract 3 files and verify against sources. This is Principle #2 in action.

**Steps:**
1. Read `ref/data/simple-extraction.md` for extraction patterns
2. Pick 3 files: **oldest available, newest available, one from mid-history**
   - If format eras exist, pick one from each era
3. Run extraction on each (`sumo_extract_run` or equivalent)
4. For each extracted file, compare against the source (Principle #11):
   - Pull 10 specific values from the source document
   - Find the same values in the extracted CSV
   - Show comparison as a table:

```
File: cms_hospital_cost_report_2024.csv (newest)
| Field | Source (PDF/XLSX) | Extracted CSV | Match |
|-------|-------------------|---------------|-------|
| Provider CCN 050454 net_patient_revenue | $1,234,567 | 1234567 | ✅ |
| Provider CCN 050454 total_beds | 382 | 382 | ✅ |
| ... | ... | ... | ... |
```

5. If any mismatches: diagnose, fix the extractor, re-run the 3 samples
6. Check for format-era issues: does the same extractor handle all 3 files correctly?

**Present to human:** The 3 comparison tables plus any issues found.

### ⛔ GATE 3 STOP
All 3 sample files must pass verification. If ANY mismatch exists, fix and re-verify before proceeding. Wait for human approval.

---

### Gate 4: Full Extract
**Goal:** Run extraction on all files and validate at scale.

**Steps:**
1. Run extraction on all files in the group
2. Monitor for failures — any file that fails extraction gets flagged, not silently skipped
3. Post-extraction validation:
   - Total files extracted vs total files in group (expect 100% or explain gaps)
   - Row counts per file — are they reasonable? Any files with 0 rows?
   - Schema consistency — do all extracted CSVs have the same columns?
   - Quick distribution check — are there obvious outliers? NULL rates?
4. If failures > 5%: stop, diagnose, fix, re-run failed files

**Present to human:**
```
Extraction complete: 47/47 files (100%)
Total rows: 456,789
Row count range: 5,271 (2011) to 7,203 (2024) — increasing over time, expected
Schema: consistent across all files (116 columns)
NULL rate: <1% on all metric columns except rural_urban (3.2% NULL — expected, some providers don't report)
Failures: 0
```

### ⛔ GATE 4 STOP
Show the summary statistics. Wait for approval before value mapping.

---

### Gate 5: Value Map
**Goal:** Normalize values across eras and flag ambiguous cases.

**Steps:**
1. Read `ref/data/ai-pipeline.md` for value mapping patterns
2. Identify values that need mapping:
   - Column name variations across eras (e.g., `Plan Enrollment` → `enrollment`)
   - Category/label variations (e.g., `Medicare Supplement` vs `Medicare Supp` vs `Med Supp`)
   - Unit variations (e.g., thousands vs millions vs raw)
3. For each mapping, classify as:
   - **Typo/OCR error** → auto-fix (EBIDA → EBITDA)
   - **Historical name change** → preserve both with crosswalk (Gateway → Highmark)
   - **Ambiguous** → flag for human review
4. Show the complete mapping table:

```
Value Mappings (47 total):
| Original | Canonical | Reason | Confidence |
|----------|-----------|--------|------------|
| EBIDA | EBITDA | OCR typo | Auto-fix |
| Gateway Health Plan | Gateway Health Plan | Historical name (pre-2017) | Preserve |
| Gateway Health Plan | Highmark (post-2017) | Corporate acquisition | Crosswalk |
| Plan Enrollment | enrollment | Column rename across eras | Auto-fix |
| total_revenue | SKIP | Derivable from atomic values | Excluded |

Ambiguous (3 — need human review):
| Original | Options | Context |
|----------|---------|---------|
| Policy Acquisition Costs | Insurance accounting term vs business acquisitions | Same word, completely different concepts |
```

### ⛔ GATE 5 STOP
Show the mapping table. Flag every ambiguous case. Do NOT auto-resolve ambiguous mappings. Wait for human decisions.

---

### Gate 6: Publish + Verify
**Goal:** Publish to the warehouse and run verification checks.

**Steps:**
1. Read `ref/data/publish.md` for publishing patterns
2. Publish to bronze in the workspace (never directly to production)
3. Create the silver SQL model:
   - `CAST` every column to its proper type
   - Unpivot metric columns into `metric_name`/`metric_value` (if applicable)
   - Clean column names to snake_case
   - Add `column_descriptions` for every column (Principle #16)
   - Dedup if needed using `QUALIFY ROW_NUMBER()` (Principle #15)
4. Run verification (invoke `/verify` in pipeline mode):
   - Tier 1: Spot check 3 sample files against source
   - Tier 2: Sum checks where applicable (do totals add up across line items?)
   - Tier 3: Derived metric checks if external data available
5. Show final state:

```
Published to workspace: ws_abc123
Bronze: bronze.cms_hospital_cost_report (456,789 rows)
Silver: silver.stg_cms_hospital_cost_report (5,471,234 rows — unpivoted)
Verification:
  - Spot checks: 30/30 values match source ✅
  - Sum check: total_costs = sum of cost components ± 0.1% across all years ✅
  - Derived: operating_margin matches CMS published benchmarks ✅
```

### ⛔ GATE 6 STOP
Show the verification results. The pipeline is not "done" until verification passes. Wait for human approval before promoting the workspace.

---

## Refresh Mode

When new data drops for an existing pipeline (e.g., new month's enrollment data):

1. **Check what's new:** Compare current files vs last run
2. **Run the existing extractor on new files only** — don't re-extract everything
3. **Validate new extractions:** Same 3-file comparison, but only on new files
4. **Re-publish:** Incremental add to bronze
5. **Re-run silver/gold/platinum:** SQL models should handle the new data automatically
6. **Quick verify:** Spot-check the new data points, ensure they connect to existing time series without gaps

Refresh is **nearly autonomous** — the gates are softer because the pipeline is already proven. But flag any anomalies:
- New columns that didn't exist before
- Significant changes in row counts
- Values that break established patterns (e.g., enrollment suddenly drops 50%)

---

## Anti-Patterns

1. **Skipping Gate 3.** "The extractor looks right, let me just run it on everything." No. Test on 3 first. Always.

2. **Silent failures.** A file that fails extraction is NOT okay to skip. Every file must extract or be explicitly flagged as a known issue.

3. **Auto-resolving ambiguous value mappings.** "Policy Acquisition Costs" meaning insurance accounting vs business acquisitions — these MUST go to the human. When in doubt, flag it.

4. **Publishing directly to production.** Always publish to a workspace first. Verify. Then promote.

5. **Editing CSVs instead of fixing extractors.** If the extraction is wrong, fix the extraction prompt/code. Don't patch the output (Principle #6).
