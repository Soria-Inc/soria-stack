# SoriaStack — Agent Instructions

This file exists for agents (Claude Code, Clawd, etc.) that look for an
`AGENTS.md` by convention. The content lives in `README.md` — read that.

## Key rules for agents

1. **Start every session with `/env` then `/tools`.** No other skill should
   run until the active environment is known and the `soria` CLI is verified.
2. **No Soria MCP.** The Soria platform is driven exclusively through the
   `soria` CLI. Never load `sumo_*` / `news_*` / `mcp__sumo__*` tools.
   External MCP is OK where scoped: `mcp__linear__*` is owned by `/ticket`
   (other skills invoke `/ticket` rather than calling Linear directly);
   `mcp__openclaw__mempalace_search` is used for domain grounding and
   prior-session search across several skills.
3. **Git-native authoring.** Scrapers, dbt SQL, manifests, dive TSX all live
   as files in the env's worktree. Commit in logical chunks as you go.
4. **Prod safety.** Every write-path skill refuses to run against prod
   unless the user explicitly acknowledges. `/promote` is the only skill
   that's expected to interact with prod, and it does so via PR, not direct
   writes.
5. **Read `ETHOS.md`** before any data pipeline work. All numbered
   principles apply.

## Skill index

See `README.md` for the full skill list and architecture diagram. Skills
live in their own directories — invoke by name (e.g., `/status`).
