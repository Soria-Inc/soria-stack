---
name: dashboard-review
description: Ship-readiness browser QA for a dive in Codex. Use when the user wants a live dive reviewed before promotion, including render checks, data correctness, interactivity, methodology, edge cases, and performance evidence.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: dashboard-review/SKILL.md
  variant: codex
---

# Dashboard Review

Codex adaptation of the `Soria-Inc/soria-stack` `/dashboard-review` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- live dive QA against local dev or preview envs
- browser evidence for render, interactivity, correctness, and performance
- final gate before `promote`

## Notes

- Use the Codex `browse` skill for the actual browser runtime.
- Do not silently file tickets from here; hand off to `ticket` or `diagnose`.
