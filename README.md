# SoriaStack

> Cognitive modes for data pipeline work — how Soria Analytics thinks about
> scraping, cleaning, analyzing, verifying, and representing data in SQL.
>
> Modeled after [gstack](https://github.com/garrytan/gstack). Same primitives,
> different domain. gstack is a virtual engineering team. SoriaStack is a virtual
> data engineering team.

## The core idea

SoriaStack gives Claude Code (and Clawd, our always-on agent) a set of opinionated
data pipeline skills. Each skill is a cognitive mode — it sets how to think, when to
stop, and what to verify. The hard part isn't the tooling, it's the judgment.

The key insight: an AI building data pipelines will jump straight to scraping and
extracting. Every pipeline that went poorly started with the AI building before
looking. SoriaStack forces the right sequence: understand → design → build → verify.

## Skills

Skills run in the order a data pipeline runs:

**Understand → Design → Build → Verify → Present**

Each skill feeds into the next. `/scout` writes a recon doc that `/ingest` reads.
`/ingest` produces data that `/model` shapes. `/model` outputs that `/verify` proves correct.

| Skill | Your specialist | What they do |
|-------|----------------|-------------|
| `/scout` | Data Recon Analyst | Understand sources, design analytical architecture, classify effort. Prevents building the wrong thing. |
| `/ingest` | Pipeline Builder | Scrape, organize, extract, map, and publish data through six hard-stop gates. |
| `/model` | SQL Model Designer | Build bronze → silver → gold → platinum models. Forces grain-first thinking. |
| `/verify` | Paranoid Verifier | Three-tier verification: spot checks (evidence), sum checks (proof), derived metrics (gold standard). |
| `/newsroom` | News Pipeline Operator | Branch management, prompt tuning, source review, event clustering. Separate domain, separate tools. |

## Principles

All 25 data principles live in `ETHOS.md`. Every skill references them. They are
the source of truth for how Soria thinks about data.

## Architecture

Skills set the **cognitive frame** — how to think, when to stop, what to verify.
Ref files (in the host project) provide **tool specifics** — API parameters, schemas, MCP tool names.

Skills load once per session. Ref files load on-demand at each gate.

## Installation

### Claude Code (recommended)

```bash
git clone https://github.com/Soria-Inc/soria-stack.git ~/.claude/skills/soria-stack
```

Then add to your project's `CLAUDE.md`:

```markdown
## soria-stack
Data pipeline skills. Read ETHOS.md before any data work.
Available skills: /scout, /ingest, /model, /verify, /newsroom
```

### Per-repo install

```bash
git clone https://github.com/Soria-Inc/soria-stack.git .claude/skills/soria-stack
```

### OpenClaw / Clawd

Skills are referenced from the agent's capability index. The agent reads SKILL.md
files on-demand — same skills, different runtime.

## Dual-host design

SoriaStack works in two contexts:

| Context | How skills are discovered | How tools are accessed |
|---------|--------------------------|----------------------|
| **Claude Code** | Auto-discovered via `.claude/skills/` | Direct tool calls (Bash, Read, etc.) |
| **Clawd (OpenClaw)** | Referenced via AGENTS.md capability index | MCP tools (sumo_*, news_*, etc.) |

Skills are pure markdown — no binaries, no build step. This is intentional.
The same SKILL.md works in both contexts because it describes *how to think*,
not *how to call a specific API*.

## Origin

Extracted from ~50 real Claude Code sessions (Feb–Mar 2026) where Adam worked
through healthcare data pipelines — CMS cost reports, Medicaid enrollment, Star
Ratings, NAIC filings, hospital utilization, insurer 10-K analysis. Every
principle maps to a session where either Adam stated it explicitly or the AI
violated it and wasted time.

## License

MIT
