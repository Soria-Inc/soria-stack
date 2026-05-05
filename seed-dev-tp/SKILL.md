---
name: seed-dev-tp
version: 1.0.0
description: Use when Soria runtime or E2E tests need real Turbopuffer chunks in a branch dev namespace, especially for chunk_search, chunk_delete, patch_for_file, embeddings, search, or TP cleanup behavior.
allowed-tools:
  - Read
  - Bash
---

# /seed-dev-tp

`/dev-env` clones Postgres and MotherDuck, but it does not clone
Turbopuffer. Each dev env has its own TP namespace, and it often starts empty.

This skill seeds a dev TP namespace with prod-shaped chunk rows so runtime and
pipeline E2E tests can exercise real search/delete/patch behavior without
burning Modal/LlamaParse credits to re-ingest.

The script belongs in the app repo (`scripts/seed-dev-tp.py`). This skill is
the operating procedure.

## Prereqs

- `/dev-env` has run.
- The local backend is running with `make run-dev`.
- `.env` / direnv exposes the dev `TURBOPUFFER_NAMESPACE`.
- `TURBOPUFFER_API_KEY` is set.
- `scripts/seed-dev-tp.py` exists in the target repo.

## Check Namespaces

```bash
echo "target (dev): $TURBOPUFFER_NAMESPACE"
echo "source (prod): soria_chunks_prod"
```

## Dry Run

```bash
python scripts/seed-dev-tp.py \
  --source-namespace soria_chunks_prod \
  --target-namespace "$TURBOPUFFER_NAMESPACE" \
  --file-ids <file_uuid> \
  --dry-run
```

## Seed By File ID

```bash
python scripts/seed-dev-tp.py \
  --source-namespace soria_chunks_prod \
  --target-namespace "$TURBOPUFFER_NAMESPACE" \
  --file-ids <file_uuid>
```

## Seed And Remap

Use this when the dev chunks should live under a synthetic file ID:

```bash
python scripts/seed-dev-tp.py \
  --source-namespace soria_chunks_prod \
  --target-namespace "$TURBOPUFFER_NAMESPACE" \
  --file-ids <prod_uuid> \
  --remap-to auto
```

## Typical Runtime Test

```text
1. /dev-env
2. make run-dev
3. /seed-dev-tp for a file with real chunks
4. call the dev MCP tool or route under test
5. verify TP search/delete/patch behavior in the dev namespace
```

Example JSON-RPC call against a local MCP server:

```bash
curl -s -X POST "$SERVER_URL/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call",
       "params":{"name":"chunk_search",
                 "arguments":{"query":"Operating Margin"}}}'
```

## Caveats

- This only touches TP. It does not copy Postgres rows.
- Target namespace schema must already exist.
- Vector dimensions and distance metric must match.
- Chunk IDs are preserved; `--remap-to` changes `file_id`, not chunk IDs.

End by reporting rows read, rows written, target namespace, and what runtime
test should be run next.

