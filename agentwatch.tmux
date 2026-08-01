#!/usr/bin/env bash
#
# TPM entry point for tmux-agentwatch
#
# User-configurable options (set in ~/.tmux.conf before loading TPM):
#
#   set -g @agentwatch-next   "M-a"   # Jump to the agent waiting longest
#   set -g @agentwatch-menu   "M-A"   # Pick an agent from a menu
#   set -g @agentwatch-switch "none"  # Pick an agent with fzf (popup)
#   set -g @agentwatch-list   "none"  # Show the roster in a popup
#
# Set any key to "none" to disable that binding.
#
#   set -g @agentwatch-decorate-windows "on"   # append a glyph to window-status-format
#   set -g @agentwatch-clear-on-focus   "on"   # un-flag a pane once you look at it
#
# See readme.md for the full option list.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTWATCH="$CURRENT_DIR/scripts/agentwatch"

# Reserved hook index, so re-sourcing the plugin replaces our hooks instead of
# stacking another copy alongside them.
HOOK_SLOT=90

get_tmux_option() {
    local value
    value=$(tmux show-option -gqv "$1")
    echo "${value:-$2}"
}

bind_option() {
    local key
    key=$(get_tmux_option "$1" "$2")
    [[ $key == "none" ]] && return 0
    shift 2
    tmux bind-key "$key" "$@"
}

# Append the state glyph to the window status, once.
decorate_windows() {
    [[ $(get_tmux_option "@agentwatch-decorate-windows" "on") == "on" ]] || return 0

    local suffix='#{?#{@agentwatch_glyph},#[fg=#{@agentwatch_color}] #{@agentwatch_glyph}#[default],}'
    local opt fmt
    for opt in window-status-format window-status-current-format; do
        fmt=$(tmux show-option -gqv "$opt")
        [[ $fmt == *"@agentwatch_glyph"* ]] && continue
        tmux set-option -g "$opt" "${fmt}${suffix}"
    done
}

# Clear a pane's flag when the user actually looks at it.
install_focus_hooks() {
    [[ $(get_tmux_option "@agentwatch-clear-on-focus" "on") == "on" ]] || return 0

    tmux set-option -g focus-events on

    local hook
    for hook in pane-focus-in after-select-pane after-select-window; do
        tmux set-hook -g "${hook}[${HOOK_SLOT}]" "run-shell -b \"'$AGENTWATCH' seen\""
    done
}

main() {
    bind_option "@agentwatch-next" "M-a" run-shell -b "'$AGENTWATCH' next"
    bind_option "@agentwatch-menu" "M-A" run-shell -b "'$AGENTWATCH' menu"
    bind_option "@agentwatch-switch" "none" \
        display-popup -E -w 70% -h 40% "'$AGENTWATCH' switch"
    bind_option "@agentwatch-list" "none" \
        display-popup -E -w 70% -h 40% "'$AGENTWATCH' list; read -n1 -r -p ''"

    decorate_windows
    install_focus_hooks

    # Drop records for panes that died while tmux was not running this plugin.
    tmux run-shell -b "'$AGENTWATCH' reap"
}

main
