---
name: guidance
description: Build a normalized, chunk-cited CSV of a public company's forward-looking financial guidance over a date window. Pulls from ir_<ticker>, sec_edgar_prime, and earnings_transcripts via mcp__soria__chunk_search; cross-checks gaps against the IR scraper. Use for "show X's guidance", "track guidance revisions", "when did they suspend / raise / lower", "build a guidance timeline", "compare initial vs current FY outlook".
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: guidance/SKILL.md
  variant: codex
---

# Guidance

Codex adaptation of the `Soria-Inc/soria-stack` `/guidance` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- one ticker per invocation; default window 8 quarters
- inventory the disclosure surface FIRST via `mcp__soria__database_query`
  against `files` joined to `scrapers` (filter by `s.name = 'ir_<ticker>'`
  and `s.name = 'sec_edgar_prime'`); confirm the candidate event list with
  the user before extraction (Gate 1)
- per event, run THREE `mcp__soria__chunk_search` shapes — segment outlook,
  EPS reconciliation, ratios/capital — never just one
- always set `ticker=<TICKER>` and `scraper_name=<source>`
- do NOT use `date_from`/`date_to` for IR docs (`date_iso` is fiscal year,
  not release date); date filters work only for `sec_edgar_prime`
- normalize to the locked schema:
  `as_of_date,period,metric_category,metric,value_range,value_units,chunk_id`
- categories are locked: `Total | Segment Revenue | Segment Operating Earnings | EPS | EPS Bridge | Ratios | Cash Flow | Capital | Members | Long-Term`
- value encoding: `low - high` | `>= X` | `~X` | `X` | `withdrawn` | `qualitative`
- coverage check (Gate 2): for IC / Q4 / "re-establishes outlook" events,
  confirm segment + EPS + ratios + cash flow + capital + members are all
  attempted; for mid-cycle revisions, EPS-only is by design
- spot-check (Gate 3): re-read the cited chunk for the most recent event's
  Adjusted EPS row before declaring DONE
- output sorted by `as_of_date` then `period` then category order

## Common anti-patterns

- citing a recap chunk instead of the primary event chunk
- one `chunk_search` call per event (will miss segment / ratios / capital tables)
- assuming the Investor Conference deck is in the chunk index — usually only
  the press release preview is. Say so explicitly when the deck is missing.
- inventing metric_categories or metric names; the taxonomy is the contract
- searching without a `ticker` filter — returns cross-issuer noise

## Cross-issuer adaptation

Adapt query 1 segment names per ticker:
- managed care (UNH/HUM/CI/CVS/ELV/MOH): UnitedHealthcare/Optum/Aetna/Cigna Healthcare/Evernorth/Anthem
- hospitals (HCA/THC/UHS/CYH): same-facility admissions, EBITDA, capex
- standard insurers: combined ratio, NWP, BVPS

Schema and gates stay constant across issuers.
