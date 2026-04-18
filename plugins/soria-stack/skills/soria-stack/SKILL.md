---
name: soria-stack
description: Use when the task follows the Soria CLI workflow from the `Soria-Inc/soria-stack` repo: environment setup, status/inventory, planning, ingest/publish work, dive implementation, verification, diagnosis, or promotion. Prefer the `soria` CLI and this repo's `AGENTS.md` over ad-hoc commands. Pair with the `browse` skill for fast browser QA and UI debugging.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  variant: codex
---

# Soria Stack

Codex adaptation of the `Soria-Inc/soria-stack` workflow. This skill is the
CLI-first operating model for Soria work in Codex.

## When to use this skill

- User wants to work through a Soria environment with `soria env ...`
- User asks what data or pipeline state exists for a scraper or domain
- User wants a plan before changing ingestion, mappings, or dives
- User is building or fixing a dive, verify flow, or promotion flow
- User wants the Soria-stack workflow specifically, but inside Codex

## When not to use it

- If the user explicitly wants Sumo or Soria MCP tooling, use `sumo-mcp`
- If the task is generic repo coding with no Soria workflow implications
- If the task is pure browser QA, jump straight to `browse`

## Session start

Run these before making assumptions:

```bash
soria env status
git status --short
```

If local app work is involved, use the repo-standard loop:

```bash
make run-dev
make logs
make stop-dev
```

If `bd` is missing in the shell, proceed without it and note that the issue
tracker CLI is unavailable in this environment.

## Core workflow

1. Inventory before action.
   Use `soria env status`, `soria list`, `soria group list`, `soria db query`,
   and `soria warehouse query` to understand what already exists.
2. Plan before building when the scope is not obvious.
   Be explicit about the target output: pipeline change, table, dive, verify
   pass, or promotion.
3. Use the CLI, not ad-hoc workarounds.
   The main surfaces are:
   - `soria env ...`
   - `soria scraper ...`
   - `soria detect`, `soria extract`, `soria validate`
   - `soria schema ...`, `soria value ...`
   - `soria warehouse ...`
4. Verify with evidence.
   Show actual rows, counts, traces, or file state before claiming success.
5. Run `soria env diff` before promotion or merge-related handoff.

## Dive work

For dive implementation, stick to the repo's file-based flow:

- dbt models under `frontend/src/dives/dbt/models/...`
- manifests under `frontend/src/dives/manifests/...`
- React components under `frontend/src/dives/...`
- registration in `frontend/src/pages/DivesPage.tsx`
- verify rows in `frontend/src/dives/dbt/seeds/verifications.csv`

When the user wants UI proof, invoke `browse` instead of defaulting to the
slower Chrome-first browser tools.

## Guardrails

- Do not write against prod without explicit user acknowledgment.
- Run `soria env diff` before any landing or promotion recommendation.
- Respect this repo's `AGENTS.md` completion rules if you end up committing:
  tests or validation, `git pull --rebase`, `bd sync` if available, `git push`.
- Treat `direnv` and repo-local `.env` loading as the source of truth; do not
  tell the user to `source .env`.

## Routing hints

- Environment management: `soria env list|status|checkout|branch|diff`
- Inventory and recon: `soria list`, `soria group list`, `soria db query`
- Ingestion path: scraper -> detect/extract/validate -> mappings -> publish
- Dive path: dbt + manifest + TSX + verifications + browser QA
- Diagnosis: inspect actual schema or state first, then trace the failure

If a live page, screenshot, auth import, or UI repro is involved, switch to
`browse`.
