---
name: lessons
description: Data-pipeline retrospective for Codex. Use when the user wants to review recent work, extract patterns, capture what went well or failed, or update the team's operating principles from concrete evidence.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: lessons/SKILL.md
  variant: codex
---

# Lessons

Codex adaptation of the `Soria-Inc/soria-stack` `/lessons` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- review recent artifacts and session evidence
- use mempalace when available for prior comparable work
- identify repeat failures, successful patterns, and principle updates
- treat "capture this", "why did this take so long", and "make sure we
  remember this" as possible skill-update requests
- locate the target skill and compare any branch-local patch against canonical
  `Soria-Inc/soria-stack`
- update the canonical skill repo, not a temporary `soria-2` checkout or
  backup copy
- update both surfaces when needed:
  `<skill>/SKILL.md` and `plugins/soria-stack/skills/<skill>/SKILL.md`
- preserve `https://github.com/Soria-Inc/soria-stack` metadata when porting
  lessons from embedded copies
- surface MCP tool gaps (needed behavior with no `mcp__soria__*` tool)
- end with concrete lessons, not generic retrospection

## Canonical Skill Update Workflow

When an approved lesson changes skill behavior:

1. Verify the canonical repo with `git remote -v`; expected remote is
   `https://github.com/Soria-Inc/soria-stack`.
2. Identify the skill that should absorb the lesson (`browse`, `dive`,
   `ingest`, `verify`, etc.).
3. Search for the lesson in likely stray locations: current worktree,
   `~/.claude/skills`, `~/.codex/skills`, plugin wrappers, and backups.
4. Port only the lesson into canonical `soria-stack`. Do not wholesale copy
   branch-local files whose metadata or repo assumptions point at `soria-2`.
5. Update both the Claude-facing skill and the Codex-facing wrapper when both
   should change.
6. Show the diff or, if the user approved direct landing, commit and push.
