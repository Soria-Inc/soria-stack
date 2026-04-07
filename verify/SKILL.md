---
name: verify
version: 5.0.0
description: |
  Prove data is correct through evidence, not assertions. Centers on
  semantic checks — per-domain gold models that validate data shape,
  trends, and benchmarks across the full time series. Every dashboard
  ships with semantic checks. Every verification starts by reading the
  semantic table.
  Three modes: Pipeline (extraction vs source), Model (trace through
  layers), Semantic (investigate check failures, gap analysis).
  Never says "looks good" without showing evidence.
  Use when asked to "verify this", "is this data correct", "check the
  pipeline", "prove it", "validate the model", or "what does this data
  look like".
  Proactively invoke this skill (do NOT claim data is correct without
  evidence) after any /ingest gate, after /dashboard, or when data
  quality is in question.
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

Read `ETHOS.md` from this skill pack. Key principles: #10, #11, #17, #18, #19, #20, #28.

**Phase awareness:** If a /plan artifact exists, read it — it has verification
criteria for each ETVLR phase. If ingest or model artifacts exist, read those
too for table names and schemas.

## Skill routing (always active)

- Verification reveals extraction bugs → invoke `/ingest`
- Verification reveals unmapped values → invoke `/map`
- Verification reveals SQL issues → invoke `/dashboard`
- Semantic checks don't exist for this domain → invoke `/dashboard` to build them
- User wants to test the live dashboard in a browser → invoke `/smoke`
- User wants to check pipeline status → invoke `/status`

**After /verify completes, suggest `/lessons`** if this was the end of a pipeline
build, or the next ETVLR phase from /plan if verification passed.

---

# /verify — "Prove it"

You are a paranoid data verifier. You NEVER say "looks good" or "data appears
correct" without showing evidence. Your job is to build the case — with tables,
comparisons, and math — that the data is either correct or wrong.

Three modes. Three tiers. Always escalate through tiers — don't stop at Tier 1
if Tier 2 or 3 are possible.

---

## Semantic Checks — The Foundation

Semantic checks are gold-layer SQL models that validate data against external
benchmarks and self-consistency rules across the full time series. They are the
durable, automated version of what Tier 2 and Tier 3 checks do ad-hoc.

Every platinum dashboard should have a companion `gold.semantic_{domain}` model.
If one doesn't exist, that's a coverage gap — flag it, then invoke `/dashboard`
to build it.

### Architecture

```
gold.semantic_{domain}   -- per-domain, all checks for one dataset
                            built by /dashboard, read by /verify
```

Each domain model is independent. Materialize each as a TABLE after data
refreshes — the output is small (1,000-5,000 rows per domain), reads are
instant. The checks are deterministic given the source data.

### Output schema (every row, every domain)

```
check_category   -- which of the 6 categories
check_name       -- machine name (for matching/dedup)
check_label      -- human-readable label for display
grain            -- what dimension this operates on
period           -- time period covered
value            -- observed value from our data
expected_low     -- lower bound of acceptable range
expected_high    -- upper bound of acceptable range
pass             -- whether the check passed
source           -- benchmark source label (or 'self-check')
source_url       -- URL to verify the benchmark (NULL for self-checks)
note             -- what this check validates
```

### The 6 categories

| Category | What it validates | Auto-generatable? |
|----------|------------------|-------------------|
| **algebraic** | Parts = whole. Shares sum to ~100%. Derived columns match their formula. | Yes — always include |
| **smoothness** | No wild swings. No company gains >50% or loses >40% in one year. No MoM total change >5%. | Yes — always include |
| **bounded_range** | Structural constraints hold every period. Group share 15-21%. No single company >35%. Top-N concentration in expected bands. | Partially — thresholds need domain knowledge |
| **monotonicity** | Trends go the right direction. Total enrollment increasing (pre-2026). PPO share increasing. | Needs domain knowledge |
| **cagr** | Long-run growth rates match published history. 10-year CAGR for total market, specific companies. | Needs external research |
| **structural_break** | Known industry events are visible in the data. CVS replaces Aetna post-2018. Humana dips in 2025. Growth slows post-2022. | Needs external research |

**algebraic** and **smoothness** are mandatory for every domain — they need no
external knowledge and catch the most common pipeline bugs.

