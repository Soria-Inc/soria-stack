# Codex

This repo ships a Codex plugin at `plugins/soria-stack`.

## Repo-local usage

If you open this repo in Codex, the plugin is discoverable through the repo
marketplace file at `.agents/plugins/marketplace.json`.

Restart Codex or start a fresh session after pulling changes.

## Home-local install

To expose the plugin across Codex sessions outside this repo:

```bash
bash install-codex.sh
```

That script:

- symlinks `~/plugins/soria-stack` to this repo's plugin
- adds or updates `~/.agents/plugins/marketplace.json`
- builds the fast `/browse` runtime from `browse/build.sh` if needed

## `/browse`

The Codex `/browse` skill prefers the fast `$B` runtime from the upstream repo:

```bash
browse/vendor/dist/browse
```

If `$B` is unavailable or cannot start in the current sandbox, the plugin ships
Playwright MCP as a slower fallback.

## Engineering Skills

The Codex plugin also exposes Soria engineering workflows:

- `/dev-env` — branch-local app env setup and repair
- `/dev-dives` — dev HTTPS dive frontend setup/repair for `dev.soriaanalytics.com`
- `/test` — choose unit, integration, boundary, runtime, pipeline E2E, or deployed proof
- `/code-review` — Soria-specific diff review and test-boundary judgment

Repo-local helper scripts, such as `soria-2/scripts/seed-dev-tp.py`, are
called by the relevant workflow skill rather than exposed as Codex skills.

When working inside `soria-2`, read that repo's `AGENTS.md`/`CLAUDE.md` first.
Repo-local rules and scripts are the source of truth.
