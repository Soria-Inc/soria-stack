---
name: seed-dev-tp
description: Use when Soria runtime or E2E tests need real Turbopuffer chunks in a branch dev namespace, especially for chunk_search, chunk_delete, patch_for_file, embeddings, search, or TP cleanup behavior.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: seed-dev-tp/SKILL.md
  variant: codex
---

# Seed Dev TP

Codex adaptation of `Soria-Inc/soria-stack` `/seed-dev-tp`.

Use after `dev-env` when a runtime or E2E test needs real chunks in the dev
Turbopuffer namespace. The script should live in the app repo as
`scripts/seed-dev-tp.py`.

Typical flow:

```text
dev-env -> make run-dev -> seed-dev-tp -> test runtime/E2E behavior
```

This copies TP rows only. It does not copy Postgres rows and does not create
namespace schema.

