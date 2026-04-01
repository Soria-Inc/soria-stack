---
name: soria-stack
version: 2.1.0
description: |
  Data pipeline skills for Soria Analytics. Seven cognitive modes for data work:
  /tools (search before calling MCP tools), /status (investigate pipeline state of a concept),
  /scout (understand before building), /ingest (pipeline with gates), /profile (inspect data quality),
  /model (grain-first SQL), /verify (prove it with evidence + SQL review),
  /newsroom (news pipeline ops), /retro (learn from what happened).
  Suggest the right skill by stage: exploring tools or unsure what to call → /tools;
  "where are we with X" or "let's work on X" → /status; understanding a new source → /scout;
  building a pipeline → /ingest; inspecting data quality → /profile;
  designing SQL models → /model; verifying data or reviewing SQL → /verify;
  news pipeline → /newsroom; reviewing recent work → /retro.
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

Read `ETHOS.md` before any data pipeline work. All principles apply.

# SoriaStack — Data Pipeline Skills

Seven cognitive modes for data pipeline work. Each sets how to think, when to stop,
and what to verify.

## Skill routing

| If the user is... | Suggest |
|-------------------|---------|
| Unsure which tool to call | `/tools` |
| Exploring what the MCP can do | `/tools` |
| "Where are we with X?" | `/status` |
| "Let's work on X" | `/status` first, then the right build skill |
| Exploring a new data source | `/scout` |
| Ready to build after scouting | `/ingest` |
| Looking at data before writing SQL | `/profile` |
| Building SQL models on existing data | `/model` |
| Checking if data is correct | `/verify` |
| Reviewing SQL quality | `/verify` (Mode 4) |
| Working with the news pipeline | `/newsroom` |
| Reviewing recent work for lessons | `/retro` |

## The sequence

```
/tools (always available — search before calling)
   ↓
/status (recon — what exists today?)
   ↓
/scout → /ingest → /profile → /model → /verify
                                          ↓
                                       /retro (periodic)
```

Each skill produces an artifact that the next skill consumes.
Don't skip steps — every pipeline that went poorly started with the AI building before looking.

## Quick reference

- **Principles** in `ETHOS.md` — the source of truth (includes resolver pattern, completion protocol, anti-sycophancy)
- **Artifacts** in `~/.soria-stack/artifacts/` — state passed between skills
- **Gates** in every skill — hard stops where the human must review and approve
- **Completion status** — every skill ends with DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT
