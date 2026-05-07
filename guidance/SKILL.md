---
name: guidance
version: 1.0.0
description: |
  Build a normalized, chunk-cited timeline of a public company's
  forward-looking financial guidance over a date window. Pulls from
  `ir_<ticker>`, `sec_edgar_prime`, and `earnings_transcripts` via
  `mcp__soria__chunk_search`; cross-checks gaps against the IR scraper
  file list in Postgres. Outputs an event × metric × period CSV with
  `as_of_date, period, metric_category, metric, value_range, value_units,
  chunk_id` and renders a markdown table on request.
  Use when asked to "show X's guidance", "track guidance revisions",
  "when did they suspend / raise / lower guidance", "build a guidance
  timeline", or "compare initial vs current FY outlook". Proactively
  invoke when the user names a public company ticker and asks about
  forward-looking financials over multiple quarters. (soria-stack)
benefits-from: [diagnose, status]
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
  - Agent
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: guidance"
echo "---"
echo "Recent guidance artifacts:"
ls -t ~/.soria-stack/artifacts/guidance-*.md 2>/dev/null | head -5 || echo "  (none)"
echo "---"
echo "Default output dir: ~/Downloads (override with explicit path)"
```

**Load deferred MCP tools.** This skill relies on three deferred tools.
If they haven't been loaded yet in this session, load via ToolSearch:

```
ToolSearch: "select:mcp__soria__chunk_search,mcp__soria__database_query,mcp__soria__file_query"
```

Read `ETHOS.md` (especially #17 spot checks, #18 sum checks, #24 inventory before action).

## Skill routing (always active)

If the user's intent shifts away from extracting guidance, invoke the matching skill:

- User wants to dive into one company's data quality → invoke `/diagnose`
- User wants to build a dashboard from this data → invoke `/dive`
- User wants to verify a dive against guidance figures → invoke `/verify`
- User wants prior context on this company / ticker → invoke `/status` or just search mempalace

---

# /guidance — "What did they actually guide to?"

You are an equity research assistant building a faithful, source-cited record
of a company's forward-looking guidance. Your job is to extract published ranges
**verbatim** with chunk-level provenance, never paraphrase, never synthesize a
number that the company didn't publish.

The output is structured for downstream analysis: one row per
(event × metric × period), with the `chunk_id` that supports each value.
Anyone reading the CSV can pull up the source paragraph.

## Output schema (locked)

```
as_of_date,period,metric_category,metric,value_range,value_units,chunk_id
```

| field | rules |
|---|---|
| `as_of_date` | YYYY-MM-DD of the disclosure event (press release date, IC date, 8-K filing date, conference call date) |
| `period` | `FY2024` / `FY2025` / `FY2026` for annual outlook. `Long-Term` for multi-year growth targets. (US issuers rarely guide quarterly — if they do, use `1Q25`, `2H25`, etc.) |
| `metric_category` | One of: `Total`, `Segment Revenue`, `Segment Operating Earnings`, `EPS`, `EPS Bridge`, `Ratios`, `Cash Flow`, `Capital`, `Members`, `Long-Term`. Do not invent new categories. |
| `metric` | Human-readable. Examples: `Total Revenue`, `UnitedHealthcare Revenue`, `Optum Health Operating Earnings`, `Net EPS (GAAP)`, `Adjusted EPS`, `Medical Care Ratio`, `Cash Flow from Operations`, `Capital Expenditures`, `Intangible Amortization per Share`, `Long-Term EPS Growth Target`. |
| `value_range` | `low - high` for ranges, `>= X` for "at least X" / "greater than X", `~X` for approximate, `X` single point, `withdrawn` for suspended, `qualitative` for categorical drivers (e.g. "MA utilization acceleration") |
| `value_units` | `$ billions`, `$ per share`, `%`, `millions` (members), `text` (for `withdrawn` / `qualitative`) |
| `chunk_id` | UUID from `chunk_search` that supports this value. **Required.** No row ships without one. |

## Phases

### Phase 1: Scope

If the user didn't specify, ask:

- **Ticker** (single ticker per skill invocation)
- **Window** — default 8 quarters (24 months) ending today
- **Output path** — default `~/Downloads/<ticker>_guidance_<window>.csv`

### Phase 2: Inventory the disclosure surface

Before any chunk_search, query the IR scraper to see what's actually been
ingested:

```sql
SELECT DISTINCT
  f.file_name,
  f.date_iso,
  f.file_metadata->>'original_url' AS url
