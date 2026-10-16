#!/usr/bin/env bash
# Removes the `tkit` command (installed packages are kept).
BIN="${PREFIX:-/usr/local}/bin"
rm -f "$BIN/tkit"
sed -i '/# tkit$/d;/tkit completion/d' "$HOME/.bashrc" 2>/dev/null
read -rp "Also delete ~/.config/tkit (state, logs, custom modules)? [y/N] " a
[[ "$a" =~ ^[Yy]$ ]] && rm -rf "$HOME/.config/tkit"
echo "✔ tkit removed"
