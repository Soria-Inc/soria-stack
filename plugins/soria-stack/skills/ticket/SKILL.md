---
name: ticket
description: Capture a structured issue from a Soria workflow in Codex. Use when the user wants a ticket filed, when a bug or feature needs to be recorded with enough context to act on, or when another Soria skill reaches a ticket disposition.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: ticket/SKILL.md
  variant: codex
---

# Ticket

Codex adaptation of the `Soria-Inc/soria-stack` `/ticket` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- gather repro steps, environment, workaround, and root-cause hints
- deduplicate against existing issues when the connector exists
- keep ticket filing as a side-quest, then return to the main workflow

## Notes

- If Linear is available in the Codex session, use it.
- If Linear is unavailable, file a GitHub issue when appropriate or produce a
  ready-to-paste issue draft with the same structure.
