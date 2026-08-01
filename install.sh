#!/usr/bin/env bash
#
# Standalone installer for tmux-agentwatch.
#
#   ./install.sh                  # installs to ~/.local/bin
#   ./install.sh /usr/local/bin   # or a directory of your choosing

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$HOME/.local/bin}"

mkdir -p "$TARGET_DIR"
install -m 0755 "$CURRENT_DIR/scripts/agentwatch" "$TARGET_DIR/agentwatch"

echo "agentwatch installed to $TARGET_DIR/agentwatch"

case ":$PATH:" in
    *":$TARGET_DIR:"*) ;;
    *) echo "warning: $TARGET_DIR is not in your PATH" >&2 ;;
esac

echo
echo "Next:"
echo "  1. agentwatch hooks --write     # wire up Claude Code"
echo "  2. agentwatch doctor            # confirm the setup (run inside tmux)"
