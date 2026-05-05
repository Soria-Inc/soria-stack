---
name: test
version: 1.0.0
description: Use when testing Soria engineering changes, deciding which proof layer is credible, running E2E checks, or verifying MCP, DBOS, FastAPI, Turbopuffer, warehouse, scraper, extractor, or frontend behavior.
allowed-tools:
  - Read
  - Bash
---

# /test

Testing means choosing credible evidence for the change. It does not mean
blindly running pytest.

Read the target repo's `AGENTS.md`, `CLAUDE.md`, and any
`docs/engineering/testing.md` first. Repo-local scripts and rules win.

## Proof Layers

Use the weakest layer that still exercises the risky boundary.

| Layer | Name | Proves | Does Not Prove |
|---|---|---|---|
| 1 | Unit proof | Pure logic and helpers | Integration, wrappers, transport |
| 2 | Local integration proof | Real test DB, fixtures, transactions | MCP/HTTP/runtime wiring |
| 3 | Boundary proof | MCP wrapper, FastAPI route, DBOS call shape | Live transport or deployed env |
| 4 | Runtime proof | Running local backend/frontend, real FastMCP/HTTP/DBOS init | Full external pipeline |
| 5 | Pipeline E2E proof | Multi-system chain such as scrape/extract/chunk/publish/search | Production parity |
| 6 | Preview/staging/prod proof | Deployed target behavior | Available only when configured |

If a change touches an external surface, Layer 1 alone is not enough.

## Decision Tree

```text
Pure helper or formatter?
  -> Layer 1

Database write, transaction, soft delete, ORM model, migration?
  -> Layer 2

@mcp.tool wrapper?
  -> Layer 1 for callee
  -> Layer 3 MCP boundary
  -> Layer 4 runtime MCP when registration/transport matters

FastAPI route?
  -> Layer 1 for callee
  -> Layer 3 TestClient/API boundary
  -> Layer 4 curl/runtime when deployment shape matters

DBOS workflow, queue, enqueue options, workflow ID, worker recovery?
  -> Layer 2 local DBOS/integration
  -> Layer 3 boundary/call-shape checks
  -> Layer 4 runtime DBOS when durability/queue behavior matters

Scraper, extractor, parsing, validation, warehouse publish, chunks, embeddings?
  -> Layer 2 focused integration
  -> Layer 5 pipeline E2E for the changed path

Turbopuffer/search/chunk delete/patch path?
  -> Layer 2 plus Layer 4/5
  -> use the repo-local TP seed helper when the dev namespace needs real chunks

Frontend UX or browser behavior?
  -> build/lint as available
  -> Playwright/Stably or browser QA when the flow matters
```

## Soria Test Setup

Use repo scripts, not raw pytest, when they exist:

```bash
if [ ! -f .test-db-name ]; then
  eval $(bash scripts/create-test-db.sh)
fi

export DB_HOST=localhost
export DB_USER=soria_user
export DB_PASSWORD=password
export DB_NAME=placeholder
export TURBOPUFFER_NAMESPACE=test

bash scripts/run-tests.sh tests/path/to/test_file.py -v -n0
```

Common commands:

```bash
bash scripts/run-tests.sh tests/files/test_chunk_workflows.py -v -n0
bash scripts/run-tests.sh tests/ -v -k "chunk_delete or soft_delete"
bash scripts/run-tests.sh tests/ -m "not dbos_integration"
bash scripts/run-tests.sh tests/ -m "dbos_integration" --maxfail=1
bash scripts/run-tests.sh tests/ -x --tb=short -q
```

## Boundary Patterns

MCP wrappers should be tested at the wrapper, not only through the workflow
function:

```python
import asyncio

def _unwrap(tool):
    return tool.fn if hasattr(tool, "fn") else tool

result = asyncio.run(_unwrap(chunk_delete)(file_id=str(file.id)))
assert "Soft-deleted" in result
```

Assert the response shape the agent sees. Do not only assert that a mock was
called.

For FastAPI routes, use the repo's TestClient fixture or app factory and verify
status codes, validation, dependency wiring, and JSON serialization.

For DBOS/queue changes, avoid tests that mock DBOS internals into accepting an
invalid call shape. Use real integration coverage when the framework contract
is the risk.

## E2E Surfaces In soria-2

The app repo currently has several E2E families:

- `e2e/`: deployed backend MCP/API chains, controlled by `E2E_BACKEND_URL`
- `frontend/tests/e2e/`: Playwright/Stably UI tests
- `tests/mcp/`: local MCP/soft-delete scenarios
- `tests/integrations/`: local integration E2E for webhooks and services
- `tests/scrapers/`: scraper, trigger, and notification E2E
- `.github/workflows/preview-env.yml`: preview E2E when `run-e2e` is configured
- `.github/workflows/e2e-warehouse-promotion.yml`: MotherDuck promotion E2E

Do not claim staging or preview E2E proof unless the target environment, auth,
data seed, and runner are actually configured for that run.

## TP/Search E2E

Dev envs do not clone Turbopuffer. For search/chunk runtime tests:

```text
/dev-env
python scripts/seed-dev-tp.py --dry-run ...
/test
```

`scripts/seed-dev-tp.py` is an app repo helper, not a standalone skill. It
copies real vectors/content/metadata into the dev TP namespace without
re-running Modal/LlamaParse. It does not copy Postgres rows and does not create
namespace schema.

## Gotchas

- Soft-deleted rows are hidden unless the query uses
  `execution_options(include_deleted=True)`.
- After a DBOS workflow, call `db_session.expire_all()` before asserting with
  the test session.
- Mock external services when needed, not DBOS internals or wrapper contracts.
- If xdist causes DB drift on a narrow PR, use `-n0`.

## Output

End with an evidence report:

```text
Test evidence
Layer(s): <1-6>
Commands: <exact commands>
Result: <pass/fail/blocked>
Proven: <what boundary was exercised>
Not proven: <remaining risk>
Next: <review / more tests / fix>
```
