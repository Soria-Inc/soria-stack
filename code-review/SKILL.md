---
name: code-review
version: 1.1.0
description: Use when reviewing Soria code, PRs, commits, or diffs for readiness, especially DBOS, MCP, API, database, scraper, extractor, observability, Turbopuffer, warehouse, frontend, or test-boundary changes.
allowed-tools:
  - Read
  - Bash
---

# /code-review

Review the diff against Soria's real implementation patterns, not generic
correctness. The goal is to catch changes that look reasonable in isolation
but violate how this repo actually works.

Read the target repo's `AGENTS.md` first (in shifted-left repos `CLAUDE.md`
is a symlink to it). Then load `docs/README.md` to find the subsystem routing
table — based on which subsystem(s) the diff touches, load the relevant
`docs/<pillar>/<doc>.md`. Those hold the codebase's actual rules, examples,
and anti-patterns; ground review against them, not vibes. Fall back to
inferring from nearby code only when those docs don't cover what changed.

## Workflow

1. Identify changed subsystems.
2. Read nearby existing implementation and tests before judging the diff.
3. Check whether each new pattern already exists elsewhere in the repo.
4. Check `/test` evidence or local test output. Ask whether it hit the risky
   boundary.
5. Report findings first, ordered by severity, with file/line references.

## Subsystem Checks

### DBOS Workflows And Queues

- Custom workflow IDs should use the repo's accepted DBOS pattern.
- Queue dedupe should use the repo's accepted enqueue options and catch
  dedupe exceptions only when duplicate enqueue is expected.
- Worker-recovered workflows must be imported where workers load at boot.
- DBOS contract changes need real integration coverage when mocks would accept
  an invalid framework call shape.

### Workflows / Tools / API / Schemas

- Business logic belongs in workflows, not MCP tools or API handlers.
- Tools validate inputs, call one workflow, and format the returned schema for
  agents.
- API routes validate inputs, call one workflow, and return typed data.
- Workflows return Pydantic models or plain data structures designed for the
  boundary, not detached ORM objects.

### Mocked Boundary Tests

- Treat mocks around framework or third-party APIs as suspicious if the test
  only asserts the mock was called.
- Ask: would this fail if the real API rejected this call shape?
- For MCP tools, verify response text/shape, not only the underlying function.
- For FastAPI, verify route/dependency/serialization behavior when relevant.

### Database Idempotency And Races

- Concurrent worker paths must be idempotent at the database boundary.
- Queue dedupe alone is not enough.
- If catching `IntegrityError`, the insert must happen inside the protected
  block and the handler should identify the expected conflict precisely.
- Reused rows must update exactly the fields callers expect to be current.

### Observability Suppression

- Expected states should become explicit outcomes: 4xx responses, skipped
  statuses, warnings, or specific ignored exceptions.
- Unknown failures should still raise or return 5xx.
- Avoid broad substring filters, broad `except Exception`, and suppression that
  hides actionable bugs.

### Scrapers, Extractors, Pipeline

- Scrapers and extractors should follow repo contracts and avoid live network
  calls in normal tests unless the test is explicitly E2E.
- Pipeline tests should cover the observed failure mode, not just the intended
  happy path.
- For chunk/search/TP changes, verify TP behavior when that is the risk.

### Test Quality

- Use `bash scripts/run-tests.sh` when available.
- Prefer focused regression tests plus the relevant boundary proof from
  `/test`.
- Do not accept "unit tests passed" for MCP, DBOS, HTTP, or E2E-facing changes
  when the wrapper/runtime boundary is the risk.

## Lessons Hook

If the review catches a repeated miss, record where it should go:

- repeated review rule -> `soria-stack/code-review`
- repeated testing decision -> `soria-stack/test`
- missing helper -> target repo `scripts/`

## Output

Start with findings. If there are no findings, say so and list residual risks.

```text
Findings
- [severity] file:line Problem. Why it matters. Suggested fix.

Residual risks
- What was not proven by tests or local review.

Verdict
- Ready / ready after fixes / not ready.
```
