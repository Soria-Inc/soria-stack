# SoriaStack — Data Principles & Ethos

> These principles are extracted from real Claude Code sessions at Soria Analytics.
> Each one maps to at least one session where either Adam stated it explicitly
> or the AI violated it and wasted time.
>
> They are injected into every skill's preamble. They are the source of truth.

---

## The Philosophy

A single person with AI and the right data tooling can build what used to take
a team of data engineers. The extraction barrier is gone. What remains is
**judgment** — knowing what to extract, at what grain, for what audience, and
proving it's correct.

SoriaStack is a set of cognitive modes and composable functions — not a framework.
When a gate or pattern doesn't fit the problem, document why and work around it.
**Never force the data to fit the system.**

---

## Pipeline Discipline

### 1. Think before you build
Before creating any scraper, group, schema, or extractor: download a sample file, open it, understand the format, check how many years of history exist, and identify where formats changed. Never auto-create anything without looking first.

### 2. Test on 3 before testing on all
Pick the oldest file, the newest file, and one from mid-history. Extract those 3 first. Compare each against the source. Only after all 3 pass, run the full batch. This prevents burning 7+ minutes on a wrong approach.

### 3. Extract wide, transform in SQL
When the source has a wide table (measures as columns), extract it as-is — one row per entity with N value columns. Unpivot to long format in the silver SQL model, not in the extractor. Complex reshaping during extraction fails; simple extraction is reliable extraction.

### 4. Bronze loads all raw data as-is. Silver defines types, unpivots, and cleans
- **Bronze** = `SELECT *` from the warehouse table with version pin (DuckLake snapshot), no transforms. `kind EXTERNAL` or VIEW wrapper over DuckLake via `@ducklake()` macro. **Bronze tables must be materialized in MotherDuck before any downstream work.** Never run dashboards or silver models on un-materialized DuckLake views.
- **Silver** = explicit `CAST` on every column, unpivot wide metric columns into `metric_name`/`metric_value` rows, rename to clean snake_case, filter invalid records. One silver model per bronze table. No joins in silver.

### 5. Silver gets everything — Gold decides what matters
In silver, unpivot ALL metric columns except dimension columns (identifiers, addresses, dates, provider type). If someone needs "Prepaid Expenses" or "PT Medicaid visits," they shouldn't have to go back to bronze. Gold is where you join across silvers, apply business logic, de-cumulate YTD values, and decide the final grain.

### 6. Don't mutate extraction outputs
If an extraction produced wrong data, fix the extractor/prompt and re-extract. Never hand-edit a CSV or patch values in the warehouse. The pipeline must be reproducible end-to-end.

### 7. Derivable data gets excluded from extraction schemas
Don't extract totals, subtotals, grand totals, or percentages that are computable from atomic rows. Extract the atomic values. Compute totals/ratios in SQL where they can be verified.

---

## Human Judgment Gates

### 8. Schema design is a conversation, not a decision
The AI proposes the schema (columns, types, grouping strategy). The human pushes back: "shouldn't these be unpivoted?", "that column is derivable, skip it", "I want one group per company, not five." Schema proposals are presented as options with tradeoffs, never auto-committed.

### 9. Historical names stay historical; typos get fixed
Gateway→Highmark is a real corporate transition — preserve both names and handle succession in the SQL model with a crosswalk table. EBIDA→EBITDA is an OCR/typo error — map it to the canonical in value mapping. The AI must flag ambiguous cases and let the human decide which category they fall into.

### 10. Validate with your eyes, not just code
Row counts passing doesn't mean the data is right. Open the extracted CSV alongside the source PDF. Spot-check 5 random values from different eras. Look at distribution charts across time — does the shape make sense? Is enrollment trending roughly how you'd expect?

### 11. Compare extraction against the source
For pipeline verification: take 3 sample files across eras. For each, pull 10 specific values from the source document (PDF, XLSX) and compare cell-by-cell against the extracted CSV. Show the comparison as a table with ✅/❌ per value. This is the definition of "extraction works."

---

## SQL & Dashboard Correctness

### 12. Ratios compute after aggregation, never before
The formula is always `SUM(numerator) / NULLIF(SUM(denominator), 0)`. Never `AVG(pre_computed_ratio)`. Market share = `SUM(company_enrollment) / SUM(total_enrollment)`, not the average of per-plan-type market shares. This prevents the 171% market share class of bugs.