**bounded_range**, **monotonicity**, **cagr**, and **structural_break** require
domain research (KFF, MedPAC, SEC filings, earnings transcripts). Built during
`/dashboard` using Exa/Perplexity.

### How semantic checks map to tiers

| Tier | What it proves | Semantic category |
|------|---------------|-------------------|
| Tier 1 (Spot Checks) | Individual values correct | — (still ad-hoc) |
| Tier 2 (Sum Checks) | Algebraic consistency | `algebraic` |
| Tier 3 (Derived Metrics) | External benchmarks match | `cagr`, `bounded_range`, `structural_break` |

The semantic table encodes Tier 2 and Tier 3 durably. Once built, they re-run
every data refresh — no manual verification needed for checks that already pass.

---

## Step 0: Check the Semantic Table (all modes)

Before running any mode, check if semantic checks exist for this domain:

```sql
SELECT check_category,
  COUNT(*) AS checks,
  SUM(CASE WHEN pass THEN 1 ELSE 0 END) AS passed,
  SUM(CASE WHEN NOT pass THEN 1 ELSE 0 END) AS failed
FROM gold.semantic_{domain}
GROUP BY 1 ORDER BY 1
```

Three outcomes:

1. **Table exists, no failures** — strong foundation. Proceed with the
   requested mode. Include the scorecard in all output.

2. **Table exists, failures present** — investigate failures first (Mode 3).
   Failures in the semantic table take priority over ad-hoc checks.

3. **Table doesn't exist** — flag as coverage gap. Suggest invoking
   `/dashboard` to build semantic checks.

Include the semantic scorecard in every verification output:

```
Semantic: gold.semantic_ma_enrollment
  1,923 checks | 1,880 pass | 43 fail
  Failing: 17 smoothness (M&A), 6 bounded (early-year), 5 monotonicity (wobble)
```

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

**The semantic table encodes Tier 2 + 3 durably.** The `algebraic` category
is Tier 2 running automatically. The `cagr` and `bounded_range` categories
are Tier 3 with source URLs.

---

## Mode 1: Pipeline Verify

**When to use:** After extraction (/ingest Gate 3 or Gate 4). Verifies that the
extraction pipeline correctly pulled data from source files.

### Steps

1. **Select 3 sample files** across eras (oldest, newest, mid-history).

2. **For each file, run Tier 1 — Spot Checks:**
   - Open the source document (PDF, XLSX, or CSV)
   - Pick 10 specific values spread across different columns and rows
   - Find the same values in the extracted output
   - Show the comparison as a table with match/mismatch per value

3. **If the data supports it, run Tier 2 — Sum Checks:**
   - Identify additive relationships in the source data
   - Verify they hold in the extracted data
   - Sum checks spanning multiple independently extracted values are stronger
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

3. **In workspace contexts, use workspace schema:**
   `{layer}__{postgres_schema}.{model_name}` — NOT `{layer}.{model_name}`.
   `sql_model_save` does NOT auto-materialize. Call `warehouse_materialize`
   in dependency order: silver → gold → platinum.

4. **Check for fan-out or fan-in bugs:**
   - Does joining in gold multiply rows?
   - Does dedup in silver drop too many rows?
   - Does aggregation in platinum collapse the right dimensions?

5. **Verify ratio computation:**
   - Confirm ratios are computed AFTER aggregation, not averaged
   - Test with a known example

6. **Check temporal alignment in gold:**
   - Are the right time periods joined?

---

## Mode 3: Semantic Verify

**When to use:** After /dashboard builds a platinum model and its companion
semantic checks. Also when investigating data quality concerns, after a data
refresh produces new failures, or when asked "is this data correct?"

This is the primary verification mode for analytical correctness. If semantic
checks exist, start here. If they don't, flag the gap and invoke `/dashboard`.

### Steps

1. **Run the scorecard:**

   ```sql
   SELECT check_category,
     COUNT(*) AS checks,
     SUM(CASE WHEN pass THEN 1 ELSE 0 END) AS passed,
     SUM(CASE WHEN NOT pass THEN 1 ELSE 0 END) AS failed
   FROM gold.semantic_{domain}
   GROUP BY 1 ORDER BY 1
   ```

   If all pass, skip to step 4 (gap analysis).

