# analyst/

File-based playbooks for the **pydantic-ai analyst agent** that writes
institutional healthcare briefing notes in `soria-2`.

These are NOT Claude Code skills. The `install.sh` at the pack root
symlinks only top-level skill dirs; `analyst/` is skipped because it has
no top-level `SKILL.md` — it's a namespace for a different runtime.

## How the analyst consumes these

At agent init, `soria/agents/skills_loader.py` walks `analyst/*/SKILL.md`,
parses the YAML frontmatter, and emits a one-line-per-skill index into
the analyst's system prompt via a `@analyst_agent.instructions` hook.

Each entry is `name` + `description`. The bodies are NOT loaded by
default — they're lazy-fetched when the analyst calls the `read_skill`
tool with a skill name it picked off the index. This keeps the per-event
prompt small (the 6 descriptions) while making the full playbook
available on demand.

Anthropic prompt caching is on (`anthropic_cache_instructions=True` on
the analyst agent), so the index is free after the first call of the
day.

## Authoring conventions

Each `<skill-name>/SKILL.md` is:

```markdown
---
name: <kebab-case-name>
description: >
  One paragraph. The first sentence is the trigger — "use this playbook
  when <event type>". The rest names the main analytical moves and the
  canonical chart.
---

# <skill-name>

Short intro: what makes this event type different.

## When to apply

Bulleted triggers. Be concrete — cite filings, actors, URL patterns.

## Core moves

1. **Move 1** — what to compute, against what reference class.
2. **Move 2** — …

## The canonical chart

The one chart an equity researcher would flip to first for this event
type. Specify the axes.

## Traps

What's easy to get wrong. Usually one or two bullets.
```

Keep each skill tight. No boilerplate. No restating what's already in
`analyst_rules.py`. The rules catalog covers the universal rigor
disciplines (title, first-sentence, citations, chart-coherence,
numbers-cited-or-footnoted); these skills cover what's specific to ONE
event type.

## Current skills (8)

Event-type playbooks:
- `federal-rulemaking/` — CMS/FDA/HHS/Treasury NPRMs, Final Rules, rate notices
- `executive-order/` — Presidential EOs, memos, proclamations
- `state-regulation/` — state statutes, regs, AG actions, ballot measures
- `legal-ruling/` — court decisions, MDL verdicts, settlements, consent decrees
- `drug-device-approval/` — FDA approvals, CRLs, label expansions, ODAC votes
- `tax-policy/` — federal + state tax policy affecting issuer cashflows

Cross-cutting (read in Phase 1.5 on every event, not event-type-specific):
- `framing-axes/` — checklist of categorical splits to pressure-test the first-instinct frame
- `mechanism-vs-event/` — separating the news peg from the analyst insight

## Update cycle

`/opt/soria-2/vendor/soria-stack/` is a live git clone. The
`soria-agents.service` systemd unit runs `git -C vendor/soria-stack pull
--ff-only` as `ExecStartPre`, so a service restart picks up new skills.
For mid-day bumps, `ssh root@178.104.142.125 'cd /opt/soria-2/vendor/soria-stack && git pull'`
and the next analyst run sees them (no restart needed — the loader reads
fresh on each agent init).
