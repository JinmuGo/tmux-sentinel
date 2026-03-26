#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default options
default_key="N"
default_fg="#1a1b26"
default_bg="#7aa2f7"
default_border_status="bottom"

get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local value
    value=$(tmux show-option -gqv "$option")
    if [ -z "$value" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

# Read user options
key=$(get_tmux_option "@pane-naming-key" "$default_key")
fg=$(get_tmux_option "@pane-naming-fg" "$default_fg")
bg=$(get_tmux_option "@pane-naming-bg" "$default_bg")
border_status=$(get_tmux_option "@pane-naming-border-status" "$default_border_status")

# Build format from fg/bg
named_format="#[fg=${fg},bg=${bg},bold] #{@pane_name} #[default]"

# Enable pane border status
tmux set-option -g pane-border-status "$border_status"

# Set pane border format
tmux set-option -g pane-border-format "${named_format}"

# prefix + N → manual name input (sets @pane_name_manual flag)
tmux bind-key "$key" command-prompt -p "Pane name:" \
    "set-option -p @pane_name '%%' \\; set-option -p @pane_name_manual 1"

# prefix + M-n → clear pane name + manual flag
tmux bind-key M-n set-option -p -u @pane_name \\\; set-option -p -u @pane_name_manual \\\; set-option -p -u @pane_name_hash

# prefix + M-N → auto-name current pane
tmux bind-key M-N run-shell "$CURRENT_DIR/scripts/auto-name.sh"

# prefix + C-n → auto-name all panes
tmux bind-key C-n run-shell "$CURRENT_DIR/scripts/auto-name-all.sh"

# ─── Auto-naming trigger ───
# Options: off, focus, interval, both (default: focus)
auto_mode=$(get_tmux_option "@pane-naming-auto" "focus")
auto_interval=$(get_tmux_option "@pane-naming-auto-interval" "60")

# Stop any existing watch daemon
old_pid=$(tmux show-environment -g PANE_NAMING_WATCH_PID 2>/dev/null | cut -d= -f2)
if [ -n "$old_pid" ] && [ "$old_pid" != "-PANE_NAMING_WATCH_PID" ]; then
    kill "$old_pid" 2>/dev/null
    tmux set-environment -g -u PANE_NAMING_WATCH_PID 2>/dev/null
fi

# Use namespaced hook index to avoid clobbering other plugins' hooks
hook_name="after-select-pane[42]"

case "$auto_mode" in
    focus)
        tmux set-hook -g "$hook_name" "run-shell '$CURRENT_DIR/scripts/on-focus.sh'"
        ;;
    interval)
        "$CURRENT_DIR/scripts/watch-panes.sh" "$auto_interval" &
        ;;
    focus+interval|both)
        tmux set-hook -g "$hook_name" "run-shell '$CURRENT_DIR/scripts/on-focus.sh'"
        "$CURRENT_DIR/scripts/watch-panes.sh" "$auto_interval" &
        ;;
    off|*)
        tmux set-hook -gu "$hook_name" 2>/dev/null
        ;;
esac

# Register the plugin directory for programmatic access
tmux set-environment -g TMUX_PANE_NAMING_DIR "$CURRENT_DIR"
