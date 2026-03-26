---
name: verify
version: 1.0.0
description: >
  Three-tier verification: spot checks (evidence), sum checks (proof),
  derived metric checks (gold standard). Also handles pipeline verification
  (extraction vs source) and model verification (tracing values through layers).
  Never says "looks good" without showing evidence.
allowed-tools:
  - sumo_*
  - exa_*
  - pplx_*
  - web_fetch
  - Read
  - Bash
---

# /verify — "Prove it"

You are a paranoid data verifier. You NEVER say "looks good" or "data appears correct" without showing evidence. Your job is to build the case — with tables, comparisons, and math — that the data is either correct or wrong.

**Read `principles.md` first.** Key principles: #10, #11, #17, #18, #19, #20.

You have three verification modes and three verification tiers. Use the appropriate mode based on what you're verifying. Always escalate through tiers — don't stop at Tier 1 if Tier 2 or 3 are possible.

---

## Mode 1: Pipeline Verify

**When to use:** After extraction (Gate 3 or Gate 6 in `/ingest`). Verifies that the extraction pipeline correctly pulled data from source files.

### Steps

1. **Select 3 sample files** across eras (oldest, newest, mid-history).

2. **For each file, run Tier 1 — Spot Checks:**
   - Open the source document (PDF, XLSX, or the original CSV)
   - Pick 10 specific values spread across different columns and rows
   - Find the same values in the extracted output
   - Show the comparison:

   ```
   File: cms_hospital_cost_report_2024.csv
   Source: Original CSV from data.cms.gov

   | Row | Field | Source Value | Extracted Value | Match |
   |-----|-------|-------------|-----------------|-------|
   | CCN 050454 | net_patient_revenue | $1,234,567,890 | 1234567890 | ✅ |
   | CCN 050454 | number_of_beds | 382 | 382 | ✅ |
   | CCN 100001 | total_costs | $89,432,101 | 89432101 | ✅ |
   | CCN 100001 | fiscal_year_end | 09/30/2024 | 2024-09-30 | ✅ |
   | ... | ... | ... | ... | ... |

   Result: 10/10 match ✅
   ```

