# Codex Adapter

These wrappers mirror the canonical `Soria-Inc/soria-stack` Claude skill pack
for Codex.

## Core rules

- Stay CLI-first. The Soria platform is driven through `soria`, not Soria MCP.
- If the user explicitly asks for Sumo/Soria MCP, switch to the separate
  `sumo-mcp` skill instead of forcing the CLI path.
- If the upstream Claude skill mentions `AskUserQuestion`, use normal Codex
  commentary updates and, when necessary, a short direct user question.
- If the upstream Claude skill mentions browser QA, use the Codex `browse`
  skill first. It prefers the fast `$B` runtime and only falls back to
  Playwright MCP when needed.
- If the upstream Claude skill mentions `mcp__openclaw__mempalace_search`,
  use it when the connector is available. If not, say that the memory search
  connector is unavailable and continue with local evidence.
- If the upstream Claude skill mentions `mcp__linear__*`, use Linear only if
  the connector exists in the Codex session. Otherwise fall back to a GitHub
  issue, or produce a ticket draft for the user.
- Read the current repo's `AGENTS.md` before following write or landing
  workflows. Repo rules take precedence over generic skill text.
- Respect prod safety. Anything that writes data or promotes changes needs
  explicit user acknowledgment if the active env is `prod`.

## Canonical source

When these wrappers are used inside the actual `Soria-Inc/soria-stack` repo,
the Claude `SKILL.md` files at the repo root remain the most detailed source of
truth. The Codex wrappers exist to make those workflows discoverable and usable
inside Codex without assuming Claude-specific tool names.
