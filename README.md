# SoriaStack

> Soria Analytics' version of [gstack](https://github.com/garrytan/gstack).
> Cognitive modes for data pipeline work — not generic data engineering, but exactly how Adam thinks about scraping, cleaning, analyzing, verifying, and representing data in SQL.

## Skills

| Skill | Cognitive Mode | When to Use |
|-------|---------------|-------------|
| `/scout` | Data recon + analytical architect | Before touching any tools — understand sources, design the data architecture, classify effort |
| `/ingest` | Pipeline builder with gates | Building or re-running a data pipeline (scrape → extract → publish) |
| `/model` | SQL model designer | Building bronze/silver/gold/platinum SQL models |
| `/verify` | Paranoid data verifier | After extraction, after modeling, or on-demand — prove the data is correct |
| `/newsroom` | News pipeline operator | News branch management, prompt tuning, source/event review |

## Principles

All 25 data principles live in `principles.md`. Every skill references them. They are the source of truth for how Soria thinks about data.

## Architecture

Skills set the **cognitive frame** — how to think, when to stop, what to verify.
Ref files provide **tool specifics** — API parameters, schemas, MCP tool names.

Skills load once per session (~200-400 lines). Ref files load on-demand at each gate.

## Usage

### Claude Code
Clone to `~/.claude/skills/soria-stack/` — each skill is auto-discovered by Claude Code.

### OpenClaw / Clawd
Skills are referenced from `ref/skills/` or `memory/knowledge/engineering/soria-stack/`.
AGENTS.md points to principles and skills for pipeline work.

## Origin

Extracted from ~50 real Claude Code sessions (Feb-Mar 2026) where Adam worked through healthcare data pipelines — CMS cost reports, Medicaid enrollment, Star Ratings, NAIC filings, hospital utilization, insurer 10-K analysis. Every principle maps to a session where either Adam stated it explicitly or the AI violated it and wasted time.

See `soria-stack-skills-prd.md` for the full design conversation.

## Changelog

- **2026-03-26:** Initial version — 5 skills, 25 principles. Extracted from session analysis covering gstack comparison, planning depth, verification tiers, dashboard correctness patterns.
- **2026-03-14:** PRD written capturing initial design conversation.
