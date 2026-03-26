#!/usr/bin/env bash
# Rename a pane programmatically (marks as manual to prevent auto-update)
# Usage: rename-pane.sh [pane-target] [name]
#   rename-pane.sh "my-server"        # rename current pane
#   rename-pane.sh -t %3 "my-server"  # rename specific pane

if [ "$1" = "-t" ]; then
    target="$2"
    name="$3"
else
    target=""
    name="$1"
fi

if [ -z "$name" ]; then
    echo "Usage: rename-pane.sh [-t target] <name>"
    echo "       rename-pane.sh <name>           # rename current pane"
    echo "       rename-pane.sh -t %3 <name>     # rename pane %3"
    exit 1
fi

if [ -n "$target" ]; then
    tmux set-option -p -t "$target" @pane_name "$name"
    tmux set-option -p -t "$target" @pane_name_manual 1
else
    tmux set-option -p @pane_name "$name"
    tmux set-option -p @pane_name_manual 1
fi
