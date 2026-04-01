---
name: ingest
version: 2.0.0
description: |
  Build and run data pipelines with six hard-stop gates.
  Each gate requires human review before proceeding.
  Also handles refresh mode for re-running existing pipelines when new data drops.
  Use when asked to "scrape this", "build the pipeline", "extract this data",
  "run the pipeline", or "load this into the warehouse".
  Proactively suggest when the user has completed /scout and is ready to build.
  Use after /scout, before /model.
benefits-from: [scout]
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
echo "Checking for scout artifacts..."
ls -t ~/.soria-stack/artifacts/scout-*.md 2>/dev/null | head -3
```

Read `ETHOS.md` from this skill pack. All principles apply during ingestion.

**Check for prior scout work:** If a scout artifact exists, read it — it has the source analysis, complexity classification, and platform fit assessment. If no scout artifact exists, warn: "No /scout recon found. Consider running /scout first to avoid building the wrong thing."

**Pipeline framing:** This pipeline follows **ETVL** — Extract, Transform, Value-map, Load (Principle #26). The Transform step is NOT limited to per-file extractors. If the scout report flagged Level 5 complexity, the Transform step may require custom code.

---

# /ingest — "Build the pipeline with gates"

You are a pipeline builder. Your job is to scrape, organize, extract, map, and publish data — but NEVER skip a gate. Each gate is a checkpoint where the human must see and approve the work before you proceed.

---

## Gate 1: Scrape (Extract)
**Goal:** Download all source files.

**Steps:**
1. Check if files already exist (Principle #24 — inventory first)
2. If scraper exists and has files → skip to Gate 2
3. If scraper exists but no files → run it
4. If no scraper → write one:
   - Write the scraper code
   - Test first
   - Save, then run
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

## Gate 2: Organize + Schema
**Goal:** Group files logically and propose the extraction schema.

**Steps:**
1. Examine file contents — look at headers, formats, structure across eras
2. Propose groups:
   - One group per logical collection
   - If files have different schemas across eras, note which files belong to which schema era
3. Create groups
4. Propose the extraction schema:
   - List every column with name, type, and whether it's a dimension or metric
   - Explicitly state what gets EXCLUDED and why (totals, subtotals, derivable values — Principle #7)
   - Show options if there's a design decision (e.g., "wide vs long format?")
5. **If scout flagged Level 5 complexity:** Propose the custom Transform approach here — what waterfall logic, cross-file association, or AI re-validation is needed? This replaces the standard extractor path.

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

## Gate 3: Sample Extract (Transform — 3 files)
**Goal:** Extract 3 files and verify against sources. This is Principle #2 in action.

**Steps:**
1. Pick 3 files: **oldest available, newest available, one from mid-history**
   - If format eras exist, pick one from each era
2. Run extraction on each
3. For each extracted file, compare against the source (Principle #11):
   - Pull 10 specific values from the source document
   - Find the same values in the extracted CSV
   - Show comparison as a table with ✅/❌ per value

   ```
   File: cms_hospital_cost_report_2024.csv (newest)
   | Field | Source (PDF/XLSX) | Extracted CSV | Match |
   |-------|-------------------|---------------|-------|
   | Provider CCN 050454 net_patient_revenue | $1,234,567 | 1234567 | ✅ |
   | Provider CCN 050454 total_beds | 382 | 382 | ✅ |
   ```

4. If any mismatches: diagnose, fix the extractor, re-run the 3 samples
5. Check for format-era issues: does the same extractor handle all 3 files correctly?

**For Level 5 sources:** The Transform step here is the custom script, not a standard extractor. Run it on 3 entities (not 3 files) and verify the output.

**Present to human:** The 3 comparison tables plus any issues found.

### ⛔ GATE 3 STOP
All 3 sample files must pass verification. If ANY mismatch exists, fix and re-verify before proceeding. Wait for human approval.

---

## Gate 4: Full Extract (Transform — all files)
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
NULL rate: <1% on all metric columns except rural_urban (3.2% NULL — expected)
Failures: 0
```

### ⛔ GATE 4 STOP
Show the summary statistics. Wait for approval before value mapping.

---

## Gate 5: Value Map
**Goal:** Normalize values across eras and flag ambiguous cases.

**Steps:**
1. Identify values that need mapping:
   - Column name variations across eras
   - Category/label variations (e.g., `Medicare Supplement` vs `Med Supp`)
   - Unit variations (e.g., thousands vs millions vs raw)
2. For each mapping, classify as:
   - **Typo/OCR error** → auto-fix (EBIDA → EBITDA)
   - **Historical name change** → preserve both with crosswalk (Gateway → Highmark)
   - **Ambiguous** → flag for human review
3. Show the complete mapping table

### ⛔ GATE 5 STOP
Show the mapping table. Flag every ambiguous case. Do NOT auto-resolve ambiguous mappings. Wait for human decisions.

---

## Gate 6: Publish + Verify (Load)
**Goal:** Publish to the warehouse and run verification checks.

**Steps:**
1. Publish to bronze in the workspace (never directly to production)
2. **Materialize the bronze table** (Principle #4 — bronze must be materialized in MotherDuck)
3. Create the silver SQL model:
   - `CAST` every column to its proper type
   - Unpivot metric columns into `metric_name`/`metric_value` (if applicable)
   - Clean column names to snake_case
   - Add `column_descriptions` for every column (Principle #16)
   - Dedup if needed using `QUALIFY ROW_NUMBER()` (Principle #15)
4. Run verification (invoke `/verify` in pipeline mode):
   - Tier 1: Spot check 3 sample files against source
   - Tier 2: Sum checks where applicable
   - Tier 3: Derived metric checks if external data available

**Present to human:**
```
Published to workspace: ws_abc123
Bronze: bronze.cms_hospital_cost_report (456,789 rows) — MATERIALIZED ✅
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
6. **Quick verify:** Spot-check the new data points

Refresh is **nearly autonomous** — the gates are softer because the pipeline is already proven. But flag any anomalies:
- New columns that didn't exist before
- Significant changes in row counts
- Values that break established patterns

---

## Artifact Output

At the end of an ingest session, write an extraction report:

```bash
cat > ~/.soria-stack/artifacts/ingest-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Ingest Report: [Dataset Name]

## Pipeline Summary
[Scraper, file counts, date range, schema]

## Value Mappings Applied
[Mapping table summary]

## Verification Results
[Which tiers passed, evidence]

## Tables Created
[Bronze and silver table names, row counts]

## Open Questions
[Anything that needs human decision before /model can start]
ARTIFACT
```

This artifact is consumed by `/model` when building SQL models.

---

## Anti-Patterns

1. **Skipping Gate 3.** "The extractor looks right, let me just run it on everything." No. Test on 3 first. Always.

2. **Silent failures.** A file that fails extraction is NOT okay to skip. Every file must extract or be explicitly flagged.

3. **Auto-resolving ambiguous value mappings.** When in doubt, flag it for the human.

4. **Publishing directly to production.** Always publish to a workspace first. Verify. Then promote.

5. **Editing CSVs instead of fixing extractors.** If the extraction is wrong, fix the extraction. Don't patch the output (Principle #6).

6. **Un-materialized bronze tables.** If bronze isn't materialized, dashboards will take 40 seconds instead of 0.02 seconds. Materialize at Gate 6. Always.
