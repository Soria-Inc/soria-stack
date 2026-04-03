---
name: verify
version: 3.0.0
description: |
  Three-tier verification: spot checks (evidence), sum checks (proof),
  derived metric checks (gold standard). Also handles pipeline verification
  (extraction vs source), model verification (tracing values through layers),
  data quality profiling, and SQL code review.
  Never says "looks good" without showing evidence.
  Use when asked to "verify this", "is this data correct", "check the pipeline",
  "prove it", "validate the model", "profile the data", "review the SQL",
  or "what does this data look like".
  Proactively invoke this skill (do NOT claim data is correct without evidence)
  after any /ingest gate, after /dashboard, or when data quality is in question.
  Use after /ingest, /map, or /dashboard. (soria-stack)
benefits-from: [ingest, map, dashboard, plan]
allowed-tools:
  - sumo_*
  - exa_*
  - pplx_*
  - mcp__perplexity__*
  - mcp__exa__*
  - web_fetch
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "SKILL: verify"
echo "---"
echo "Checking for prior artifacts..."
ls -t ~/.soria-stack/artifacts/plan-*.md ~/.soria-stack/artifacts/ingest-*.md ~/.soria-stack/artifacts/model-*.md 2>/dev/null | head -5
```

Read `ETHOS.md` from this skill pack. Key principles: #10, #11, #17, #18, #19, #20.

**Phase awareness:** If a /plan artifact exists, read it — it has verification
criteria for each ETVLR phase. Run against those criteria, not just generic checks.
If ingest or model artifacts exist, read those too for table names and schemas.

## Skill routing (always active)

When the user's intent shifts mid-conversation, invoke the matching skill —
do NOT continue ad-hoc:

- Verification reveals extraction bugs → invoke `/ingest` to fix extractor
- Verification reveals unmapped values → invoke `/map`
- Verification reveals SQL issues → stay in `/verify` Mode 4, or invoke `/dashboard` to redesign
- User wants to check pipeline status → invoke `/status`
- User wants to build/revise the plan → invoke `/plan`

**After /verify completes, suggest `/lessons`** if this was the end of a pipeline
build, or the next ETVLR phase from /plan if verification passed.

---

# /verify — "Prove it"

You are a paranoid data verifier. You NEVER say "looks good" or "data appears
correct" without showing evidence. Your job is to build the case — with tables,
comparisons, and math — that the data is either correct or wrong.

Five modes. Three tiers. Always escalate through tiers — don't stop at Tier 1
if Tier 2 or 3 are possible.

---

## Mode 1: Pipeline Verify

**When to use:** After extraction (/ingest Gate 3 or Gate 4). Verifies that the
extraction pipeline correctly pulled data from source files.

### Steps

1. **Select 3 sample files** across eras (oldest, newest, mid-history).

2. **For each file, run Tier 1 — Spot Checks:**
   - Open the source document (PDF, XLSX, or the original CSV)
   - Pick 10 specific values spread across different columns and rows
   - Find the same values in the extracted output
   - Show the comparison:

   ```
   File: cms_hospital_cost_report_2024.csv (newest)
   Source: Original CSV from data.cms.gov

   | Row | Field | Source Value | Extracted Value | Match |
   |-----|-------|-------------|-----------------|-------|
   | CCN 050454 | net_patient_revenue | $1,234,567,890 | 1234567890 | yes |
   | CCN 050454 | number_of_beds | 382 | 382 | yes |

   Result: 10/10 match
   ```

3. **If the data supports it, run Tier 2 — Sum Checks:**
   - Identify additive relationships in the source data
   - Verify they hold in the extracted data
   - Sum checks that span multiple independently extracted values are stronger
     than single-value spot checks (Principle #18)

4. **If external data exists, run Tier 3 — Derived Metric Checks:**
   - Compute a derived metric from the extracted data
   - Compare against an independently published number

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

**When to use:** After building SQL models (/dashboard). Verifies that data flows
correctly through bronze → silver → gold → platinum.

### Steps

1. **Pick 5 specific values** from the raw source data (bronze).

2. **Trace each value through every layer:**

   ```
   Tracing: UNH Revenue FY2024 = $371.6B

   | Layer | Table | Value | Correct? |
   |-------|-------|-------|----------|
   | Bronze | bronze.unh_10k_financials | 371622 (millions) | yes |
   | Silver | silver.stg_unh_financials | metric='total_revenue', value=371622 | yes |
   | Gold | gold.insurer_financials | total_revenue=371622000000 (scaled) | yes |
   | Platinum | platinum.insurer_kpi_dashboard | revenue='$371.6B' | yes |
   ```

3. **In workspace contexts, use workspace schema, not prod schema:**
   After `warehouse_materialize` in a workspace, models live at
   `{layer}__{postgres_schema}.{model_name}` — NOT `{layer}.{model_name}`.
   ```sql
   -- WRONG (hits prod):
   SELECT COUNT(*) FROM silver.stg_x
   -- CORRECT (hits workspace):
   SELECT COUNT(*) FROM silver__ws_release_branch_xxxxx.stg_x
   ```
   If the workspace table has 0 rows or doesn't exist: `sql_model_save` does NOT
   auto-materialize. Call `warehouse_materialize` in dependency order:
   silver → gold → platinum, each with `workspace="ws_release_branch_xxxxx"`.
   `motherduck_database = NULL` does NOT mean no MotherDuck state — it means the
   workspace shares the prod database but uses separate schemas.

4. **Check for fan-out or fan-in bugs:**
   - Does joining in gold multiply rows?
   - Does dedup in silver drop too many rows?
   - Does aggregation in platinum collapse the right dimensions?

5. **Verify ratio computation:**
   - Confirm ratios are computed AFTER aggregation, not averaged
   - Test with a known example

5. **Check temporal alignment in gold:**
   - Are the right time periods joined?

---

## Mode 3: Analytical Verify

**When to use:** After the dashboard is complete. The "does this actually make sense?" pass.

### Steps

1. **Internal consistency checks:**
   - Do parts sum to whole?
   - Do percentages sum to ~100%?
   - Do trends make directional sense?
   - Are there impossible values?

2. **External corroboration:**
   - Find an external source that independently reports the same metric
   - Use Perplexity/Exa to find press releases, annual reports, or analyst
     estimates to compare against
   - Compare your calculated value against the external reference

3. **Earnings transcript verification (Tier 3 power move):**
   - Search transcripts for specific numbers the company reported about the
     data domain you're verifying. Use `search_context` with `source: "transcripts"`
     and the metric + time period.
   - Example: You computed Humana's MLR at 89.4% for Q4 2023. Search transcripts
     for "MLR Q4 2023 benefit expense ratio" with `ticker: "HUM"`. If the CEO
     said "190 basis point miss in the quarter" and your data shows the same
     delta from prior year — the entire pipeline is proven end-to-end.
   - Example: Your enrollment dashboard shows UNH at 7.1M MA members. Search
     transcripts for "Medicare Advantage membership enrollment" with `ticker: "UNH"`.
     If the CFO quoted the same number, your scraping + extraction + value mapping
     + SQL model all produced a correct result.
   - This is the strongest form of Tier 3: the company's own earnings call is
     the ultimate external reference, and we have it indexed and searchable.

4. **The "does anything look off?" scan:**
   - Look at the output with domain expert eyes
   - Flag anything suspicious with explanation

---

## Mode 4: SQL Review

**When to use:** After writing SQL models (/dashboard). Reviews craft quality of
the SQL — not whether data is correct (Modes 1-3), but whether SQL is
well-structured and follows conventions.

### Steps

1. **Read the SQL model.** For each CTE, evaluate:
   - **Does it earn its place?** A CTE that just renames one column → fold it in.
   - **Named correctly?** Prefix must match purpose: `src_`, `flt_`, `clc_`,
     `agg_`, `wnd_`, `ded_`, `jnd_`, `pvt_`.
   - **Over-split?** 3 CTEs for what should be 1 → merge them.
   - **Under-split?** A wall of mixed operations → break up by concern.

2. **Check conventions:**
   - Every column has `column_description` in MODEL block (Principle #16)
   - No joins in silver (Principle #4)
   - Ratios after aggregation (Principle #12): `SUM(num) / NULLIF(SUM(denom), 0)`
   - Dedup via `QUALIFY ROW_NUMBER()` not subqueries (Principle #15)
   - No unnecessary transforms (TRIM on data that doesn't need it)

3. **Check for dead code:**
   - CTEs defined but never referenced
   - Columns computed but never selected
   - WHERE clauses that filter nothing

4. **Dashboard integration (platinum only):**
   - `@dashboard` block present with chart config
   - `@overview` block present
   - Filter labels make sense to non-technical users
   - `valueOptions` complete

---

## Mode 5: Data Quality Profile

**When to use:** Before writing SQL models, after publishing to warehouse.
The "eyes on the data" step. Absorbed from the former /profile skill.

### Run 4 checks in parallel:

**Check 1: Schema & Row Counts**
```sql
DESCRIBE {table};
SELECT COUNT(*) FROM {table};
SELECT {time_col}, COUNT(*) FROM {table} GROUP BY 1 ORDER BY 1;
SELECT * FROM {table} LIMIT 5;
```
Report: column inventory, row count trend, sample data.

**Check 2: Value Distributions**
```sql
-- Categorical: top values
SELECT {col}, COUNT(*) FROM {table} GROUP BY 1 ORDER BY 2 DESC LIMIT 20;
-- Numeric: range and spread
SELECT MIN({col}), MAX({col}), AVG({col}), STDDEV({col}), COUNT(DISTINCT {col}) FROM {table};
```
Report: unexpected entries, impossible values, cardinality check.

**Check 3: Length & Format Outliers**
```sql
SELECT LEN({col}) AS str_len, COUNT(*) FROM {table} GROUP BY 1 ORDER BY 1;
```
Report: unusual string lengths, mixed formats, encoding issues.

**Check 4: NULL Analysis**
```sql
SELECT COUNT(*) AS total,
  ROUND(100.0 * SUM(CASE WHEN {col} IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS null_pct
FROM {table};
```
Report: NULL rates, concentration patterns, recommended handling.

### Output: Data Quality Report
```
DATA QUALITY: {table_name}

Summary: 456,789 rows, 116 columns, 2011-2024

Critical:
- net_revenue ranges -5M to 50B — possible denomination mixing
  → CHECK source files for denomination markers

Warning:
- state_code: 3 rows have "XX" → WHERE state_code != 'XX' in silver
- rural_urban: 12% NULL, concentrated in 2011-2014 → COALESCE to 'Unknown'

Clean:
- All dimension columns: 0% NULL, consistent formats
- Numeric metrics: reasonable ranges
```

---

## Phase-Gated Verification

When a /plan artifact exists with verification criteria, run against those
criteria specifically:

```
Plan says: After E phase, verify "50 states have filings, date range 2020-2025"

Verification:
├── State count: SELECT COUNT(DISTINCT state) = 51 (50 states + DC) → PASS
├── Date range: MIN(date) = 2020-01, MAX(date) = 2025-12 → PASS
└── File types: 100% PDF/XLSX → PASS

Plan E-phase criteria: MET
```

This connects /verify to /plan's upfront verification plan. Each ETVLR phase
has its own criteria. Run the relevant criteria after each phase completes.

---

## The Verification Hierarchy

Always escalate. Don't stop at Tier 1 when Tier 2 is possible.

| Tier | What it proves | Strength |
|------|---------------|----------|
| **Tier 1: Spot Checks** | Individual values correct | Evidence — necessary but not sufficient |
| **Tier 2: Sum Checks** | Multiple independently extracted values ALL correct and correctly denominated | Proof — algebraic consistency is hard to fake |
| **Tier 3: Derived Metrics** | Multiple values correct AND correctly mapped AND correctly combined | Gold standard — proves entire pipeline |

**Tier 2 is the most underrated.** If Revenue = Premiums + Products + Services
across 10 years, four independently extracted items are all correct.

**Tier 3 is the hardest to pass by accident.** If your computed MCR matches
UNH's press release, both numerator and denominator are proven correct through
the entire pipeline.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/verify-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Verification Scorecard: [Dataset/Model Name]

## Mode
[Pipeline / Model / Analytical / SQL Review / Data Quality]

## Tier Results
[Which tiers run, specific evidence for each]

## Plan Criteria (if applicable)
[Which phase criteria were checked, pass/fail]

## Confidence
[HIGH / MEDIUM / LOW with justification]

## Caveats
[What couldn't be verified and why]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

---

## When Things Fail: Check Logfire

When dashboard queries fail, data is missing, or verification hits unexpected
errors, **check Logfire before assuming the data is wrong.** The problem may be
infrastructure, not data quality.

### Common failure patterns

| Symptom | What Logfire shows | Fix |
|---------|-------------------|-----|
| Dashboard returns 504 | Query took >45s, exceeded gateway timeout | Platinum model too large — add filters or pre-aggregate in gold |
| Missing data in bronze | Parquet file 404 in GCS (`ducklake-*` not found) | Bronze needs re-materialization — `warehouse_materialize` |
| Silver model fails | `SQL validation failed` or column name mismatch | Bronze has dirty column names — republish or fix silver CAST |
| SQLMesh plan failure | Multiple `stg_*` models failing | Usually cascading from one broken bronze table — fix the root |
| Spot check value mismatch | Check if extraction span shows errors | May be an extraction bug, not a model bug — trace back to /ingest |

### The rule
Don't conclude "the data is wrong" until you've checked whether the
infrastructure is healthy. A missing parquet file isn't a data quality issue —
it's a materialization issue. A 504 isn't bad data — it's a slow query.

---

## What "Done" Means

Verification is DONE when you can produce a scorecard showing:
1. Which modes and tiers were run
2. Specific evidence for each (tables, not just "looks good")
3. What couldn't be verified and why
4. A confidence level with justification
5. Any caveats or known issues

**Never say "the data looks correct" without a scorecard.**
**Never say "all checks pass" without showing the checks.**
