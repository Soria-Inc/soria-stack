---
name: map
version: 2.0.0
description: |
  Value mapping — normalize raw values to canonical forms across eras and sources.
  Semantic reasoning about whether two values represent the same concept.
  Drives the Soria platform through the `soria value` CLI — never MCP.
  Use when asked to "value map", "normalize values", "canonical", "map these values",
  or when /ingest is done and values need normalization before /dive.
  Proactively invoke this skill (do NOT map values ad-hoc) when /status shows
  unmapped values or /ingest flags value drift across eras.
  Use after /ingest, before /dive. (soria-stack)
benefits-from: [ingest]
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: map"
echo "---"
echo "Active environment:"
soria env status 2>&1 || echo "  (soria CLI not authed — run /env first)"
echo "---"
echo "Checking for ingest artifacts..."
ls -t ~/.soria-stack/artifacts/ingest-*.md 2>/dev/null | head -3
```

**Before proceeding:** Read the `soria env status` output. If the active
environment type is `prod`, refuse to write any value mappings unless the
user explicitly acknowledges. For dev/preview envs, proceed normally.

Read `ETHOS.md`. Key principles: #9 (historical names vs typos), #6 (don't
mutate outputs).

**Check for prior ingest work:** If an ingest artifact exists, read it — it has
the group IDs, table names, and schema. If /plan exists, check if it specified
V-phase verification criteria.

## Skill routing (always active)

When the user's intent shifts mid-conversation, invoke the matching skill —
do NOT continue ad-hoc:

- User wants to check pipeline status → invoke `/status`
- User wants to go back to extraction → invoke `/ingest`
- User says "now build the dive" → invoke `/dive`
- User wants to verify the mapped values → invoke `/verify`

**After /map completes, suggest `/dive`** to build a dive on the clean data.

---

# /map — "Is this the same thing?"

You are a value mapping specialist. Your job is to normalize raw extracted values
to canonical forms — deciding whether two different strings represent the same
concept, a historical name change, a typo, or genuinely different things.

**Where this state lives:** value mappings are stored in the env's Neon
Postgres, not in git. You author them via `soria value index` / `soria value
map` and they promote to prod via `soria env diff` + PR merge (diff-based
promotion — #32). You don't need to commit anything in this skill unless
you're also editing a downstream SQL model that reads the mapped values.

**This is semantic reasoning, not string matching.** "Drug Expense" vs "Drugs
Expense" is a typo. "Gateway Health" vs "Highmark" is a corporate transition.
"Adjusted Discharges" vs "Adjusted Discharges per Calendar Day" is a methodology
change that requires human judgment.

---

## Step 1: Survey the Landscape

Before mapping anything, understand the scope.

For each group, check value mapping status:
```bash
soria value read --group {group_id}
```

Present a status table:

```
| Column | Canonicals | Mapped | Unmapped | Status |
|--------|-----------|--------|----------|--------|
| metric_name | 30 | 75 | 52 | Partial |
| segment_type | 0 | 0 | 3 | Not started |
| segment_value | 1 | 3 | 11 | Mostly unmapped |
| comparison_period | 3 | 6 | 7 | Partial |
| report_date | 0 | 0 | 66 | No mapping needed (raw dates) |
| value | 0 | 0 | 0 | Numeric, skip |
```

**Skip columns that don't need mapping:** numeric values, dates, IDs.
Focus on categorical columns with string values that vary across eras.

---

## Step 2: Index Values

For columns that need mapping, index the distinct values:
```bash
soria value index --group {group_id} --column metric_name
```

This extracts all unique values from the extracted files and stores them
for mapping.

---

## Step 3: Classify Each Value

For each unmapped value, classify it:

### Transcript-grounded canonical names

When choosing canonical names for ambiguous metrics, search mempalace/earnings
transcripts for how the industry actually refers to this concept. Use
`mcp__openclaw__mempalace_search` with `wing=earnings` for ticker-specific
phrasing, or `wing=granola` for internal meeting context.

- Data has `benefit_expense_ratio` and `medical_loss_ratio` → search for
  "benefit expense ratio medical loss ratio" — different companies use
  different terms for the same concept. Pick the one analysts use most
  commonly as the canonical.
- Data has `adjusted_discharges` vs `adjusted_discharges_per_calendar_day` →
  search for "adjusted discharges per calendar day" to understand if the
  industry treats these as the same metric or different ones.

This is especially valuable for cross-source mapping where Kaufman Hall uses
one name and Strata uses another — transcripts tell you the shared canonical.

### Category 1: Typo / OCR Error → Auto-fix
- `Operating EBIDA Margin` → `Operating EBITDA Margin` (missing T)
- `Drug Expense` → `Drugs Expense` (singular/plural)
- `Bad Debt And Charity` → `Bad Debt and Charity` (casing)
- `NPSr` → `NPSR` (case error)

These are safe to map without human review. Do them in bulk.

### Category 2: Naming Convention Change → Map with Explanation
- `Month-Over-Month` → `Month-over-Month` (hyphenation)
- `500plus` → `500+` (encoding)
- `Year-Over-Year 2020` → `Year-over-Year 2020` (casing)

Safe to map, but document the convention chosen.

### Category 3: Methodology Change → Flag for Human Review
- `Adjusted Discharges` → `Adjusted Discharges per Calendar Day`
  (same metric, different normalization basis)
- `Total Labor Expense` vs `Labor Expense per Calendar Day`
  (absolute vs rate — are these comparable for YoY?)

**These require human judgment.** Present the pair, explain the difference,
and ask: "Should these map to the same canonical? For your use case (YoY
growth rates), the values are comparable because..."

### Category 4: Historical Corporate Transition → Preserve Both
- `Gateway Health` → `Highmark Inc.` (acquisition)
- `WellPoint` → `Anthem` → `Elevance Health` (rebranding)

Don't map these to one canonical. Create a crosswalk table or handle
succession in the SQL model (Principle #9).

### Category 5: Genuinely Distinct → Create New Canonical
- `CARES Expense` vs `Non-CARES Expense` (different concepts)
- `Revenue` vs `Revenue (w/ CARES)` (different metrics)

These aren't variants — they're different things. Each gets its own canonical.

### How canonicals are created — do NOT create them manually
Map any unmapped value to another unmapped value and the system auto-promotes
the target to canonical. Every other value with that same text across all files
gets mapped automatically. Never create canonical records by hand — just
map unmapped-to-unmapped and let the system handle it.

---

## Step 4: Execute Mappings

Work column by column. For each column:

1. **Do the easy wins first** — typos, casing, encoding. These can be batched:
   ```bash
   soria value map --group {group_id} --column metric_name \
     --from "{raw_value}" --to "{canonical_value}"
   ```

2. **Present methodology changes** — show the human what you'd map and why.
   Wait for approval on each ambiguous pair.

3. **Flag corporate transitions** — present the full succession timeline.
   Let the human decide how to handle it.

4. **Create new canonicals** for genuinely distinct values.

### Batch pattern (from real sessions)

For columns with many typo variants (e.g., Kaufman Hall metric_name had 75
variants), batch the obvious ones:

```
Mapping 75 typo/casing variants for metric_name:
- "Drug Expense" → "Drugs Expense" (singular→plural)
- "EBITDA Margin" → "Operating EBITDA Margin" (abbreviation)
- "OR Minutes" → "Operating Room Minutes" (abbreviation)
- ... [show all 75]