FROM files f
JOIN groups g  ON f.group_id  = g.id
JOIN scrapers s ON g.scraper_id = s.id
WHERE s.name = 'ir_<TICKER_LOWER>'
  AND f.deleted_at IS NULL
  AND f.file_type = 'pdf'
  AND f.file_metadata->>'original_url' LIKE '%/<YEAR>/%'   -- repeat per year in window
ORDER BY f.file_name
```

Also pull SEC 8-Ks in window from `sec_edgar_prime`:

```sql
SELECT f.file_name, f.date_iso, f.file_metadata->>'original_url' AS url
FROM files f
JOIN groups g ON f.group_id = g.id
JOIN scrapers s ON g.scraper_id = s.id
WHERE s.name = 'sec_edgar_prime'
  AND f.file_metadata->>'ticker' = '<TICKER>'
  AND f.file_metadata->>'form' = '8-K'
  AND f.date_iso BETWEEN '<from>' AND '<to>'
ORDER BY f.date_iso
```

From these results, build the **candidate event list**. Common event types:

- **Q earnings release** (4× / year) — usually `<ticker>-q<N>-<year>-release.pdf` or similar
- **Q4 release** — typically also issues next-FY outlook
- **Investor Conference outlook release** (1× / year, often early December) — issues initial next-FY ranges
- **Mid-quarter pre-announcement / supplemental non-GAAP recon** (rare)
- **Suspension / withdrawal calls** (rare — e.g. UNH 2025-05-13)
- **Prepared remarks PDFs** — companion to earnings releases; may have segment color the release lacks

### ⛔ GATE 1: Confirm event list

Present the candidate event list as a table with `as_of_date | event_type | filename | url`.
Ask the user to confirm or add events you might have missed (e.g. an analyst
day deck that wasn't scraped, a supplemental investor day file). Do NOT
proceed to extraction until confirmed.

### Phase 3: Per-event extraction

For each confirmed event, run **three chunk_search shapes** (don't skip any
— each surfaces different table types):

1. **Segment outlook query**:
   `outlook UnitedHealthcare Optum revenues operating earnings segment` (adapt segment names per ticker)
2. **EPS reconciliation query**:
   `adjusted net earnings per share reconciliation intangible amortization`
3. **Ratios / capital query**:
   `medical care ratio operating cost ratio tax rate cash flow capital expenditures share repurchase dividend`

Apply these filters to every call:
- `ticker=<TICKER>` (mandatory)
- `scraper_name="ir_<TICKER_LOWER>"` for IR docs OR `"sec_edgar_prime"` for 8-Ks OR `"earnings_transcripts"` for call transcripts (one source per call — don't mix)
- **Do NOT use `date_from`/`date_to` for IR docs.** The `ir_<ticker>` scraper sets `date_iso` to fiscal year (e.g. `2025-01-01`), not the release date. Date filters work correctly only for `sec_edgar_prime`.
- `limit=15-25` per call

Set `max_per_file` higher (e.g. 5) when you need multiple chunks from the
same press release (the outlook page is often split across 2-3 chunks).

If a chunk_search response exceeds context (>50KB), the result will be
persisted to a file. Use `jq -r '.result' <file> | grep -E "^File:|^Chunk:"`
to enumerate the chunks before deciding which to extract.

### Phase 3: Per-event extraction — source preference order

When the same guidance event has multiple chunked sources, prefer in this order:
1. **8-K Exhibit 99.1** from `sec_edgar_prime` — the authoritative SEC-filed press release with exact tables. `as_of_date` = the 8-K filing date.
2. **IR press release PDF** from `ir_<ticker>` — same content, but `date_iso` is fiscal-year-stamped (skill anti-pattern #1). Use the press release's own header date (e.g. "(October 29, 2025)") for `as_of_date`, NOT `date_iso`.
3. **Prepared remarks PDF** — for color and EPS bridge components. Use only when (1) and (2) don't have the metric.
4. **Earnings call transcript** (`earnings_transcripts`) — last resort. Transcripts have rounding artifacts and verbal imprecision. Numbers stated verbally that contradict the press release table are wrong.

If a guidance event was first announced in a mid-quarter pre-announcement 8-K (e.g. MOH 2025-07-07 EPS cut announced before the 2025-07-23 Q2 release), `as_of_date` = the pre-announcement date, not the later transcript date.

### Phase 4: Normalize into the locked schema

Map every extracted value to one row. Hold the line on the locked taxonomy:

- A revenue range for a segment goes to `Segment Revenue`, not `Total`
- An "operating margin" guide goes to `Ratios` (single number with `%` units)
- A "capex" guide goes to `Capital`, with `$ billions`
- A "long-term 13-16% growth" goes to `Long-Term` / `Long-Term EPS Growth Target`
- A suspension goes as 4 rows minimum: Total Revenue, Net EPS, Adjusted EPS, OCF — all `withdrawn` / `text`
- Categorical drivers (e.g. "MA utilization acceleration as the cause of the cut") go as `Ratios` rows with `qualitative` / `text`, citing the chunk where management named the driver

### Profitability metric category rule

Adjusted EBITDA, Adjusted Gross Profit, Adjusted Net Income, GAAP Net Income, and any other consolidated profitability metric that is NOT denominated per share goes in `metric_category=Total`, NEVER in `EPS`. The `EPS` category is reserved for actual per-share metrics (Net EPS GAAP, Adjusted EPS, etc.). For EBITDA-anchored insurtechs (ALHC, OSCR, CLOV, etc.) you may have zero rows in the `EPS` category — that is correct.

When the skill body mentions "treat EBITDA as the Adj EPS analog," that applies ONLY to Gate 3 spot-check selection (which row to verify), NOT to the category column.

### Phase 4 vocab gate (programmatic)

After normalizing into rows, before Gate 2, walk every row and assert:
- `metric_category` ∈ the locked 10. If a value falls outside, do NOT invent a new category — use `Total` for non-EPS profitability (EBITDA, gross profit, net income), `Ratios` for ratios you can't otherwise place, etc.
- `value_units` ∈ {`$ billions`, `$ per share`, `%`, `millions`, `text`}. NEVER use `$M`, `$B`, `USD_billions`, `percent`, `count`, `count_millions`, `note`, `members`, `days`, `clinics`, `states`, or any other freeform unit. If a metric naturally needs an out-of-vocab unit (e.g. Days Claims Payable in days), use `text` for `value_units` and put the magnitude with the unit word in `value_range` (e.g. `~44 days`).
- `value_range` is in canonical encoding (`low - high` / `>= X` / `~X` / single / `withdrawn` / `qualitative`). No prose contamination. No `(at low-end)` qualifiers. No arrows. No parenthetical negatives — use `-X` not `(X)`.
- `period` ∈ {`FY2024`, `FY2025`, ..., `Long-Term`, or quarterly forms `1Q25`/`2H25`}. Monthly snapshots (e.g. `Jan-2025`) are not guidance periods — drop those rows.

Any row that fails the gate must be either fixed or dropped before Phase 5.

### ⛔ GATE 2: Coverage check

For "high-detail" events — annual Investor Conference, Q4 / FY release, any
"re-establishes outlook" / "issues outlook" / "raises outlook" headline —
confirm you've attempted all six high-value categories:

- Segment Revenue (per segment)
- Segment Operating Earnings (per segment)
- EPS (GAAP + Adjusted)
- Ratios (MCR, OpEx ratio, tax rate, op margin, days claims payable)
- Cash Flow + Capital (OCF, capex, repurchases, dividends)
- Members (consumers served, VBC patients, scripts where relevant)

For "EPS-only revision" events (mid-cycle Q1 / Q3 raises or revisions),
expect only EPS + sometimes total revenue. That's not a gap, that's the
disclosure cadence. Note this in the artifact.

### ⛔ GATE 3: Spot-check (ETHOS #17)

Pick 2 high-stakes rows — usually the most recent event's Adjusted EPS plus
one segment-level row from the most decomposed event. Re-read the cited
chunk text and confirm the value matches the row exactly. If it doesn't:

- Fix the row
- Search again for the correct chunk
- Or downgrade the artifact status to `DONE_WITH_CONCERNS` and surface the
  discrepancy in the report

### Phase 5: Persist

Sort the CSV by `as_of_date` then `period` then category order:
`Total → Segment Revenue → Segment Operating Earnings → EPS → EPS Bridge → Ratios → Cash Flow → Capital → Members → Long-Term`.

Write to the user's output path. Render a markdown table on request,
truncating `chunk_id` to 8 chars for readability with full UUIDs in the CSV.

### Phase 6: Report

Final report shape:

```
GUIDANCE TIMELINE: <TICKER> · <window>
═══════════════════════════════════════════════
Output: <path>
Rows: N (across M events)
Distinct chunk_ids: K

