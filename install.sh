#!/usr/bin/env bash
# Installs the `tkit` command.
set -e
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${PREFIX:-/usr/local}/bin"
RC="$HOME/.bashrc"

chmod +x "$DIR/tkit"
mkdir -p "$BIN" "$HOME/.config/tkit/modules"
ln -sf "$DIR/tkit" "$BIN/tkit"

touch "$RC"
grep -q 'tkit completion' "$RC" || printf '\n# tkit\nsource <(tkit completion)\n' >> "$RC"

echo "✔ tkit installed  ->  run: tkit"
echo "  (restart Termux for tab-completion)"
