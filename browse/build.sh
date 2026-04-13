#!/usr/bin/env bash
# Build the vendored browse binary.
# Requires bun (https://bun.sh). Playwright Chromium is downloaded on first launch
# of the binary, or can be pre-fetched with `bunx playwright install chromium`.
set -euo pipefail
cd "$(dirname "$0")/vendor"

if ! command -v bun >/dev/null 2>&1; then
  echo "error: bun not found. Install from https://bun.sh or: curl -fsSL https://bun.sh/install | bash" >&2
  exit 1
fi

bun install --silent
bun run build

# Pre-fetch Chromium so first $B invocation doesn't block on download
bunx --bun playwright install chromium >/dev/null 2>&1 || true

echo "built: $(pwd)/dist/browse"
