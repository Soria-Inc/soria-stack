---
name: soria-stack
version: 5.0.0
description: |
  Data pipeline skills for Soria Analytics. Cognitive modes for upstream
  pipeline work (scrape → extract → value-map → publish) and for building
  dives (dbt marts + manifest + React component + DivesPage registration +
  rows in the shared verifications seed + methodology wired into the component).
  All skills drive the Soria platform through the `soria` CLI — no MCP.
  Sixteen skills: /env (environment management), /tools (verify CLI + env),
  /status (what exists), /plan (ETVLR orchestrator), /ingest (scrape + extract
  + publish), /map (value mapping), /parent-map (centralized parent company
  resolution), /dive (build a dive end-to-end), /preview (render a dive in
  chat), /verify (prove data correct), /dashboard-review (adversarial browser QA),
  /diagnose (failure triage), /ticket (file structured tickets mid-session),
  /promote (git push → PR → CI), /newsroom (news pipeline ops),
  /lessons (retrospective).
  Suggest the right skill by stage: starting a session → /env then /tools;
  investigating what exists → /status; planning work → /plan; building a
  pipeline → /ingest; normalizing values → /map; resolving parent companies
  → /parent-map; building a dive or reviewing its SQL → /dive; proving data
  correct → /verify; testing live dive UI → /dashboard-review; something broke →
  /diagnose; filing a bug/feature ticket → /ticket; promoting to prod →
  /promote; news pipeline → /newsroom; reviewing recent work → /lessons.
allowed-tools:
  - Read
  - Bash
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SoriaStack v5 loaded"
echo "---"
if command -v soria >/dev/null 2>&1; then
  echo "Active environment:"
  soria env status 2>&1 || echo "  (not authed — run /env)"
else
  echo "⚠️  soria CLI not found — run: uv tool install --from <repo>/cli soria-cli"
fi
echo "---"
echo "Recent artifacts:"
ls -t ~/.soria-stack/artifacts/*.md 2>/dev/null | head -5 || echo "  (none)"
```

**Prod safety:** if `soria env status` reports the active env type is `prod`,
no write-path skill (`/ingest`, `/map`, `/parent-map`, `/dive`, `/newsroom`)
may run without explicit user acknowledgment. `/promote` is the only skill
that expects prod in its flow (and it promotes TO prod from a dev branch,
not FROM prod).

Read `ETHOS.md` before any data pipeline work. All principles apply.

# SoriaStack — Data Pipeline Skills

Sixteen cognitive modes for data pipeline work. Each sets how to think, when
to stop, and what to verify. All skills shell out to the `soria` CLI — never
MCP tools.

## Skill routing

| If the user is... | Suggest |
|-------------------|---------|
| Starting a new session | `/env` then `/tools` |
| Managing dev environments (branch / checkout / diff) | `/env` |
| Asking "what do we have for X?" | `/status` |
| Saying "let's work on X" or "come up with a plan" | `/plan` |
| Ready to scrape, extract, or publish | `/ingest` |
| Normalizing values across eras | `/map` |
| Resolving company names to parent companies | `/parent-map` |
| Building a dive, writing dbt SQL, or reviewing a dive | `/dive` |
| Checking if data is correct, proving it | `/verify` |
| Testing a live dive in a browser | `/dashboard-review` |
| Wanting to see a dive rendered in chat | `/preview` |
| Something broke or isn't working | `/diagnose` |
| Hit a bug, need to file a ticket | `/ticket` |
| Promoting to production (`git push` + PR) | `/promote` |
| Working with the news pipeline | `/newsroom` |
| Reviewing recent work for lessons | `/lessons` |

## The sequence

```
/env (set environment — always first)
   ↓
/tools (verify CLI + active env)
   ↓
/status → /plan → /ingest → /map → /dive → /verify → /promote
                          ↑              ↑
                   /parent-map      (verify rows live in
                   (parallel to /map) the shared seed,
                                     authored inside /dive)
   + /dashboard-review (browser QA — after dive deploys)
   + /preview (render dive output in chat — any time)
   + /diagnose (enters from any phase when something breaks)
   + /ticket (side-quest — file a bug/feature ticket from any phase)
   + /newsroom (separate domain)
   + /lessons (periodic)
```

Each skill produces an artifact the next skill consumes.
Don't skip steps — every pipeline that went poorly started with the AI building
before looking.

## ETVLR Framework

Every data concept follows this lifecycle:

```
E (Extract)    → /ingest Gate 1: scrape files         (soria scraper run)
T (Transform)  → /ingest Gates 2-4: group, schema,    (soria detect/extract/
                 extract, validate                     validate/schema map)
V (Value Map)  → /map: normalize values to canonicals (soria value index/map)
L (Load)       → /ingest Gate 5: publish to warehouse (soria warehouse publish)
R (Represent)  → /dive: dbt marts model + manifest +  (dbt + filesystem +
                 TSX component + DivesPage entry +     soria warehouse query)
                 verify seed rows + methodology
```

`/plan` orchestrates the phases. `/verify` runs after each.

## Environment resolution

All write-path skills (`/ingest`, `/map`, `/parent-map`, `/dive`, `/promote`)
require an active environment. Before any write op, confirm:

1. **User named one** — use it.
2. **Obvious from context** (just created, continuing prior work) — use it.
3. **None set** — suggest `/env` to list and switch.
4. **Pointing at prod** — refuse writes unless the skill is `/promote` or the
   user explicitly acknowledges prod.

Environments are Neon branches plus MotherDuck clones plus git worktrees.
`soria env branch` creates one, `soria env checkout` prints the worktree path
for the shell wrapper to cd into, `soria env diff` shows what's changed vs
prod, `soria env teardown` soft-deletes (7-day grace).

Read-only skills (`/status`, `/verify`, `/plan`, `/newsroom`, `/lessons`,
`/preview`, `/ticket`) don't need an environment for writes but should still
report the active env in output so the user knows which data they're looking at.

## Quick reference

- **Principles** in `ETHOS.md` — the source of truth
- **Artifacts** in `~/.soria-stack/artifacts/` — state passed between skills
- **Gates** in every skill — hard stops where the human must review
- **Completion status** — every skill ends with DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT
- **`soria --help`** — CLI surface reference (install: `uv tool install --from <repo>/cli soria-cli`)