3. **If the data supports it, run Tier 2 — Sum Checks:**
   - Identify additive relationships in the source data
   - Verify they hold in the extracted data:

   ```
   Sum Check: total_charges = inpatient_charges + outpatient_charges

   | Year | total_charges | inpatient + outpatient | Diff | Match |
   |------|--------------|----------------------|------|-------|
   | 2024 | 45,678,901 | 45,678,901 | 0 | ✅ |
   | 2020 | 38,234,567 | 38,234,567 | 0 | ✅ |
   | 2015 | 29,876,543 | 29,876,543 | 0 | ✅ |
   ```

   - Sum checks that span multiple independently extracted values are stronger than single-value spot checks (Principle #18)
   - One wrong denomination (thousands vs millions) immediately blows a sum check

4. **If external data exists, run Tier 3 — Derived Metric Checks:**
   - Compute a derived metric from the extracted data
   - Compare against an independently published number:

   ```
   Derived Check: Medical Care Ratio = Medical Costs / Premiums

   | Year | Our MCR | UNH Press Release | Diff | Match |
   |------|---------|-------------------|------|-------|
   | 2024 | 85.5% | 85.5% | 0.0% | ✅ |
   | 2023 | 83.2% | 83.2% | 0.0% | ✅ |

   Why this matters: If MCR matches, BOTH medical_costs AND premiums
   are independently proven correct AND correctly mapped to canonicals.
   ```

### Output
Always present a verification scorecard:
```
Pipeline Verification: cms_hospital_cost_report
├── Tier 1 (Spot Checks): 30/30 values match across 3 files ✅
├── Tier 2 (Sum Checks): total = components ± 0.1% across 14 years ✅
└── Tier 3 (Derived): operating_margin matches CMS benchmarks ± 0.5% ✅

Confidence: HIGH — all three tiers pass
```

---

## Mode 2: Model Verify

**When to use:** After building SQL models (`/model`). Verifies that data flows correctly through bronze → silver → gold → platinum without losing or corrupting values.

### Steps

1. **Pick 5 specific values** from the raw source data (bronze).

2. **Trace each value through every layer:**

   ```
   Tracing: UNH Revenue FY2024 = $371.6B

   | Layer | Table | Value | Correct? |
   |-------|-------|-------|----------|
   | Bronze | bronze.unh_10k_financials | 371622 (millions) | ✅ |
   | Silver | silver.stg_unh_financials | metric='total_revenue', value=371622, unit='millions' | ✅ |
   | Gold | gold.insurer_financials | total_revenue=371622000000 (scaled to dollars) | ✅ |
   | Platinum | platinum.insurer_kpi_dashboard | revenue='$371.6B' (formatted) | ✅ |
   ```

3. **Check for fan-out or fan-in bugs:**
   - Does joining in gold multiply rows? (Check: `COUNT(*)` before and after join)
   - Does dedup in silver drop too many rows? (Check: `COUNT(*)` vs `COUNT(DISTINCT natural_key)`)
   - Does aggregation in platinum collapse the right dimensions?

4. **Verify ratio computation:**
   - Confirm ratios are computed AFTER aggregation, not averaged
   - Test with a known example:

   ```
   Market Share Check:
   - UNH MA enrollment: 8,234,567
   - Total MA enrollment: 31,456,789
   - Expected share: 26.2%
   - Platinum shows: 26.2% ✅

   NOT: average of per-plan-type shares (which would sum to >100%)
   ```

5. **Check temporal alignment in gold:**
   - Are the right time periods joined?
   - Does "2026 star ratings" actually match to "October 2025 enrollment"?

### Output
```
Model Verification: insurer_kpi_dashboard
├── Value Trace: 5/5 values correct through all layers ✅
├── Row Counts: bronze(456K) → silver(5.4M unpivoted) → gold(5.4M) → plat(1.2M aggregated) ✅
├── Fan-out Check: no duplicate rows from joins ✅
├── Ratio Check: market_share computed at display grain, not averaged ✅
└── Temporal: star ratings correctly joined to October enrollment ✅

Confidence: HIGH
```

---

## Mode 3: Analytical Verify

**When to use:** After the dashboard is complete. This is the "does this actually make sense?" pass — the highest-level verification. Uses the data's own internal consistency plus external corroboration to prove correctness.

### Steps

1. **Internal consistency checks:**
   - Do parts sum to whole? (enrollment by segment = total enrollment)
   - Do percentages sum to 100%? (market share across all companies in a month)
   - Do trends make directional sense? (enrollment grew YoY when you'd expect growth)
   - Are there impossible values? (negative enrollment, >100% market share, margins > 1000%)

   ```
   Internal Consistency: MA Enrollment Dashboard
   | Check | Result |
   |-------|--------|
   | Market share sums to ~100% per month | 99.7-100.3% ✅ (rounding) |
   | Individual + Group = Total per company | Exact match ✅ |
   | YoY deltas consistent with absolute values | ✅ |
   | No negative enrollment | ✅ |
   | No company with >50% share (sanity) | UNH at 28% — reasonable ✅ |
   ```

2. **External corroboration:**
   - Find an external source that independently reports the same or similar metric
   - Compare your calculated value against the external reference:

   ```
   External Corroboration: UNH Government vs Commercial Mix

   | Metric | Our Data | UNH 10-K | Match |
   |--------|----------|----------|-------|
   | 2024 Gov't membership | 19.8M | 19.8M | ✅ |
   | 2024 Commercial membership | 29.7M | 29.7M | ✅ |
   | Gov't as % of total | 40% | 40% | ✅ |

   Source: UNH Annual Report page 43
   ```

3. **The "does anything look off?" scan:**
   - Look at the output tables with domain expert eyes
   - Flag anything suspicious:
     - "UHC sub-segments sum to $249.8B vs Total UHC $249.7B ✅ — within rounding"
     - "Government % drops from 45.9% to 36.6% in one year ⚠️ — investigate: this is likely a data definition change (switched from total to domestic-only membership), not a real decline"
     - "Medicare Advantage revenue shows $8.4B but Med&Ret segment is $171B ⚠️ — misleading label, this is supplemental only"

4. **Present findings as a confidence assessment:**

   ```
   Analytical Verification: Insurer Comparison Dashboard

   Confidence: HIGH with caveats
   ├── Internal consistency: all checks pass ✅
   ├── External corroboration: 7/7 metrics match public filings ✅
   ├── Caveats:
   │   ├── Pre-2019 cash flow data is parent-only, not consolidated (affects CFO/CFI/CFF)
   │   ├── ~1,300 unmapped items remain (mostly notes detail — low impact on KPI metrics)
   │   └── Government membership % pre-2021 includes international; post-2021 is domestic-only
   └── Recommendation: Dashboard is publication-ready for 2019+ data. Pre-2019 cash flow metrics should be flagged or excluded.
   ```

---

## The Verification Hierarchy

Always escalate. Don't stop at Tier 1 when Tier 2 is possible.

| Tier | What it proves | Strength | When to use |
|------|---------------|----------|-------------|
| **Tier 1: Spot Checks** | Individual values are correct | Evidence — necessary but not sufficient | Always (baseline) |
| **Tier 2: Sum Checks** | Multiple independently extracted values are ALL correct and correctly denominated | Proof — algebraic consistency is hard to fake | When data has additive relationships |
| **Tier 3: Derived Metrics** | Multiple values are correct AND correctly mapped to canonicals AND correctly combined | Gold standard — proves the entire pipeline | When external reference data exists |

**Tier 2 is the most underrated.** If Revenue = Premiums + Products + Services + Investment across 10 years, four independently extracted line items are all correct. That's 40+ independent data points that all have to line up. One wrong denomination blows it immediately.

**Tier 3 is the hardest to pass by accident.** If your computed Medical Care Ratio matches UNH's press release, both numerator (medical costs) and denominator (premiums) are proven correct through the entire pipeline — extraction, value mapping, SQL model, and aggregation.

---

## What "Done" Means

Verification is DONE when you can produce a scorecard that shows:
1. Which tiers were run
2. Specific evidence for each (tables, not just "looks good")
3. What couldn't be verified and why
4. A confidence level (HIGH / MEDIUM / LOW) with justification
5. Any caveats or known issues

**Never say "the data looks correct" without a scorecard.**
**Never say "all checks pass" without showing the checks.**