Coverage:
  Annual outlook events (full segment): list
  EPS-only revision events: list
  Suspension/withdrawal events: list

Discrepancies / concerns:
  <flagged spot-check failures, missing IC decks, etc.>

Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT
```

## Anti-patterns (codified from the UNH 2026-05-06 retro)

1. **Don't trust `date_iso` on `ir_<ticker>` files.** It's the fiscal year
   stamp (e.g. `2025-01-01`), not the press release date. Filter by
   `original_url` path (`/2024/`, `/ic24/`, `/2025/`) or by `original_filename`.
   Date filters only work correctly for `sec_edgar_prime`.

2. **Don't cite a recap chunk.** If event A is described in a release for
   event B (e.g. a Q2 release that mentions a prior-quarter suspension),
   find event A's primary chunk before quoting it. The chunk_id must point
   to the document of the event itself.

3. **Don't claim "no segment-level disclosure" without checking three places**
   for the event:
   (a) the press release PDF,
   (b) the 8-K Exhibit 99.1 from `sec_edgar_prime`,
   (c) the prepared remarks PDF if one exists for that event.

4. **Don't extract from one chunk_search call.** Each release has 3-5
   distinct table types (segment outlook, EPS bridge, ratios, members,
   capital). Run the three query shapes per event; merge results.

5. **Don't ship without spot-checking** the most-recent event's Adjusted EPS
   row. The cost of a wrong number propagating into downstream analysis is
   higher than the cost of one extra `chunk_search` call.

6. **Don't conflate the Investor Conference press release preview with the
   IC deck itself.** The deck (with full segment outlook + multi-year
   targets + business-unit deep-dives) is often NOT in the chunk index even
   when the preview release is. If the deck is missing, say so explicitly
   in the artifact — don't synthesize segment detail from the press release
   bullet points.

7. **Don't search without a `ticker` filter.** UNH-shaped queries against
   the entire catalog return MA / Optum / CVS noise. Always set
   `ticker="<TICKER>"`.

8. **Don't invent metric_categories or metric names per session.** The locked
   taxonomy is the contract. If you encounter something that genuinely
   doesn't fit, surface it as `DONE_WITH_CONCERNS` and ask whether to extend
   the taxonomy in `/lessons`, not silently in this artifact.

## Cross-issuer notes

Different companies publish guidance differently. Adapt query terms but keep
the schema constant:

- **Managed care (UNH, HUM, CI, ELV, CVS, MOH)**: segment rev/op earn,
  Medical Care Ratio (MCR), members, intangible amort EPS bridge
- **Hospitals (HCA, THC, UHS, CYH)**: same-facility admissions, EBITDA,
  capex
- **Insurers more broadly**: combined ratio, NWP, BVPS

Add the issuer's specific segment names to the query 1 ("UnitedHealthcare
Optum" → "Aetna" for CVS, "Cigna Healthcare Evernorth" for CI, etc.).

## Artifact output

```bash
cat > ~/.soria-stack/artifacts/guidance-<ticker>-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Guidance Timeline: <TICKER> · <window>

## Output
<path to CSV>

## Events covered
<count, types, headlines>

## Coverage gaps
<events where outlook was EPS-only by design vs missing from index>

## Spot-check results
<rows checked, pass/fail>

## Discrepancies surfaced
<anything flagged for follow-up>

## Status
DONE | DONE_WITH_CONCERNS
ARTIFACT
```

## Completion

End with status per ETHOS:

- **DONE** — All confirmed events extracted, GATE 2 coverage met or
  documented as "by design", GATE 3 spot-checks passed, CSV sorted and
  written.
- **DONE_WITH_CONCERNS** — Shipped, but with discrepancies (failed
  spot-check, missing chunk for an event the user expected to be covered,
  taxonomy edge case).
- **BLOCKED** — Cannot proceed (e.g. ticker has no `ir_<ticker>` scraper
  and no `sec_edgar_prime` coverage, user needs to ingest first).
- **NEEDS_CONTEXT** — Missing the ticker, window, or whether to include a
  specific event type.
