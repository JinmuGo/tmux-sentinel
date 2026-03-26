#!/usr/bin/env bash
# Clear a pane name and all associated flags
# Usage: clear-pane-name.sh [-t target]

if [ "$1" = "-t" ]; then
    tmux set-option -p -t "$2" -u @pane_name
    tmux set-option -p -t "$2" -u @pane_name_manual
    tmux set-option -p -t "$2" -u @pane_name_hash
else
    tmux set-option -p -u @pane_name
    tmux set-option -p -u @pane_name_manual
    tmux set-option -p -u @pane_name_hash
fi