### 13. One table, many views
Don't create 6 platinum tables for enrollment, market share, YoY, plan count, company mix when they're all the same data through different lenses. Build one silver/gold table at the right grain. Use `@dashboard` page controls and `valueOptions` to switch metrics. Pre-compute only what the frontend can't derive (complex window functions, cross-dataset joins).

### 14. Grain is the hardest SQL decision — answer it first
Before writing any SQL model, state explicitly: "One row = one [entity] per [time period] per [dimensions]." Then check: does the pivot/dashboard aggregate across any dimension not in the display? If yes, will ratio metrics produce garbage? If yes, either drop that dimension from the grain or only include additive metrics (enrollment, counts) at that grain.

### 15. QUALIFY for dedup, not subqueries
When the same data appears in multiple source files (e.g., CA Medicaid publishes full snapshots each month), dedup in silver with `QUALIFY ROW_NUMBER() OVER (PARTITION BY [natural key] ORDER BY _source_file DESC) = 1`. Bronze stays a true raw archive.

### 16. Every column needs a business label
`column_descriptions` in the MODEL block is required for every silver, gold, and platinum model. These are display names for the dashboard UI — keep them short: `mlr_pct = 'Medical Loss Ratio'`, not `mlr_pct = 'Medical Loss Ratio: amount_incurred / premiums_earned * 100'`.

---

## Verification Hierarchy

### 17. Tier 1: Spot checks are evidence
Pick random values from the source, find them in the output. Necessary but not sufficient — you can pass spot checks and still have systematic errors.

### 18. Tier 2: Sum checks are proof
If `Revenue = Premiums + Products + Services + Investment` within 5% for every year across 10 years, then four independently extracted line items are all correct, all mapped to the right canonical, and all denominated correctly. One wrong denomination (thousands vs millions) blows the sum check immediately. Prefer algebraic consistency checks over random sampling when the data supports it.

### 19. Tier 3: Derived metric checks are the gold standard
Compute `Medical Care Ratio = Medical Costs / Premiums`, compare against the company's press release. If it matches, both numerator and denominator are proven correct. Compute `UHC Revenue as % of Total`, compare against Bullfincher. These require multiple independently extracted values to be correct AND correctly mapped — they're the hardest to pass by accident.

### 20. External corroboration closes the loop
After internal consistency checks, find an external source that independently reports the same metric. If your calculated enrollment mix matches an external report, the data is proven end-to-end. If it doesn't, investigate — the discrepancy reveals either a pipeline bug or a data definition mismatch.

---

## Analytical Architecture (Planning)

### 21. Design the answer, then find the data
Start from "what does the analyst at BofA need to see?" That determines the grain, the joins, the enrollment weighting approach, and which sources to prioritize. Don't start with "what's available" and hope it answers the question.

### 22. Coverage and overlap before extraction
Before scraping anything, map what combination of sources gives 100% coverage with no double-counting. Example: FL County MMA covers 73% (plan + county granularity), Region FFS/PACE covers 27% (no plan assignments). County LTC is a *subset* of MMA — adding it would double-count. Document the coverage math before building.

### 23. Temporal semantics before temporal joins
When joining time-series across sources, state what the join *means* in business terms. "2026 star ratings (released Oct 2025) → October 2025 enrollment" is a semantic decision: that's when analysts evaluate these ratings. Then verify: "Do we have October enrollment for the years we need?" If not, document the gap.

### 24. Inventory before action
First step of any new work: check what scrapers, workspaces, groups, and models already exist. Query the database. Don't build what's already there. Don't write a new scraper when files are already downloaded.

### 25. Classify effort before committing
- **Tier 1:** Clean CSVs with consistent schema → scrape + group + schema map + publish, no extraction needed.
- **Tier 2:** Simple Excel/CSV with format variations → scrape + extract + publish.
- **Tier 3:** PDFs with tables and format drift across years → full pipeline (scrape + group + detect + extract + value map + publish).
- **Tier 4:** Multi-format sources (mix of PDFs, Excel, CSVs across years) → Tier 3 per format + era-specific handling.

---

## Pipeline Architecture

### 26. ETVL, not ETL
The pipeline is **Extract → Transform → Value-map → Load**. Transform is arbitrary code on files — not limited to per-file extractors. When the source requires waterfall logic (XBRL → HTML fallback → PDF), cross-file association, or non-deterministic AI re-validation, the Transform step must support it. Flag this complexity at scout time, not mid-pipeline.

### 27. Functions over frameworks
Pipeline utilities (file normalization, header detection, proxy management, Gemini extraction) should be composable functions you can call, not a rigid framework you're forced through. A base scraper with deletable defaults beats a mandatory template.
