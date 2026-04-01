# SoriaStack — Data Pipeline Skills

SoriaStack is a collection of SKILL.md files that give AI agents structured roles for
data pipeline work. Each skill is a specialist: data recon analyst, pipeline builder,
data quality inspector, SQL model designer, paranoid verifier, news pipeline operator,
and retrospective analyst.

## Available skills

Skills live in their own directories. Invoke them by name (e.g., `/scout`).

| Skill | What it does |
|-------|-------------|
| `/tools` | Load MCP tools via ToolSearch. Required before any Soria MCP call. |
| `/status` | Investigate pipeline state of a concept. Scraper → files → groups → schema → warehouse → models → dashboards. |
| `/scout` | Understand sources, design analytical architecture, classify effort. Start here. |
| `/ingest` | Build and run data pipelines with six hard-stop gates. |
| `/profile` | Inspect raw data quality before writing SQL models. 4 parallel checks. |
| `/model` | Design bronze → silver → gold → platinum SQL models. Grain-first thinking. |
| `/verify` | Four modes: pipeline verify, model verify, analytical verify, SQL review. |
| `/newsroom` | News pipeline ops — branch management, prompt tuning, source review. |
| `/retro` | Review recent work, find patterns, propose principle updates. |

## Principles

Read `ETHOS.md` before any data pipeline work. Includes:
- Data principles (27 numbered principles)
- Resolver pattern (context efficiency)
- Completion & escalation protocol
- Anti-sycophancy & simplicity guidance

## Skill chaining

`/tools` is the foundational pattern — search before you call. `/status` is the
starting point when picking up existing work — recon before building.

Skills produce artifacts that downstream skills consume:

```
/status → status report (pipeline map with ✅/⚠️/❌ per stage, recommended next skill)
  ↓
/scout → recon doc (source analysis, coverage map, effort classification)
  ↓
/ingest → extraction report (files processed, schema applied, value maps)
  ↓
/profile → data quality report (issues, distributions, recommended transforms)
  ↓
/model → model spec (grain design, SQL models, dashboard config)
  ↓
/verify → verification scorecard (tier results, confidence, caveats)
  ↓
/retro → retro report (patterns, proposed principle updates) [periodic]
```

When a skill writes an artifact, it saves to `~/.soria-stack/artifacts/`.
When a skill reads a prior artifact, it checks there first.

Every artifact includes a completion status and lessons learned section.
