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

## Working With Data (How to Think)

### Simplicity over complexity
If you can answer the question with 1 dive and filter controls, don't build 5 dives.
If you can answer it with 1 marts model at the right grain, don't build 6 tables through different lenses.
If you can extract wide and transform in SQL, don't write a complex extractor.
The simplest approach that produces correct, verifiable data wins. Always.

### Challenge before building
When the user asks for 5 dives, push back: "Can this be 1 dive with filter controls
slicing it?" State your case. Don't just do what was asked if a simpler approach serves the
same need. When the user asks for a complex extraction pipeline, push back: "Can we extract
wide and let SQL do the reshaping?" Take a position. Expect to be overruled sometimes —
that's fine. The point is the conversation happened.

### Never say "looks good" without evidence
Every claim of correctness must have a table, a comparison, or a screenshot backing it up.
"Data appears correct" is banned. "30/30 spot check values match source ✅" is acceptable.

---

## Resolver Pattern (Context Efficiency)

### Skills as resolvers
Each skill's `description` field in the YAML header serves as a resolver. Claude Code reads
all skill descriptions and auto-applies the right one based on what the user says. Write
descriptions as precise trigger conditions, not marketing copy.

Good: "Use when asked to 'scrape this', 'build the pipeline', 'extract this data'. Proactively
suggest when the user has completed /status and is ready to build."

Bad: "A comprehensive data ingestion skill for building pipelines."

### Just-in-time context loading
Don't load everything upfront. The skill is loaded once at invocation (~200-400 lines).
Total context at any point: skill + ETHOS, not every skill in the pack.

---

## Completion & Escalation

### Completion status
Every skill workflow ends with one of:
- **DONE** — All steps completed successfully. Evidence provided for each claim.
- **DONE_WITH_CONCERNS** — Completed, but with issues the user should know about. List each concern.
- **BLOCKED** — Cannot proceed. State what is blocking and what was tried.
- **NEEDS_CONTEXT** — Missing information required to continue. State exactly what you need.

### Escalation rules
It is always OK to stop and say "this is too hard" or "I'm not confident in this result."
Bad data is worse than no data.

- If 3 extraction approaches fail: STOP and escalate. Don't keep trying variations.
- If the grain decision feels wrong but you can't articulate why: STOP and ask.
- If you're about to average pre-computed ratios: STOP — you're about to create the 171% bug.

Escalation format:
```
STATUS: BLOCKED | NEEDS_CONTEXT
REASON: [1-2 sentences]
ATTEMPTED: [what you tried]
RECOMMENDATION: [what the user should do next]
```

### Learning from failures
When a skill completes, log what happened in the artifact:
```
## Outcome
Status: DONE_WITH_CONCERNS
Lesson: Gate 3 caught a denomination mismatch (thousands vs millions)
  that would have propagated through the entire pipeline.
  Sum checks (Tier 2) found it, spot checks (Tier 1) missed it.
Principle reinforced: #18 (sum checks are proof)
```

These logs feed into `/lessons` for continuous improvement.

---

## CLI-First Tool Invocation

### All operations go through `soria`
Skills drive the platform exclusively through the `soria` CLI. Never invoke
MCP tools directly. Never hit internal Python modules. The CLI surface is:

```
soria env       list | branch | teardown | restore | checkout | status | diff
soria scraper   run | test | upload-urls | confirm
soria warehouse query | publish | status | unpublish | materialize
soria schema    read | update | mappings-read | mappings-update
soria value     read | index | map
soria model     list | get
soria extractor list
soria group     list | show | create | assign
soria file      show | list | open | reprocess
soria db        query | schema
soria list      soria detect  soria extract  soria validate  soria revert
soria auth      soria --env <local|prod|URL>
```

If a command the skill needs doesn't exist yet, flag it clearly — don't fall
back to MCP or direct module imports.

### Environment awareness is mandatory
Every skill preamble reports `soria env list` active state. Writes against
prod require explicit acknowledgment — writes while silently pointing at prod
are never acceptable.

---

## Pipeline Discipline

### 1. Think before you build
Before creating any scraper, group, schema, or extractor: download a sample file, open it, understand the format, check how many years of history exist, and identify where formats changed. Never auto-create anything without looking first.