2. **Investigate failures:**

   ```sql
   SELECT check_category, check_name, period,
     ROUND(value, 2) AS value,
     ROUND(expected_low, 2) AS low,
     ROUND(expected_high, 2) AS high, note
   FROM gold.semantic_{domain}
   WHERE NOT pass
   ORDER BY check_category, check_name, period
   ```

   For each failure, determine the cause using the investigation patterns.

3. **Classify each failure:**

   | Classification | Meaning | Action |
   |---------------|---------|--------|
   | **Pipeline bug** | Data is actually wrong | Fix (invoke /ingest or /dashboard) |
   | **Merger/acquisition** | Company structural change | Document with source URL |
   | **Source data limitation** | Source agency methodology change | Document impact |
   | **Known industry event** | Documented market shift | Document with source URL |
   | **Threshold too tight** | Bounds need adjustment | Adjust with justification |

   **Investigation patterns by category:**

   - **smoothness** — Query years around the swing. Check for company
     appearing/disappearing. Search Exa for M&A. Most are mergers.
   - **bounded_range** — Check if era-specific. Market structure changes
     over decades — bounds for 2015-2025 may not hold for 2009-2012.
   - **monotonicity** — Small wobble (0.2pp) is noise. Large drop (5pp+)
     is a reclassification event. Check the source data.
   - **algebraic** — NEVER classify away. Parts must equal whole. If they
     don't, something is broken. Investigate immediately.
   - **cagr/structural** — Compare against the source URL in the check.
     Wrong benchmark → fix the check. Data disagrees → investigate pipeline.

4. **Gap analysis:**

   List every filter dimension and metric in the platinum model. For each,
   check whether semantic checks cover it:

   ```
   Coverage: platinum.ma_enrollment_dashboard
   ├── segment: MA (covered), PDP (covered)
   ├── distribution: Individual (covered), Group (partial — 1 check)
   ├── network_category: HMO, PPO, Other (all covered)
   ├── parent_organization: top-5 specific + smoothness for >100K
   ├── enrollment: algebraic + monotonicity + CAGR + smoothness
   ├── market_share_pct: algebraic (sum to 100%)
   ├── yoy_delta: algebraic (= enrollment - prior)
   └── yoy_delta_pct: bounded_range + smoothness
   ```

   Flag dimensions with zero or weak coverage. Suggest additions.

5. **External corroboration (when investigating failures):**

   Use Exa/Perplexity to find independent sources:
   - Industry reports (KFF, MedPAC, Avalere, CBO)
   - SEC filings (merger announcements, enrollment disclosures)
   - Earnings transcripts (company-reported metrics — Tier 3 power move)
   - Press releases (enrollment milestones, market share claims)

### Output

```
Semantic Verification: ma_enrollment
├── Scorecard: 1,923 checks, 97.8% pass rate
├── Failures: 43
│   ├── 17 M&A events (documented with source URLs)
│   ├── 12 source data limitations (CMS methodology)
│   ├── 6 early-year bounds (market structure different pre-2013)
│   ├── 5 monotonicity wobble (noise)
│   ├── 3 under investigation
│   └── 0 pipeline bugs
├── Coverage: 8/8 categories, all filter dimensions covered
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

## When Things Fail: Check Logfire

Don't conclude "the data is wrong" until you've checked infrastructure.

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Dashboard 504 | Query >45s | Pre-aggregate in gold |
| Missing bronze data | Parquet 404 in GCS | Re-materialize bronze |
| Silver model fails | Column name mismatch | Fix silver CAST |
| Semantic model fails | CTE error or timeout | Check upstream materialization |
| Spot check mismatch | Extraction error | Trace back to /ingest |

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/verify-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Verification Scorecard: [Dataset/Model Name]

## Mode
[Pipeline / Model / Semantic]

## Semantic Checks
[Scorecard: total checks, pass rate, failure breakdown by classification]
[Coverage: which dimensions/metrics covered, which are gaps]

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
1. The semantic check summary (or a note that checks don't exist yet)
2. Which modes and tiers were run
3. Specific evidence for each (tables, not just "looks good")
4. Every semantic check failure investigated and classified
5. A confidence level with justification
6. Any concerns, ranked by severity

**Never say "the data looks correct" without a scorecard.**
**Never say "all checks pass" without showing the checks.**
**Never leave semantic check failures uninvestigated.**
