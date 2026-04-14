#!/usr/bin/env bash
# install-codex.sh — expose the soria-stack Codex plugin as a home-local plugin.
# Creates/updates ~/plugins/soria-stack -> <repo>/plugins/soria-stack and ensures
# ~/.agents/plugins/marketplace.json contains a matching entry.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_NAME="soria-stack"
PLUGIN_SRC="$SCRIPT_DIR/plugins/$PLUGIN_NAME"
PLUGIN_HOME="${CODEX_PLUGIN_HOME:-$HOME/plugins}"
PLUGIN_DEST="$PLUGIN_HOME/$PLUGIN_NAME"
MARKETPLACE_PATH="${CODEX_MARKETPLACE_PATH:-$HOME/.agents/plugins/marketplace.json}"

echo "soria-stack Codex installer"
echo "==========================="
echo "Repo:        $SCRIPT_DIR"
echo "Plugin src:  $PLUGIN_SRC"
echo "Plugin home: $PLUGIN_HOME"
echo "Marketplace: $MARKETPLACE_PATH"
echo

if [ ! -d "$PLUGIN_SRC/.codex-plugin" ]; then
  echo "ERROR: missing plugin manifest at $PLUGIN_SRC/.codex-plugin/plugin.json" >&2
  exit 1
fi

mkdir -p "$PLUGIN_HOME" "$(dirname "$MARKETPLACE_PATH")"

if [ -L "$PLUGIN_DEST" ]; then
  current="$(readlink "$PLUGIN_DEST")"
  if [ "$current" = "$PLUGIN_SRC" ]; then
    echo "Symlink already correct: $PLUGIN_DEST -> $PLUGIN_SRC"
  else
    ln -sfn "$PLUGIN_SRC" "$PLUGIN_DEST"
    echo "Updated symlink: $PLUGIN_DEST -> $PLUGIN_SRC (was $current)"
  fi
elif [ -e "$PLUGIN_DEST" ]; then
  echo "ERROR: $PLUGIN_DEST exists and is not a symlink. Move it aside and rerun." >&2
  exit 1
else
  ln -s "$PLUGIN_SRC" "$PLUGIN_DEST"
  echo "Created symlink: $PLUGIN_DEST -> $PLUGIN_SRC"
fi

python3 - "$MARKETPLACE_PATH" <<'PY'
import json
import os
import sys

path = sys.argv[1]
plugin = {
    "name": "soria-stack",
    "source": {
        "source": "local",
        "path": "./plugins/soria-stack",
    },
    "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL",
    },
    "category": "Coding",
}

if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
else:
    data = {
        "name": "local-plugins",
        "interface": {
            "displayName": "Local Plugins",
        },
        "plugins": [],
    }

data.setdefault("name", "local-plugins")
data.setdefault("interface", {})
data["interface"].setdefault("displayName", "Local Plugins")

plugins = [p for p in data.get("plugins", []) if p.get("name") != "soria-stack"]
plugins.append(plugin)
data["plugins"] = plugins

tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
os.replace(tmp, path)
print(f"Updated marketplace: {path}")
PY

if [ -x "$SCRIPT_DIR/browse/build.sh" ]; then
  browse_bin="$SCRIPT_DIR/browse/vendor/dist/browse"
  src_newer="$(find "$SCRIPT_DIR/browse/vendor/src" -type f -newer "$browse_bin" 2>/dev/null | head -1 || true)"
  if [ ! -x "$browse_bin" ] || [ -n "$src_newer" ]; then
    echo
    echo "Building fast /browse runtime..."
    "$SCRIPT_DIR/browse/build.sh"
  fi
fi

echo
echo "Done."
echo "Restart Codex or start a fresh session to pick up the plugin."