### 2. Test on 3 before testing on all
Pick the oldest file, the newest file, and one from mid-history. Extract those 3 first. Compare each against the source. Only after all 3 pass, run the full batch. This prevents burning 7+ minutes on a wrong approach.

### 3. Extract wide, transform in SQL
When the source has a wide table (measures as columns), extract it as-is — one row per entity with N value columns. Unpivot to long format in the silver SQL model, not in the extractor. Complex reshaping during extraction fails; simple extraction is reliable extraction.

### 4. Bronze loads raw data. Silver types, unpivots, and cleans. Gold joins. Marts ship.
- **Bronze** = raw warehouse tables published from extraction. `soria warehouse publish` is the only way rows land here. Don't hand-insert.
- **Silver** = explicit `CAST` on every column, unpivot wide metric columns into `metric_name`/`metric_value` rows, rename to clean snake_case, filter invalid records. One silver model per bronze table. No joins in silver.
- **Gold** = joins across silvers, business logic, entity resolution, temporal alignment, parent-company rollups.
- **Marts** (the dive's dbt project, `soria_dives`) = dashboard-ready output. One marts model per dive. Tests via `dbt test`.

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

## SQL & Dive Correctness

### 12. Ratios compute after aggregation, never before
The formula is always `SUM(numerator) / NULLIF(SUM(denominator), 0)`. Never `AVG(pre_computed_ratio)`. Market share = `SUM(company_enrollment) / SUM(total_enrollment)`, not the average of per-plan-type market shares. This prevents the 171% market share class of bugs.

### 13. One marts model, many filter combinations
Don't create 6 marts models for enrollment, market share, YoY, plan count, company mix when they're all the same data through different lenses. Build one marts model at the right grain. Expose filters through the dive manifest. Pre-compute only what the frontend can't derive (complex window functions, cross-dataset joins).

### 14. Grain is the hardest SQL decision — answer it first
Before writing any SQL model, state explicitly: "One row = one [entity] per [time period] per [dimensions]." Then check: does the dive pivot/chart aggregate across any dimension not in the display? If yes, will ratio metrics produce garbage? If yes, either drop that dimension from the grain or only include additive metrics (enrollment, counts) at that grain.

### 15. QUALIFY for dedup, not subqueries
When the same data appears in multiple source files (e.g., CA Medicaid publishes full snapshots each month), dedup in silver with `QUALIFY ROW_NUMBER() OVER (PARTITION BY [natural key] ORDER BY _source_file DESC) = 1`. Bronze stays a true raw archive.

### 16. Every column needs a business label
Every column in a silver, gold, or marts model needs a display name that the dive manifest can reference. Keep them short: `mlr_pct = 'Medical Loss Ratio'`, not the full formula. Column descriptions live in the dbt model config, not scattered across components.

---

## Verification Hierarchy

### 17. Tier 1: Spot checks are evidence
Pick random values from the source, find them in the output. Necessary but not sufficient — you can pass spot checks and still have systematic errors.

### 18. Tier 2: Sum checks are proof
If `Revenue = Premiums + Products + Services + Investment` within 5% for every year across 10 years, then four independently extracted line items are all correct, all mapped to the right canonical, and all denominated correctly. One wrong denomination (thousands vs millions) blows the sum check immediately. Prefer algebraic consistency checks over random sampling when the data supports it.

### 19. Tier 3: Derived metric checks are the gold standard
Compute `Medical Care Ratio = Medical Costs / Premiums`, compare against the company's press release. If it matches, both numerator and denominator are proven correct. Compute `UHC Revenue as % of Total`, compare against an external source. These require multiple independently extracted values to be correct AND correctly mapped — they're the hardest to pass by accident.

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
First step of any new work: check what scrapers, environments, groups, and dives already exist. `soria list`, `soria env list`, filesystem walk of `frontend/src/dives/`. Don't build what's already there. Don't write a new scraper when files are already downloaded.

### 25. Classify effort before committing
- **Tier 1:** Clean CSVs with consistent schema → scrape + group + schema map + publish, no extraction needed.
- **Tier 2:** Simple Excel/CSV with format variations → scrape + extract + publish.
- **Tier 3:** PDFs with tables and format drift across years → full pipeline (scrape + group + detect + extract + value map + publish).
- **Tier 4:** Multi-format sources (mix of PDFs, Excel, CSVs across years) → Tier 3 per format + era-specific handling.

---

## Pipeline Architecture

### 26. ETVL, not ETL
The pipeline is **Extract → Transform → Value-map → Load**. Transform is arbitrary code on files — not limited to per-file extractors. When the source requires waterfall logic (XBRL → HTML fallback → PDF), cross-file association, or non-deterministic AI re-validation, the Transform step must support it. Flag this complexity at plan time, not mid-pipeline.

### 27. Functions over frameworks
Pipeline utilities (file normalization, header detection, proxy management, Gemini extraction) should be composable functions you can call, not a rigid framework you're forced through. A base scraper with deletable defaults beats a mandatory template.

---

## Dive Invariants

### 28. Every dive ships with verify checks
A dive marts model without rows in `frontend/src/dives/dbt/seeds/verifications.csv`
is incomplete. Verify checks validate data against external benchmarks and
self-consistency rules, filtered per-dive by the `model` column. Add at
least ~15 rows covering top companies × key metrics × key periods for the
new marts model, plus a few bounded-range rows for overall totals. Every
non-self-check row needs a real `source` + `source_url` citation (SEC
filing, KFF report, CMS data). Refresh via `dbt seed --select verifications`.
The dive component picks them up automatically via `useDiveVerifications`.

### 29. Every dive ships with methodology + verify surfacing
The dive is not "done" until customers can answer two questions from the
UI itself:
- **"How is this built?"** — the component must surface methodology content
  (sources, metric formulas, grain, update cadence, known gotchas) via
  `MethodologyModal` or an equivalent panel in `DivePageHeader`. Per-element
  information buttons are preferred over per-page walls of text.
- **"How do we know it's right?"** — the component must surface verify
  check results via `VerifyModal` and per-cell `VerifyTooltip`, backed by
  rows in the shared verifications seed (#28). The `last_dbt_run` and
  `last_dbt_test` timestamps must be visible so users know how fresh the
  checks are (populated by the `vite-dbt-sync` Vite plugin).

These surfaces are a contract with the customer. Shipping a dive without
them is shipping opaque data.

### 30. Dual-mode loading is the dive performance contract
Dives load via Postgres proxy first (~500ms first paint) and upgrade to
DuckDB-WASM in the background (~20s to warm). The skill must distinguish
"still warming up" from "broken" when validating load. A dive that only
works after WASM warms is a bug — the Postgres proxy path must always
return correct data first.

### 31. Manifest is the config — no YAML, no page-level metadata
A dive's data contract lives in a single `{dive}.manifest.ts` file:
`{ table, columns, where, filters, groupBy }`. The manifest feeds both
`useDiveData` at runtime and `/preview` at design time. If you need a new
filter, add it to the manifest — never hardcode WHERE clauses in the
component. The manifest is the source of truth for what data the dive
needs; anything else is drift.

---

## Promotion & Rollback

### 32. Diff-based promotion, never delete-all-insert-all
Promotion computes the diff against the `cloned_at` snapshot and pushes only
new/modified/deleted rows — it never wipes and re-inserts. An empty
environment promoted over prod must be a no-op. This prevents the class of
bugs where a code-only branch silently wipes production metadata.

### 33. Production is git + CI, not a command
There is no `soria promote`. The promotion flow is:
```
soria env diff → git push → gh pr create → CI runs dbt run + frontend deploy
```
Promotion cannot be triggered imperatively. The PR is the audit trail.
Merge is the gate. CI is the executor.

### 34. `soria revert` is the safety net — use it, don't manually undo
When a promote breaks something, `soria revert` deletes the promoted rows
from the target branch. Never hand-write DELETE statements to undo a promote.
Never force-push to roll back a PR. The revert command is the authoritative
reversal — use it.

---

## Agent Hygiene

### 35. Don't race the interactive agent
The Modal sandbox interactive agent verifies PRs, replies to comments, and
posts investigations to Linear. Skills that operate on open PRs (`/promote`,
`/dashboard-review`) must check for active agent runs and defer to them. Don't
duplicate work the agent is already doing. Don't comment on PRs the agent is
handling. If your skill sees a stuck agent run, surface it in the report —
don't try to fix it.
