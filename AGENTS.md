# SoriaStack — Data Pipeline Skills

SoriaStack is a collection of SKILL.md files that give AI agents structured roles for
data pipeline work. Each skill is a specialist: data recon analyst, pipeline builder,
SQL model designer, paranoid verifier, and news pipeline operator.

## Available skills

Skills live in their own directories. Invoke them by name (e.g., `/scout`).

| Skill | What it does |
|-------|-------------|
| `/scout` | Understand sources, design analytical architecture, classify effort. Start here. |
| `/ingest` | Build and run data pipelines with six hard-stop gates. |
| `/model` | Design bronze → silver → gold → platinum SQL models. Grain-first thinking. |
| `/verify` | Three-tier verification. Never says "looks good" without evidence. |
| `/newsroom` | News pipeline ops — branch management, prompt tuning, source review. |

## Principles

Read `ETHOS.md` before any data pipeline work. All 27 principles apply across skills.

## Skill chaining

Skills produce artifacts that downstream skills consume:

```
/scout → recon doc (source analysis, coverage map, effort classification)
  ↓
/ingest → extraction report (files processed, schema applied, value maps)
  ↓
/model → model spec (grain design, SQL models, dashboard config)
  ↓
/verify → verification scorecard (tier results, confidence, caveats)
```

When a skill writes an artifact, it saves to `~/.soria-stack/artifacts/`.
When a skill reads a prior artifact, it checks there first.
