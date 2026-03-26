#!/usr/bin/env bash
# Auto-name all panes using fingerprint-based change detection
# Skips manually named panes, re-evaluates auto-named panes if content changed
# Usage: auto-name-all.sh [-m model]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODEL_ARG=""
if [ "$1" = "-m" ]; then
    MODEL_ARG="-m $2"
fi

# Get all panes
tmux list-panes -a -F '#{pane_id}' | while read -r pane_id; do
    # Skip manually named panes
    manual=$(tmux display-message -p -t "$pane_id" '#{@pane_name_manual}' 2>/dev/null)
    if [ "$manual" = "1" ]; then
        continue
    fi

    # auto-name.sh handles fingerprint check internally
    AUTO_TRIGGER=1 "$SCRIPT_DIR/auto-name.sh" -t "$pane_id" $MODEL_ARG &
done

wait
