---
name: soria-stack
version: 2.0.0
description: |
  Data pipeline skills for Soria Analytics. Five cognitive modes for data work:
  /scout (understand before building), /ingest (pipeline with gates), /model
  (grain-first SQL), /verify (prove it with evidence), /newsroom (news pipeline ops).
  Suggest the right skill by stage: understanding a source /scout; building a pipeline
  /ingest; designing SQL models /model; verifying data /verify; news pipeline /newsroom.
allowed-tools:
  - Read
  - Bash
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SoriaStack loaded"
echo "---"
echo "Recent artifacts:"
ls -t ~/.soria-stack/artifacts/*.md 2>/dev/null | head -5 || echo "  (none)"
```

Read `ETHOS.md` before any data pipeline work. All 27 principles apply.

# SoriaStack — Data Pipeline Skills

Five cognitive modes for data pipeline work. Each sets how to think, when to stop,
and what to verify.

## Skill routing

| If the user is... | Suggest |
|-------------------|---------|
| Exploring a new data source | `/scout` |
| Ready to build after scouting | `/ingest` |
| Building SQL models on existing data | `/model` |
| Checking if data is correct | `/verify` |
| Working with the news pipeline | `/newsroom` |

## The sequence

```
/scout → /ingest → /model → /verify
```

Each skill produces an artifact that the next skill consumes.
Don't skip steps — every pipeline that went poorly started with the AI building before looking.

## Quick reference

- **27 principles** in `ETHOS.md` — the source of truth
- **Artifacts** in `~/.soria-stack/artifacts/` — state passed between skills
- **Gates** in every skill — hard stops where the human must review and approve
