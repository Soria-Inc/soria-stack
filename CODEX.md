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
