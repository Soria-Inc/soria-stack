# SoriaStack — Data Pipeline Skills

SoriaStack is a collection of SKILL.md files that give AI agents structured
roles for data pipeline work at Soria Analytics. Fifteen skills covering the
full ETVLR cycle: Extract → Transform → Value-map → Load → Represent.

All skills drive the Soria platform through the **`soria` CLI** — no MCP.

## Architecture

```
                        soria-dev or preview env
                        (git worktree + Neon branch + MotherDuck clone)
                                    │
   soria scraper run → soria detect → soria extract → soria validate
                                    │
                        soria schema mappings / soria value map
                                    │
                            soria warehouse publish
                                    │
                        soria_duckdb (upstream bronze / silver / gold)
                                    │
                                    ▼
                          soria_dives dbt project
                    (staging → intermediate → marts)
                                    │
                        soria_duckdb_main.main_marts.*
                                    │
                                    ▼
                         React dive components
                    (useDiveData manifest pattern,
                     DuckDB-WASM + Postgres wire proxy,
                     MethodologyModal + VerifyModal)
                                    │
                                    ▼
                    soria env diff → git push → gh pr create
                                    │
                                    ▼
                    CI: dbt run --target prod + frontend deploy
                                    │
                    soria revert (safety net for bad promotes)
```

Classic backend-rendered dashboards (AG-Grid + `@dashboard` YAML) are gone.
The backend is a thin FastAPI shell: auth, scraper management, news, file
processing. Dashboard data flows directly from MotherDuck to the browser.

## Available skills

Skills live in their own directories. Invoke them by name (e.g., `/status`).

| Skill | What it does |
|-------|-------------|
| `/env` | Manage dev environments — `soria env list/branch/checkout/status/diff/teardown/restore`. Run first in every session. |
| `/tools` | Verify `soria` CLI installed, report active environment, warn on prod. |
| `/status` | Investigate what exists for a concept — pipeline inventory via `soria env status` + `soria list` + dive filesystem walk. |
| `/plan` | ETVLR orchestrator — break work into phases, plan verification upfront. |
| `/ingest` | Scrape, organize, extract, validate, and publish through five hard-stop gates. |
| `/map` | Value mapping — normalize raw values to canonical forms across eras. |
| `/parent-map` | Resolve company names/codes to ultimate parent companies via parallel.ai. One centralized table, all data sources. |
| `/dive` | Build a dive end-to-end: dbt marts SQL + manifest + TSX component + `DivesPage.tsx` registration + rows in the shared `verifications.csv` seed + methodology content wired into the component. Grain-first thinking, domain grounding, SQL review checklist. |
| `/preview` | Render a dive as markdown tables in chat — read the manifest, build SQL, query MotherDuck, format as a pivot. |
| `/verify` | Prove data is correct. Semantic checks foundation — Pipeline verify, Model verify, Semantic verify. Three tiers per mode. |
| `/smoke` | Adversarial browser QA — headless browser clicks every dive control, tests MethodologyModal + VerifyModal, handles Clerk login. |
| `/diagnose` | Triage-first failure investigation: silent failures, data traces, schema mismatches, infrastructure, quality. Invokes `/ticket` when ticketing is needed. |
| `/ticket` | File a structured Linear ticket mid-session. Owns all Linear writes. Scans for duplicates and active interactive-agent runs before filing. Side-quest — returns the user to their previous skill. |
| `/promote` | Safe path to production. Pre-flight → `soria env diff` → `git push` → `gh pr create` → CI promotes on merge. Documents `soria revert` rollback. |
| `/newsroom` | News pipeline ops — branch management, prompt tuning, source review. |
| `/lessons` | Retrospective — review recent work, find patterns, propose principle updates. |

## Principles

Read `ETHOS.md` before any data pipeline work. Includes:

- Numbered data principles extracted from real sessions
- Resolver pattern (context efficiency)
- Completion & escalation protocol
- Anti-sycophancy & simplicity guidance
- CLI-first tool invocation
- Diff-based promotion semantics
- Dual-mode loading invariant for dives
- Methodology-per-element as "done"

## Installation

### 1. Install the `soria` CLI

This skill pack assumes the [`soria` CLI](https://github.com/Soria-Inc/soria-2/tree/main/cli)
is installed. From the soria-2 repo root:

```bash
uv tool install --from ./cli soria-cli
soria auth setup
soria shell-setup >> ~/.zshrc   # or ~/.bashrc
source ~/.zshrc
```

Verify with `soria --help` and `soria env list`.

### 2. Install the skill pack

Clone this repo into Claude Code's skills directory, then run the installer
to symlink every skill into the parent dir so Claude Code discovers them:

```bash
git clone https://github.com/Soria-Inc/soria-stack ~/.claude/skills/soria-stack
cd ~/.claude/skills/soria-stack
./install.sh
```

The installer creates symlinks like `~/.claude/skills/ingest -> soria-stack/ingest`
for every skill in the pack. It's idempotent — rerun it any time after
`git pull` to pick up new skills, remove stale symlinks pointing at deleted
skills, or repoint symlinks whose targets have moved.

After running, verify in a fresh Claude Code session:

```
/env      # list dev environments
/tools    # verify CLI + active env
/status   # pipeline recon
```

### 3. Keeping the pack up to date

```bash
cd ~/.claude/skills/soria-stack
git pull
./install.sh   # propagate any new/removed skills
```

Most updates (to existing skills) propagate automatically because the
top-level symlinks point into the pack — a `git pull` rewrites the content
the symlinks resolve to. Re-running `install.sh` is only strictly necessary
when skills are added or removed, but running it every time is cheap and
safe.

## Skill chaining (ETVLR)

```
/env (set active environment — always first)
   ↓
/tools (verify CLI + active env)
   ↓
/status → status report (what exists, what's missing)
   ↓
/plan → ETVLR plan (phases, verification criteria, sequencing)
   ↓
/ingest → ingest report (files, schema, extraction results, bronze tables)
   ↓
/map → mapping report (canonical values, decisions made)
   ↓
/dive → dive spec (grain, dbt model, manifest, TSX, modals, semantic checks)
   ↓
/verify → scorecard (semantic check results, tier evidence, confidence)
   ↓
/promote → promotion report (PR URL, CI status, canary results)
   ↓
/lessons → retro report (patterns, principle updates) [periodic]

   + /smoke (browser QA — after dive lands in dev env)
   + /preview (render a dive in chat — any time)
   + /diagnose (enters from any phase when something breaks)
```

Artifacts saved to `~/.soria-stack/artifacts/`. Each skill reads prior
artifacts and writes its own. Every artifact includes completion status and
lessons learned.
