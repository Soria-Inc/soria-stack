---
name: verify
version: 7.0.0
description: |
  Prove data is correct through evidence, not assertions. Centers on verify
  checks — rows in a shared dbt seed (`verifications.csv`, filtered per-dive
  by `model` column) that bound the expected range of every cell in the dive.
  Every dive ships with ~15+ verify check rows. Every verification starts by
  comparing actual marts values against the bounds in the verifications table.
  Three modes: Pipeline (extraction vs source), Model (trace through layers),
  Verify Checks (investigate cell-level bound failures, gap analysis).
  Drives the Soria platform through `mcp__soria__warehouse_query` /
  `file_query`, plus local `dbt seed` and `dbt test`. Never says "looks good"
  without showing evidence.
  Use when asked to "verify this", "is this data correct", "check the
  pipeline", "prove it", "validate the dive", or "what does this data look
  like". Proactively invoke this skill after any /ingest gate, after /dive,
  or when data quality is in question. (soria-stack)
benefits-from: [ingest, map, dive, plan]
allowed-tools:
  - Read
  - Bash
  - Glob
  - WebFetch
  - WebSearch
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: verify"
echo "---"
echo "Checking for prior artifacts..."
ls -t ~/.soria-stack/artifacts/plan-*.md ~/.soria-stack/artifacts/ingest-*.md ~/.soria-stack/artifacts/dive-*.md 2>/dev/null | head -5
```

Read `ETHOS.md`. Key principles: #10, #11, #17, #18, #19, #20, #28, #29.

**Phase awareness:** If a /plan artifact exists, read it — it has verification
criteria for each ETVLR phase. If ingest or dive artifacts exist, read those
too for table names and schemas.

## Skill routing (always active)

- Verification reveals extraction bugs → invoke `/ingest`
- Verification reveals unmapped values → invoke `/map`
- Verification reveals SQL issues → invoke `/dive`
- Semantic checks don't exist for this domain → invoke `/dive` to build them
- User wants to test the live dive in a browser → invoke `/dashboard-review`
- User wants to check pipeline status → invoke `/status`

**After /verify completes, suggest `/lessons`** if this was the end of a
pipeline build, or the next ETVLR phase from /plan if verification passed.

---

# /verify — "Prove it"

You are a paranoid data verifier. You NEVER say "looks good" or "data appears
correct" without showing evidence. Your job is to build the case — with tables,
comparisons, and math — that the data is either correct or wrong.

Three modes. Three tiers. Always escalate through tiers — don't stop at Tier 1
if Tier 2 or 3 are possible.

---

## Verify Checks — The Foundation

Verify checks are rows in a **shared dbt seed** at
`frontend/src/dives/dbt/seeds/verifications.csv`, materialized to
`soria_duckdb_staging.main.verifications`. Every dive's checks are rows in
this one table, filtered by the `model` column = dbt marts model name.

This is the durable, automated version of what Tier 2 and Tier 3 checks
do ad-hoc. The dive's `useDiveVerifications(model_name)` hook queries the
filtered rows and surfaces mismatches via `VerifyTooltip` on every grid cell.

### Architecture

```
frontend/src/dives/dbt/seeds/verifications.csv       -- git-tracked seed CSV
  ↓
  dbt seed --select verifications          (local → staging MD)
  ↓
soria_duckdb_staging.main.verifications              -- materialized table
  ↓
  (CI on PR merge promotes to soria_duckdb_main.main.verifications)
  ↓
useDiveVerifications("naic_national_kpis_by_company")   -- per-dive hook
  ↓