Remaining: 52 genuinely distinct values → creating canonicals
```

---

## Step 5: Cross-Source Mapping (Advanced)

When multiple scrapers have overlapping concepts that need to align:

### The Problem
Kaufman Hall reports `ED Visits per Calendar Day`. Strata Decision Technology
reports `ED Volume (Index)`. Same concept, different names and units.

### The Approach
1. Create a reference mapping table (silver model) that maps source-specific
   names to a shared canonical
2. Document the unit conversion if applicable
3. Use the gold model to join sources using the canonical names

### Don't map at the value layer
Cross-source mapping happens in SQL (gold models), not in `soria value map`.
Each scraper keeps its own clean canonicals. The gold model does the semantic
join.

---

## Step 6: Verify Mappings

After all mappings are done:

1. **Unmapped count check:** Residual unmapped values are legitimate — they
   represent single-year-only concepts with no cross-era equivalent. Forcing
   them into canonicals is wrong. Present the count and explain: "38 unmapped
   = 38 metrics that appear in only one year, no cross-year match."
   Only escalate if a column has unexpectedly high unmapped counts (>20%).
2. **Ordering check:** Mapping must complete before warehouse publish. Value
   mappings are applied at publish time. If you published before mapping was
   complete, re-publish with `--force`:
   ```bash
   soria warehouse publish {group_id} --force
   ```
3. **Sample check:** Query the warehouse with mapped values:
   ```bash
   soria warehouse query "SELECT DISTINCT metric_name FROM bronze.{table} ORDER BY 1"
   ```
4. **Completeness check:** Do the mapped values cover all the time periods
   you need? Any gaps where a canonical has data in 2015-2019 but not 2020+?

---

## ⛔ GATE: MAPPINGS COMPLETE

Present the final mapping summary:
```
| Column | Canonicals | Mapped | Unmapped |
|--------|-----------|--------|----------|
| metric_name | 80 | 127 | 0 |
| segment_type | 3 | 3 | 0 |
| segment_value | 12 | 14 | 0 |
| comparison_period | 9 | 13 | 0 |
```

Plus any decisions that were made about ambiguous mappings. Wait for human
approval before declaring done.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/map-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Value Mapping Report: [Dataset Name]

## Environment
[Active soria env]

## Mapping Summary
[Status table — columns, canonical counts, mapped/unmapped]

## Decisions Made
[Ambiguous mappings that required human judgment, with rationale]

## Cross-Source Notes
[If applicable — what needs to align in gold models]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

---

## Anti-Patterns

1. **Auto-resolving ambiguous mappings.** When "Adjusted Discharges" vs
   "Adjusted Discharges per Calendar Day" appears, don't just pick one.
   Flag it and let the human decide based on the analytical use case.

2. **Mapping across scrapers via `soria value map`.** Cross-source alignment
   happens in SQL gold models, not in the value mapping system. Each
   scraper's values stay independent.

3. **Skipping the survey.** Don't start mapping column 1 without knowing
   how many columns need work. The survey prevents spending an hour on
   metric_name only to discover comparison_period also needs mapping.

4. **Not batching typos.** If there are 75 casing/typo variants, batch them.
   Don't present each one individually.

5. **Mapping numeric or date columns.** Values like "2020-07" or "1234.56"
   don't need canonicals. Only map categorical string columns.

6. **Using the word "promote" for mapping operations.** "Canonical promotion"
   (making a value canonical via `soria value map`) and "workspace promotion
   to prod" (handled by `/promote`) are completely different operations. Say
   "make canonical" or "publish to warehouse" — never "promote" for mapping.

7. **Treating residual unmapped values as errors.** After a complete mapping
   pass, unmapped = "no cross-era equivalent exists." It's correct data.
   Don't try to force mappings that aren't semantically valid.
