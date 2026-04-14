---
name: preview
description: Render a dive as markdown tables in Codex without opening a browser. Use when the user wants to inspect a dive's current output shape, filters, or likely rendered values through the manifest and warehouse query path.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: preview/SKILL.md
  variant: codex
---

# Preview

Codex adaptation of the `Soria-Inc/soria-stack` `/preview` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- read the manifest, derive the SQL shape, query the warehouse
- format the output the way the dive presents it
- use this instead of a browser when the user wants a quick in-chat read
- route to `verify` or `dashboard-review` if the preview reveals a real issue