VerifyTooltip renders per-cell                       -- user sees bounds + source
```

### Row schema

Every row in `verifications.csv`:

```
id              -- bigint, unique
model           -- dbt marts model name this check applies to
description     -- human-readable ("UNH Total membership ~23M")
parent_company  -- dimension filter (NULL = any)
lob             -- dimension filter (NULL = any)
quarter         -- dimension filter, YYYY-MM format (NULL = any)
metric          -- dimension filter (NULL = any)
min_value       -- lower bound (bigint)
max_value       -- upper bound (bigint)
source          -- external citation label ("UNH 10-K 2024", "KFF MA Spotlight")
source_url      -- URL to the source
```

The `{parent_company, lob, quarter, metric}` tuple identifies which cells in
the dive grid this check applies to. A check with all dimensions NULL
applies to the whole model (bounded-range style).

### Check types (all encoded as rows in the same seed)

| Type | Row pattern | Example |
|---|---|---|
| **Spot check** | One row per cell, tight bounds | UNH Medicare membership in Q2 2025 between 7M–12M |
| **Bounded range** | One row per metric, wide bounds, other dims NULL | Total market between 220M–350M for any period |
| **Algebraic** (parts=whole) | Requires code-side check — Not directly expressible as a single seed row. The marts model SQL should enforce the identity itself (e.g. market shares computed via window function so they sum to 100 by construction) | |
| **External benchmark** | Row with `source` = company 10-K or published report | Humana Q4 2024 total membership 10M–18M with SEC URL |

### How checks map to tiers

| Tier | What it proves | Typical seed pattern |
|---|---|---|
| **Tier 1 (Spot Checks)** | Individual values correct | Tight min/max bounds on specific company × period × metric |
| **Tier 2 (Sum Checks)** | Algebraic consistency | Marts SQL structure + a bounded_range check on totals |
| **Tier 3 (Derived Metrics)** | External benchmarks match | Rows with `source` + `source_url` citing SEC / earnings / KFF |

The verifications seed encodes Tier 1 and Tier 3 durably. Tier 2 algebraic
consistency is best enforced in the marts SQL itself (computing ratios with
window functions, not storing pre-aggregated results).

---

## Step 0: Check the Verifications Seed (all modes)

Before running any mode, check how many verify checks exist for this dive:

```
mcp__soria__warehouse_query(sql="
  SELECT model, COUNT(*) AS checks,
         COUNT(DISTINCT metric) AS metrics,
         COUNT(DISTINCT source) AS sources
  FROM soria_duckdb_staging.main.verifications
  WHERE model = '{your_marts_model}'
  GROUP BY 1
")
```

Three outcomes:

1. **≥15 checks present, covering the key metrics × companies × periods** —
   strong foundation. Proceed with the requested mode. Include the count in
   all output.

2. **Checks present but sparse** (<10 rows, missing metrics) — coverage gap.
   Flag in the verdict and suggest invoking `/dive` to add more rows to
   `verifications.csv`.

3. **Zero checks** — the dive has no verify content. Shipping blocker.
   Suggest invoking `/dive` to add check rows.

Include the verify scorecard in every verification output:

```
Verifications: model = naic_national_kpis_by_company
  24 checks | 22 within bounds | 2 failing
  Failing: UNH Medicare Q1 2024 (observed 8.2M, expected 9.5M–14M — investigate)
           Total market 2014 (observed 180M, expected 220M–350M — pre-ACA era bounds too tight)
```

### Also check the methodology surfacing

Per Principle #29, every dive ships with methodology content (the
"how this is built" panel users see). Verify it exists — the pattern
varies per dive, so check whichever is used in this codebase:

```bash
# Search the dive component and its companion files for methodology content
grep -l "methodology\|Methodology" frontend/src/dives/{dive-id}.tsx
grep -rl "methodology" frontend/src/dives/ 2>/dev/null | grep "{dive-id}"
```

If the dive component renders no methodology content and there's no
companion file, flag it as a shipping blocker in the verdict.

---

## The Verification Hierarchy

Always escalate. Don't stop at Tier 1 when Tier 2 is possible.

| Tier | What it proves | Strength |
|------|---------------|----------|
| **Tier 1: Spot Checks** | Individual values correct | Evidence — necessary but not sufficient |
| **Tier 2: Sum Checks** | Multiple independently extracted values ALL correct and correctly denominated | Proof — algebraic consistency is hard to fake |
| **Tier 3: Derived Metrics** | Multiple values correct AND correctly mapped AND combined | Gold standard — proves entire pipeline |

**Tier 2 is the most underrated.** If Revenue = Premiums + Products + Services
across 10 years, four independently extracted items are all correct.

**Tier 3 is the hardest to pass by accident.** If your computed MCR matches
UNH's press release, both numerator and denominator are proven correct.

---

## Mode 1: Pipeline Verify

**When to use:** After extraction (/ingest Gate 3 or Gate 4). Verifies that
the extraction pipeline correctly pulled data from source files.

### Steps

1. **Select 3 sample files** across eras (oldest, newest, mid-history):
   ```
   mcp__soria__file_query(group_id="{id}", limit=50)
   ```

2. **For each file, run Tier 1 — Spot Checks:**
   - Open the source document (`mcp__soria__file_query(file_id="{id}", open=True)` returns a presigned URL for PDFs/Excel)
   - Pick 10 specific values spread across different columns and rows
   - Find the same values in the extracted output:
     ```
     mcp__soria__warehouse_query(sql="
       SELECT * FROM soria_duckdb_staging.bronze.{table}
       WHERE _source_file LIKE '%{filename}%' LIMIT 20
     ")
     ```
   - Show the comparison as a table with match/mismatch per value

3. **If the data supports it, run Tier 2 — Sum Checks:**
   - Identify additive relationships in the source data
   - Verify they hold in the extracted data
   - Sum checks spanning multiple independently extracted values are stronger
     than single-value spot checks (Principle #18)

4. **If external data exists, run Tier 3 — Derived Metric Checks:**
   - Compute a derived metric from the extracted data
   - Compare against an independently published number (`WebFetch` the source)

### Output
```
Pipeline Verification: cms_hospital_cost_report
├── Tier 1 (Spot Checks): 30/30 values match across 3 files
├── Tier 2 (Sum Checks): total = components +/- 0.1% across 14 years
└── Tier 3 (Derived): operating_margin matches CMS benchmarks +/- 0.5%

Confidence: HIGH — all three tiers pass
```

---

## Mode 2: Model Verify

**When to use:** After building a dive (`/dive`). Verifies that data flows
correctly through bronze → staging → intermediate → marts.

### Steps

1. **Pick 5 specific values** from the raw source data (bronze).

2. **Trace each value through every layer:**

   ```
   Tracing: UNH Revenue FY2024 = $371.6B

   | Layer | Table | Value | Correct? |
   |-------|-------|-------|----------|
   | Bronze | soria_duckdb_staging.bronze.unh_10k_financials | 371622 (millions) | ✅ |
   | Staging | soria_duckdb_staging.main_staging.stg_unh_financials | metric='total_revenue', value=371622 | ✅ |
   | Intermediate | soria_duckdb_staging.main_intermediate.int_insurer_financials | total_revenue=371622000000 (scaled) | ✅ |
   | Marts | soria_duckdb_staging.main_marts.insurer_kpi | revenue='$371.6B' | ✅ |
   ```

3. **Run `dbt run` and `dbt test` locally:**
   ```bash
   cd frontend/src/dives/dbt
   ../../../../.venv/bin/dbt run --select {model}+
   ../../../../.venv/bin/dbt test --select {model}+
   ```

   `+` includes downstream models. `+{model}` includes upstream. `+{model}+`
   includes both.

4. **Check for fan-out or fan-in bugs:**
   - Does joining in intermediate multiply rows?
   - Does dedup in staging drop too many rows?
   - Does aggregation in marts collapse the right dimensions?

5. **Verify ratio computation:**
   - Confirm ratios are computed AFTER aggregation, not averaged
   - Test with a known example

6. **Check temporal alignment in intermediate:**
   - Are the right time periods joined?

---

## Mode 3: Verify Checks (cell-level bounds)

**When to use:** After `/dive` builds a dive and adds rows to
`verifications.csv`. Also when investigating data quality concerns, after
a data refresh produces new failures, or when asked "is this data correct?"

This is the primary verification mode for analytical correctness. If
verify checks exist, start here. If they don't, flag the gap and invoke
`/dive`.

### Steps

1. **Pull all checks for this dive's model and join against the actual data
   to find mismatches:**

   ```
   mcp__soria__warehouse_query(sql="
     WITH checks AS (
       SELECT * FROM soria_duckdb_staging.main.verifications
       WHERE model = '{your_marts_model}'
     ),
     actual AS (
       SELECT parent_company, lob, quarter, metric, value
       FROM soria_duckdb_staging.main_marts.{your_marts_model}_long_format  -- if available
     )
     SELECT c.id, c.description, c.parent_company, c.lob, c.quarter, c.metric,
       c.min_value, c.max_value, a.value,
       CASE
         WHEN a.value BETWEEN c.min_value AND c.max_value THEN 'PASS'
         WHEN a.value IS NULL THEN 'NO_DATA'
         ELSE 'FAIL'
       END AS status,
       c.source, c.source_url
     FROM checks c
     LEFT JOIN actual a
       ON (c.parent_company IS NULL OR c.parent_company = a.parent_company)
      AND (c.lob IS NULL OR c.lob = a.lob)
      AND (c.quarter IS NULL OR c.quarter = a.quarter)
      AND (c.metric IS NULL OR c.metric = a.metric)
     ORDER BY status, c.id
   ")
   ```

   Adjust the `actual` CTE to match the shape of your marts model — some
   are wide (one row per entity × period with metric columns) and need an
   UNPIVOT; others are already long.

2. **Classify each failing row:**

   | Classification | Meaning | Action |
   |---------------|---------|--------|
   | **Pipeline bug** | Data is actually wrong | Fix (invoke /ingest or /dive) |
   | **Merger/acquisition** | Company structural change | Update the check's `description` to note M&A |
   | **Source data limitation** | Source agency methodology change | Widen bounds with rationale in description |
   | **Known industry event** | Documented market shift | Update check `description` and keep bounds |
   | **Threshold too tight** | Bounds need adjustment | Widen bounds, note the source of the widened range |

3. **Investigation patterns:**

   - **Company × metric out of bounds** — search mempalace for earnings
     transcripts mentioning the company + quarter. Check SEC filings for
     restatements. Most common cause: M&A.
   - **Bounded-range check fails for total market** — check era. Pre-ACA
     (2014) bounds often need separate rows than post-ACA.
   - **Derived-metric checks** (market share, YoY) — if the raw component
     checks pass but the derived fails, investigate the computation (ratios
     before aggregation? missing partition columns?).
   - **Checks with NO_DATA** — the check references a parent_company, LOB,
     or quarter that doesn't exist in the marts table. Either the check's
     dimensions are wrong, or the data is missing.

4. **Gap analysis:**

   List every filter dimension and metric in the manifest. For each, check
   whether verify check rows cover it:

   ```
   Coverage: ma-enrollment dive (model = ma_enrollment_by_company)
   ├── segment: MA (8 checks), PDP (4 checks)
   ├── distribution: Individual (6 checks), Group (1 check — weak)
   ├── parent_organization: top-5 specific rows + 2 bounded rows for overall
   ├── enrollment: 12 checks across 6 companies × 2 quarters
   ├── market_share_pct: 0 checks (should add — partition-level bounds)
   ├── yoy_delta: 0 checks (derivable — algebraic enforced in SQL)
   └── recent quarter (2025-Q4): 0 checks (add when data lands)
   ```

   Flag dimensions with zero or weak coverage. Suggest rows to add to
   `verifications.csv` via `/dive`.

5. **External corroboration (when investigating failures):**

   Use `WebSearch` / `WebFetch` to find independent sources:
   - Industry reports (KFF, MedPAC, Avalere, CBO)
   - SEC filings (merger announcements, enrollment disclosures)
   - Earnings transcripts (company-reported metrics — Tier 3 power move)
   - Press releases (enrollment milestones, market share claims)

### Output

```
Verify Checks: ma-enrollment dive (model = ma_enrollment_by_company)

├── Check rows: 32 (within bounds: 29, failing: 3)
├── Failing rows:
│   ├── UNH Medicare Q1 2024: observed 8.2M, expected 9.5M–14M
│   │    → classified: source_data_limitation (CMS mid-year contract split)
│   ├── Total market 2013-Q4: observed 14.8M, expected 16M–20M
│   │    → classified: threshold_too_tight (pre-ACA era — widen bounds)
│   └── Centene Medicaid 2022: observed 22M, expected 14M–19M
│    → classified: M&A (WellCare integration finished 2022)
├── Coverage: 6/8 manifest dimensions have rows; market_share_pct has 0 checks (GAP)
├── Methodology: ✅ surfaced via DivePageHeader.methodology prop
├── Concerns:
│   1. Parent org mapping instability (BCBS Michigan)
│   2. Dec→Jan enrollment drops (2009-2011)
│   3. "Other" network category unstable (2015 reclassification)
└── Confidence: HIGH
```

---

## Phase-Gated Verification

When a /plan artifact exists with verification criteria, run against those
criteria specifically. Each ETVLR phase has its own criteria — run the
relevant ones after each phase completes.

---

## When Things Fail

Don't conclude "the data is wrong" until you've checked infrastructure.
Invoke `/diagnose` for:

- Slow queries (may be stale dbt marts — check `frontend/public/dbt-run-results.json`)
- Missing data (may be a Durable Object event relay issue)
- Dive load failures (may be manifest/data drift, WASM cold start, or PG proxy timeout)
- Stale `last_dbt_run` in the VerifyModal (vite-dbt-sync plugin hasn't run
  — make sure `make dev-https` is running and rerun `dbt run`)

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/verify-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Verification Scorecard: [Dive/Model Name]

## Mode
[Pipeline / Model / Verify Checks]

## Verify Checks
[Count of rows in verifications table for this model]
[Failing rows with classification: pipeline bug / M&A / source limitation /
 threshold too tight / known event]
[Coverage: which dimensions/metrics have checks, which are gaps]

## Methodology Surface
[How the dive surfaces methodology — inline, DivePageHeader prop, sibling
 component — and whether it has real content or is empty]

## Tier Results
[Which tiers run, specific evidence for each]

## Plan Criteria (if applicable)
[Which phase criteria checked, pass/fail]

## Confidence
[HIGH / MEDIUM / LOW with justification]

## Concerns
[Ranked list of worries, with severity]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

---

## What "Done" Means

Verification is DONE when you can produce a scorecard showing:
1. The verify check row count (or a note that zero rows exist yet — shipping
   blocker)
2. Which modes and tiers were run
3. Specific evidence for each (tables, not just "looks good")
4. Every failing check row investigated and classified
5. Methodology surface confirmed present with real content
6. A confidence level with justification
7. Any concerns, ranked by severity

**Never say "the data looks correct" without a scorecard.**
**Never say "all checks pass" without showing the checks.**
**Never leave failing verify rows uninvestigated.**
**Never declare a dive verified without confirming methodology content exists.**
