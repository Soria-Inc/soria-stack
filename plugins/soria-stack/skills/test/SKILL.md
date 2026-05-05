---
name: test
description: Use when testing Soria engineering changes, deciding which proof layer is credible, running E2E checks, or verifying MCP, DBOS, FastAPI, Turbopuffer, warehouse, scraper, extractor, or frontend behavior.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: test/SKILL.md
  variant: codex
---

# Test

Codex adaptation of `Soria-Inc/soria-stack` `/test`.

Read `../../references/codex-adapter.md`, then read the target repo's
`AGENTS.md`, `CLAUDE.md`, and any `docs/engineering/testing.md`.

Testing means choosing evidence, not blindly running pytest. Classify the
change and pick the needed proof layer:

1. Unit proof
2. Local integration proof
3. Boundary proof
4. Runtime proof
5. Pipeline E2E proof
6. Preview/staging/prod proof when configured

Use repo scripts such as `scripts/create-test-db.sh` and
`scripts/run-tests.sh`. For TP/search/chunk runtime proof, use the app repo
helper `scripts/seed-dev-tp.py` before claiming the dev namespace has real
chunks.
