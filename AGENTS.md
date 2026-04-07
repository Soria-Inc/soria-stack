# SoriaStack — Data Pipeline Skills

SoriaStack is a collection of SKILL.md files that give AI agents structured roles for
data pipeline work. Thirteen skills following the ETVLR framework:
Extract → Transform → Value-map → Load → Represent.

## Available skills

Skills live in their own directories. Invoke them by name (e.g., `/status`).

| Skill | What it does |
|-------|-------------|
| `/tools` | Load Soria MCP tools. Run first in every session. |
| `/status` | Investigate what exists for a concept — 9-stage pipeline inventory. |
| `/plan` | ETVLR orchestrator — break work into phases, plan verification upfront. |
| `/ingest` | Scrape, organize, extract, and publish with five hard-stop gates. |
| `/map` | Value mapping — normalize raw values to canonical forms across eras. |
| `/dashboard` | Design bronze → silver → gold → platinum SQL models. Grain-first. Includes data survey, SQL review checklist, and semantic check building. |
| `/verify` | Prove data is correct. Semantic checks foundation — 6 categories, standard schema, investigation workflow. Pipeline verify, model verify, semantic verify. |
| `/smoke` | Adversarial browser QA — headless browser clicks every dashboard control, checks for breakage. |
| `/diagnose` | Diagnose failures: silent failures, data traces, schema mismatches, infra issues. Creates Linear tickets. |
| `/promote` | Promote workspace to production. REQUIRES human approval. Only path to prod. |
| `/preview` | Render dashboard data as markdown tables in chat. |
| `/newsroom` | News pipeline ops — branch management, prompt tuning, source review. |
| `/lessons` | Review recent work, find patterns, propose principle updates. |

## Principles

Read `ETHOS.md` before any data pipeline work. Includes:
- 28 numbered data principles
- Resolver pattern (context efficiency)
- Completion & escalation protocol
- Anti-sycophancy & simplicity guidance

## Skill chaining (ETVLR)

```
/tools (load MCP — always first)
   ↓
/status → status report (what exists, what's missing)
   ↓
/plan → ETVLR plan (phases, verification criteria, sequencing)
   ↓
/ingest → ingest report (files, schema, extraction results, tables)
   ↓
/map → mapping report (canonical values, decisions made)
   ↓
/dashboard → model spec (grain, SQL models, dashboard config, semantic checks)
   ↓
/verify → scorecard (semantic check results, tier evidence, confidence)
   ↓
/lessons → retro report (patterns, principle updates) [periodic]

   + /smoke (browser QA — after dashboard deploy)
   + /diagnose (enters from any phase when something breaks)
   + /preview (render dashboard data in chat — any time)
```

Artifacts saved to `~/.soria-stack/artifacts/`. Each skill reads prior artifacts
and writes its own. Every artifact includes completion status and lessons learned.
